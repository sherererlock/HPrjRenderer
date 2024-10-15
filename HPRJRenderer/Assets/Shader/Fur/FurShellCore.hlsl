
// ------------------------------ Material Properties ------------------------------
#include "FurShellProperties.hlsl"
#include "../Common.hlsl"

#include "ShadingModelFurShell.hlsl"
// ------------------------------ Surface Definition ------------------------------
// Set up surface data, using informations from properties, textures and vertex input
SURFACE_DATA InitializeSurfaceData(half2 uv, half paramControl = 1)
{    
    half4 albedoMapValue = tex2D(_AlbedoMap, uv);
    half4 detail = tex2D(_DetailMap, uv);
    
    half2 furUV = uv * _FurScale * paramControl;

	SURFACE_DATA surfaceData = (SURFACE_DATA) 0;
    half shellOffset = 0.0;
    #ifdef SHELL_OFFSET
        shellOffset = SHELL_OFFSET;
    #endif
    half furOcclusion = lerp(1.0 - _FurOcclusion, 1.0, shellOffset);
    surfaceData.albedo = albedoMapValue.rgb * _ColorTint.rgb * furOcclusion;
	surfaceData.perceptualRoughness = detail.r * _RoughnessScale;
    surfaceData.occlusion = lerp(1.0, detail.g, _OcclusionScale);
    surfaceData.tNormal = UnpackNormalScale(tex2D(_NormalMap, uv), _NormalScale);

    surfaceData.furNoise = tex2D(_FurNoiseMap, furUV).r * albedoMapValue.a;
    surfaceData.scatter = half4(_ScatterColor.rgb * detail.g * furOcclusion, _ScatterScale);
	return surfaceData;
}

#define INITIALIZE_SURFACE_DATA InitializeSurfaceData

// ------------------------------ Shading Pass ------------------------------

struct Attributes
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    half2 uv : TEXCOORD0;
    half2 lightmapUV : TEXCOORD1;
};

struct Varyings
{
    float4 pos : SV_POSITION;
    half2 uv : TEXCOORD0;
    
    // tangent to world matrix, world pos stored in w
    float4 TtoW0 : TEXCOORD1;
    float4 TtoW1 : TEXCOORD2;
    float4 TtoW2 : TEXCOORD3;

    DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 4);

    half4 shadowCoord : TEXCOORD5;

	half4 fogFactorAndVertexLight : TEXCOORD6;
    int characterShadowLayerIndex : TEXCOORD7;
    half2 paramControl: TEXCORRD8;

};

Varyings ShadingVertex (Attributes v)
{
    Varyings o = (Varyings) 0;

    half shellOffset = 0.0;
    #ifdef SHELL_OFFSET
        shellOffset = SHELL_OFFSET;
    #endif

    // 因为skin mesh 会影响 vertex 和 normal 同时影响 model 矩阵，
    // 所以计算都在 world space 下进行 
    VertexNormalInputs normalInput = GetVertexNormalInputs(v.normal, v.tangent);
    
    // transform in world space
    half3 paramVal = SAMPLE_TEXTURE2D_LOD(_ParamMaskMap, sampler_ParamMaskMap, v.uv,0);
    paramVal = lerp( half3(1,1,1), paramVal, _IntensityMaskScale);
	o.paramControl = paramVal.rg;
    float3 normalWS = normalInput.normalWS;
    float3 posWS = TransformObjectToWorld(v.vertex.xyz);
    float3 gravDirWS = normalize(_GravityDir.xyz);
    float3 windDirWS = normalize(_WindDir.xyz * sin(v.vertex.xyz * _WindFreq.w + _WindFreq.xyz * _Time.w));
    float3 gravDeltaWS = (gravDirWS - normalWS) * _GravityStrength * paramVal.b;
	float3 windDeltaWS = (windDirWS - normalWS) * _WindStrength;
    float3 directionWS = normalWS + (gravDeltaWS + windDeltaWS) * shellOffset;
    posWS += directionWS * _FurLength * shellOffset * o.paramControl.r;
    VertexPositionInputs vertexInput;
    

    vertexInput.positionWS = posWS;
    vertexInput.positionVS = TransformWorldToView(vertexInput.positionWS);
    vertexInput.positionCS = TransformWorldToHClip(vertexInput.positionWS);

    float4 ndc = vertexInput.positionCS * 0.5f;
    vertexInput.positionNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
    vertexInput.positionNDC.zw = vertexInput.positionCS.zw;
    //

    o.pos = vertexInput.positionCS;
    o.uv = v.uv;

    // Compute the matrix that transform directions from tangent space to world space
    // Put world space position in w component for optimization
    o.TtoW0 = float4(normalInput.tangentWS.x, normalInput.bitangentWS.x, normalInput.normalWS.x, vertexInput.positionWS.x);
    o.TtoW1 = float4(normalInput.tangentWS.y, normalInput.bitangentWS.y, normalInput.normalWS.y, vertexInput.positionWS.y);
    o.TtoW2 = float4(normalInput.tangentWS.z, normalInput.bitangentWS.z, normalInput.normalWS.z, vertexInput.positionWS.z);

    OUTPUT_LIGHTMAP_UV(v.lightmapUV, unity_LightmapST, o.lightmapUV);
    OUTPUT_SH(normalInput.normalWS.xyz, o.vertexSH);
    o.characterShadowLayerIndex = 1;

	o.shadowCoord = half4(0, 0, 0, 0);

    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
    half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
    o.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

    return o;
}

half4 ShadingFragment(Varyings i, half facing : VFACE) : SV_TARGET
{
    half shellOffset = 0.0;
    #ifdef SHELL_OFFSET
        shellOffset = SHELL_OFFSET;
    #endif
    // Surface Data -> BRDF Data
    SURFACE_DATA surfaceData = INITIALIZE_SURFACE_DATA(i.uv, i.paramControl.g);

    half clipTemp = min(_ClipAdjust, shellOffset);

    half alphaClip = surfaceData.furNoise - _AlphaCutout * clipTemp;
    half alphaClipDetail = 1 - _AlphaCutout * clipTemp;


    BRDF_DATA brdfData = INITIALIZE_BRDF_DATA(surfaceData);

    // Input Data
    InputDataCustom inputData = (InputDataCustom)0;
    inputData.worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
    inputData.worldVertexNormal = normalize(float3(i.TtoW0.z, i.TtoW1.z, i.TtoW2.z));
    inputData.worldNormal = normalize(float3(dot(i.TtoW0.xyz, surfaceData.tNormal),
                                             dot(i.TtoW1.xyz, surfaceData.tNormal),
                                             dot(i.TtoW2.xyz, surfaceData.tNormal)));
    inputData.worldView = normalize(_WorldSpaceCameraPos.xyz - inputData.worldPos);
    inputData.facing = facing;

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
	    inputData.shadowCoord = i.shadowCoord;
    #else
    inputData.shadowCoord = half4(0, 0, 0, 0);
    #endif

    inputData.fogCoord = i.fogFactorAndVertexLight.x;
    inputData.vertexLighting = i.fogFactorAndVertexLight.yzw;
    inputData.bakedGI = SampleNonLinearBakedGI(inputData.worldNormal) * _IndirectDiffuseScale;
    inputData.bakedGI = max(max(inputData.bakedGI.r, inputData.bakedGI.g), inputData.bakedGI.b) * _IndirectDiffuseColor * _UseIndirectDiffuseColor + inputData.bakedGI * ( 1 - _UseIndirectDiffuseColor);
    inputData.shadowMask = SAMPLE_SHADOWMASK(i.lightmapUV);

    // Lighting
    half3 color = half3(0.0, 0.0, 0.0);
	
	//**************************************
    #if defined(_TRANSPARENTSHADOWRECEIVER_YES) && defined(_GLOBAL_TRANSPARENTSHADOW)
    half4 transpShadowCoord = TransformTransparentWorldToShadowCoord(inputData.worldPos, _SupportingCharacterIndex);
	Light mainLight = GetMixedCharactersLightWithTransparency(inputData.shadowCoord, transpShadowCoord, inputData.worldPos, inputData.shadowMask,i.characterShadowLayerIndex, _SupportingCharacterIndex);
    #else
	Light mainLight = GetMainLight(inputData.shadowCoord, inputData.worldPos, inputData.shadowMask);
    #endif

    MixRealtimeAndBakedGI(mainLight, inputData.worldNormal, inputData.bakedGI);
    GLOBAL_ILLUMINATION(color, brdfData, inputData);
    LIGHTING_MAIN(color, brdfData, inputData, mainLight);

    /*#ifdef _ADDITIONAL_LIGHTS
	    uint pixelLightCount = GetAdditionalLightsCount();
	    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
	    {
	        Light addLight = GetAdditionalLight(lightIndex, inputData.worldPos, inputData.shadowMask, _SupportingCharacterIndex);
	        LIGHTING_ADD(color, brdfData, inputData, addLight);
	    }
    #endif*/

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
	    LIGHTING_VERTEX(color, brdfData, inputData);
    #endif

    MixFogCustom(color, inputData);

    half alpha = 1 - shellOffset * shellOffset;
    alpha += saturate(dot(inputData.worldView, inputData.worldNormal)) - _EdgeFade * step(0.001, shellOffset);
    alpha = saturate(alpha);
    
    half4 finalColor;
    if (alphaClip >= 0)
    {
        finalColor = half4(color, alpha);
    }
    else
    {
        half4 colorOrigin=half4(color, alpha);

    #if defined(_FRESNELEDGE_ON)
        half NdotV = max(0, dot(inputData.worldNormal, inputData.worldView));
        NdotV = smoothstep(0, 1.0, 1.0 - NdotV);
        half fresnel = pow(NdotV, _RimPower) * _RimIntensity;
        half3 temp = _DeepAreaColor.rgb;

        half alphaEdge = 1 - shellOffset * shellOffset;
        alphaEdge += saturate(dot(inputData.worldView, inputData.worldNormal)) - (_EdgeFade - _EdgeControl) * step(
            0.001, shellOffset);
        alphaEdge = saturate(alphaEdge);
        half4 colorFresnel = half4(color * temp, fresnel * alphaEdge * step(0.001,alphaClipDetail));
        half originCheck=step(0.001,alphaClip);
        finalColor =  originCheck * colorOrigin+(1-originCheck)*colorFresnel;
    #else
        clip(alphaClip);
        finalColor =  colorOrigin;
    #endif
    }
    #if defined(_APPLY_COLORGRADING_MANUAL)
        half lutHeight = 32;
        half lutWidth = lutHeight * lutHeight;

        float postExposureLinear = pow(2.f, 0.7f);

        half4 lutParameters = half4(1.f / lutWidth, 1.f / lutHeight, lutHeight - 1.f, postExposureLinear);

        finalColor.rgb = (1.0 - _MANUALCOLORSHADING) * finalColor.rgb + _MANUALCOLORSHADING * ApplyColorGrading(finalColor.rgb, lutParameters.w, lutParameters.xyz, _CustomLUT);
    #endif

    return finalColor;
}

// ------------------------------ Meta Pass ------------------------------

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"

struct MetaAttributes
{
    float4 vertex : POSITION;
    half2 uv : TEXCOORD0;
    half2 lightmapUV : TEXCOORD1;
    half2 dynamicLightmapUV : TEXCOORD2;
};

struct MetaVaryings
{
    float4 pos : SV_POSITION;
    half2 uv : TEXCOORD0;
};

MetaVaryings MetaVertex(MetaAttributes v)
{
    MetaVaryings o = (MetaVaryings) 0;
    o.pos = MetaVertexPosition(v.vertex, v.lightmapUV, v.dynamicLightmapUV, unity_LightmapST, unity_DynamicLightmapST);
    o.uv = v.uv;
    return o;
}

half4 MetaFragment(MetaVaryings i) : SV_Target
{
	// Surface Data -> BRDF Data
	SURFACE_DATA surfaceData = INITIALIZE_SURFACE_DATA(i.uv);
	BRDF_DATA brdfData = INITIALIZE_BRDF_DATA(surfaceData);

    clip(surfaceData.furNoise - _AlphaCutout);

    MetaInput metaInput;
    metaInput.Albedo = brdfData.diffColor + brdfData.specColor * brdfData.roughness * 0.5;
    //metaInput.SpecularColor = 0.0;
    metaInput.Emission = 0.0;

    return MetaFragment(metaInput);
}

// ------------------------------ ShadowCaster Pass ------------------------------

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

struct ShadowPassAttributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    half2 uv : TEXCOORD0;
};

struct ShadowPassVaryings
{
    half2 uv : TEXCOORD0;
    float4 positionCS   : SV_POSITION;
    float4 grabPos : TEXCOORD1;

};

float4 GetShadowPositionHClip(ShadowPassAttributes input)
{
    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));

#if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
#else
    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
#endif

    return positionCS;
}

ShadowPassVaryings ShadowPassVertex(ShadowPassAttributes input)
{
    ShadowPassVaryings output = (ShadowPassVaryings) 0;
    output.uv = input.uv;

    output.positionCS = GetShadowPositionHClip(input);
    output.grabPos = ComputeScreenPos(output.positionCS);

    return output;
}

half4 ShadowPassFragment(ShadowPassVaryings input) : SV_TARGET
{
    half4 albedoMapValue = tex2D(_AlbedoMap, input.uv);
    half2 furUV = input.uv * _FurScale;
    half furNoise = tex2D(_FurNoiseMap, furUV).r * albedoMapValue.a;
    
    clip(furNoise - _AlphaCutout);

    return 0;
}

// half4 CharacterShadowPassFragment(ShadowPassVaryings input) : SV_TARGET
// {
//     //half newIndex = (half)UpdateSupportingCharacterIndex(_SupportingCharacterIndex);
//
//     half supIndex = (half)UpdateSupportingCharacterIndex(_SupportingCharacterIndex);
//     clip(input.grabPos.x - (supIndex - 1.0) * 1.0/(half)(_SupportingCharacterAmount + _MixedCharactersShadowmapPowRate));
//     clip(supIndex * (supIndex * 1.0/(half)(_SupportingCharacterAmount + _MixedCharactersShadowmapPowRate) - input.grabPos.x));
//     clip(supIndex + input.grabPos.x - (half)_SupportingCharacterAmount/(_SupportingCharacterAmount + _MixedCharactersShadowmapPowRate));
//     
//     half4 albedoMapValue = tex2D(_AlbedoMap, input.uv);
//     half2 furUV = input.uv * _FurScale;
//     half furNoise = tex2D(_FurNoiseMap, furUV).r * albedoMapValue.a;
//     
//     clip(furNoise - _AlphaCutout);
//
//     return 0;
// }

// ------------------------------ DepthOnly Pass ------------------------------

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

struct DepthOnlyAttributes
{
    float4 position     : POSITION;
    half2 uv : TEXCOORD0;
};

struct DepthOnlyVaryings
{
    half2 uv : TEXCOORD0;
    float4 positionCS   : SV_POSITION;
};

DepthOnlyVaryings DepthOnlyVertex(DepthOnlyAttributes input)
{
    DepthOnlyVaryings output = (DepthOnlyVaryings) 0;
    output.uv = input.uv;
    output.positionCS = TransformObjectToHClip(input.position.xyz);
    return output;
}

half4 DepthOnlyFragment(DepthOnlyVaryings input) : SV_TARGET
{
	// Surface Data -> BRDF Data
    half4 albedoMapValue = tex2D(_AlbedoMap, input.uv);
    half2 furUV = input.uv * _FurScale;
    half furNoise = tex2D(_FurNoiseMap, furUV).r * albedoMapValue.a;

    clip(furNoise - _AlphaCutout);

    return 0;
}


// ------------------------------ TransparentShadowSupport Pass ------------------------------

struct TranspShadowAttributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    half2 texcoord     : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};
struct TranspShadowVaryings
{
    float4 positionCS   : SV_POSITION;
    half2 texcoord     : TEXCOORD1;
    float3 normalOS: TEXCOORD2;
    float3 positionOS:TEXCOORD3;
};

float4 GetTranspShadowPositionHClip(TranspShadowAttributes input)
{
    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
    Light mylight = GetMainLight();


    //float4 positionCS = TransformWorldToHClip(positionWS);
    //Note: Applying ShadowBias to transparent shadow might cause Z-fighting (Aliasing) issues due to the proper values of
    //normal and depth bias 
    float4 positionCS = TransformWorldToHClip(positionWS);


    #if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #else
    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #endif

    return positionCS;
}

half4 TransparentFragment(TranspShadowVaryings i) : SV_Target
{
    half4 albedoMapValue = tex2D(_AlbedoMap, i.texcoord);
    half2 furUV = i.texcoord * _FurScale;
    half furNoise = tex2D(_FurNoiseMap, furUV).r * albedoMapValue.a;
    
    clip(furNoise - _AlphaCutout);
    
    return 0;
}

TranspShadowVaryings TransparentSupVertex(TranspShadowAttributes v)
{
    TranspShadowVaryings output;
    UNITY_SETUP_INSTANCE_ID(input);

    float3 origDir = v.normalOS;
    float3 gravDir = normalize(_GravityDir.xyz);
    float3 windDir = normalize(_WindDir.xyz * sin(v.positionOS.xyz * _WindFreq.w + _WindFreq.xyz * _Time.w));
    float3 gravDelta = (gravDir - origDir) * _GravityStrength;
    half3 windDelta = (windDir - origDir) * _WindStrength;

    half shellOffset=1;

    float3 direction = origDir + (gravDelta + windDelta) * shellOffset;
    half2 paramControl = lerp(half2(1,1), SAMPLE_TEXTURE2D_LOD(_ParamMaskMap, sampler_ParamMaskMap, v.texcoord,0).rg, _IntensityMaskScale);

    half3 dist = direction * _FurLength * shellOffset * paramControl.r;

    v.positionOS.xyz += dist;

    output.positionCS = GetTranspShadowPositionHClip(v);

    output.texcoord=v.texcoord;
    
    output.normalOS = v.normalOS;
    output.positionOS = v.positionOS;
    return output;
}

half4 TransparentSupFragment(TranspShadowVaryings i) : SV_Target
{
    half4 AttenuationColor = tex2D(_AlbedoMap, i.texcoord.xy);
    half4 tex;
    
    #if defined(_TRANSPARENTSHADOWFACTORBOOL_YES)
    AttenuationColor.a=_TransparentShadowFactor;
    #endif

    half3 worldView=normalize(GetMainLight().direction);
    half NdotV = max(0, dot(TransformObjectToWorldNormal(i.normalOS), worldView));

    half fresnel = pow(NdotV, _RimPower) * _RimIntensity;
    
    tex.a=(1 - fresnel*AttenuationColor.a);
    return half4(1, 1, 0, tex.a);
}
