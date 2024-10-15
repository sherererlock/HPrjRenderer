
// ------------------------------ Material Properties ------------------------------


#include "LowShadingModelStandard.hlsl"
// ------------------------------ Surface Definition ------------------------------
// Set up surface data, using informations from properties, textures and vertex input
SURFACE_DATA InitializeSurfaceData(float2 uv0, float2 uv2, float2 uv3)
{    
	SURFACE_DATA surfaceData = (SURFACE_DATA) 0;

    SurfaceSharedData surfaceSharedData = GetSurfaceBlendData(uv2, uv3);
    surfaceData.albedo = BlendAlbedoOrDiffuseAndAlpha(surfaceSharedData, uv0, uv2, uv3, surfaceData.alpha);
	surfaceData.metallic = BlendDetail(surfaceSharedData, uv0, uv2, uv3, surfaceData.perceptualRoughness, surfaceData.occlusion);
    surfaceData.tNormal = NormalInTangentSpace(surfaceSharedData, uv0, uv2, uv3);

    #ifdef _SHEEN_ON
        half4 sheenTex = tex2D(_SheenTex, uv0 * _SheenTiling);
        surfaceData.sheen = sheenTex.rgb * _SheenColor.rgb * _SheenScale;
        surfaceData.sheenPerceptualRoughness = sheenTex.a * _SheenRoughnessScale;
    #endif

	return surfaceData;
}

#define INITIALIZE_SURFACE_DATA InitializeSurfaceData

// ------------------------------ Shading Pass ------------------------------

struct Attributes
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv0 : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
    float2 uv2 : TEXCOORD2;
    float2 uv3 : TEXCOORD3;
    half2 lightmapUV : TEXCOORD4;
};

struct Varyings
{
    float4 pos : SV_POSITION;
    float2 uv0 : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
    float2 uv2 : TEXCOORD2;
    float2 uv3 : TEXCOORD3;
    
    // tangent to world matrix, world pos stored in w
    float4 TtoW0 : TEXCOORD4;
    float4 TtoW1 : TEXCOORD5;
    float4 TtoW2 : TEXCOORD6;

    DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 7);

    float4 shadowCoord : TEXCOORD8;
    

	half4 fogFactorAndVertexLight : TEXCOORD9;
    float3 posWS: TEXCOORD10;
    int characterShadowLayerIndex : TEXCOORD11;

};

Varyings ShadingVertex (Attributes v)
{
    Varyings o = (Varyings) 0;
    VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);

    float tangentSign = v.tangent.w * GetOddNegativeScale();

    float3 normalWS = TransformObjectToWorldNormal(v.normal);
    float3 tangentWS = TransformObjectToWorldDir(v.tangent.xyz);
    float3 bitangentWS;

    bitangentWS = cross(normalWS, tangentWS) * tangentSign;
    o.pos = vertexInput.positionCS;;

    o.uv0 = v.uv0;
    o.uv1 = v.uv1;
    o.uv2 = v.uv2;
    o.uv3 = v.uv3;

    // Compute the matrix that transform directions from tangent space to world space
    // Put world space position in w component for optimization
    o.TtoW0 = float4(tangentWS.x, bitangentWS.x, normalWS.x, vertexInput.positionWS.x);
    o.TtoW1 = float4(tangentWS.y, bitangentWS.y, normalWS.y, vertexInput.positionWS.y);
    o.TtoW2 = float4(tangentWS.z, bitangentWS.z, normalWS.z, vertexInput.positionWS.z);

    OUTPUT_LIGHTMAP_UV(v.lightmapUV, unity_LightmapST, o.lightmapUV);
    OUTPUT_SH(normalWS.xyz, o.vertexSH);
    o.characterShadowLayerIndex = 0;

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
	    o.shadowCoord = GetMixedCharactersShadowCoord(vertexInput, 0);
	#endif

    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalWS);
    half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
    o.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

    return o;
}
void keywordConfigure()
{
    _AlphaPremultiply = _RenderingMode==2?1:0;
}

half4 ShadingFragment (Varyings i, half facing : VFACE) : SV_TARGET
{
    keywordConfigure();
    float2 uv0 = RedirectUV(i.uv0, i.uv1, i.uv2, i.uv3, _UV0);
    float2 uv2 = RedirectUV(i.uv0, i.uv1, i.uv2, i.uv3, _UV2);
    float2 uv3 = RedirectUV(i.uv0, i.uv1, i.uv2, i.uv3, _UV3);

	// Surface Data -> BRDF Data
	SURFACE_DATA surfaceData = INITIALIZE_SURFACE_DATA(uv0, uv2, uv3);

    // Input Data
    InputDataCustom inputData = (InputDataCustom) 0;
    inputData.worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
    inputData.worldVertexNormal = normalize(float3(i.TtoW0.z, i.TtoW1.z, i.TtoW2.z));
    inputData.worldNormal = normalize(float3(dot(i.TtoW0.xyz, surfaceData.tNormal), dot(i.TtoW1.xyz, surfaceData.tNormal), dot(i.TtoW2.xyz, surfaceData.tNormal)));

    inputData.worldView = normalize(_WorldSpaceCameraPos.xyz - inputData.worldPos);
    inputData.facing = facing;
    FlipBackfaceNormal(inputData, _CullMode);

    #if defined(_COLOR_CAST_ON)
        surfaceData.albedo *= lerp(float3(1,1,1),tex2D(_ColorCastMap, half2(saturate(dot(inputData.worldView, inputData.worldNormal)) * _ColorCastTiling, 0.5)).rgb, _ColorCastIntensity);
    #endif

    #if defined(_SPARKLE_ON) //闪点
        half2 uv4 = RedirectUV(i.uv0, i.uv1, i.uv2, i.uv3, _UV4);
        InitializeSparkleSurfaceData(uv4, surfaceData.sparkleColor, surfaceData.sparkleNoHPhase, surfaceData.sparkleScale, surfaceData.sparkleDependency, surfaceData.sparklePerceptualRoughness);
    #endif
    
	BRDF_DATA brdfData = INITIALIZE_BRDF_DATA(surfaceData);
    
    //_ALPHAPREMULTIPLY_ON判定
    brdfData.diffColor *= (1.0h -  _AlphaPremultiply) +  _AlphaPremultiply * surfaceData.alpha;
    brdfData.alpha = (1.0h -  _AlphaPremultiply) * surfaceData.alpha +  _AlphaPremultiply * (surfaceData.alpha * brdfData.oneMinusReflectivity + brdfData.reflectivity);

    half clipAlpha = 1.0h;

	#ifdef _ALPHATEST_ON
    //clip(surfaceData.alpha - _Cutoff);
        clipAlpha = step(0, surfaceData.alpha - _Cutoff);
	#endif

	#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
	    inputData.shadowCoord = i.shadowCoord;
	#else
	    inputData.shadowCoord = float4(0, 0, 0, 0);
	#endif
    
    
    inputData.fogCoord = i.fogFactorAndVertexLight.x;
    inputData.vertexLighting = i.fogFactorAndVertexLight.yzw;
    inputData.bakedGI = SampleNonLinearBakedGI(inputData.worldNormal) * _IndirectDiffuseScale;
    inputData.bakedGI = max(max(inputData.bakedGI.r, inputData.bakedGI.g), inputData.bakedGI.b) * _IndirectDiffuseColor * _UseIndirectDiffuseColor + inputData.bakedGI * (1 - _UseIndirectDiffuseColor);
    inputData.shadowMask = SAMPLE_SHADOWMASK(i.lightmapUV);

    POST_INITIALIZE_BRDF_DATA(brdfData, inputData);
    // Lighting
    half3 color = half3(0.0, 0.0, 0.0);
    Light mainLight = GetMainLight(inputData.shadowCoord);
    
    MixRealtimeAndBakedGI(mainLight, inputData.worldNormal, inputData.bakedGI);
    GLOBAL_ILLUMINATION(color, brdfData, inputData);
    LIGHTING_MAIN(color, brdfData, inputData, mainLight);

    half lightAtten = 0;
    lightAtten += saturate(dot(inputData.worldNormal, mainLight.direction));
    color += pow( saturate( 1 - lightAtten), _DarkPow) * _DarkColor;

    /*
    #ifdef _ADDITIONAL_LIGHTS
	    uint pixelLightCount = GetAdditionalLightsCount();
	    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
	    {
	        Light addLight = GetAdditionalLight(lightIndex, inputData.worldPos, inputData.shadowMask, _SupportingCharacterIndex);
	        LIGHTING_ADD(color, brdfData, inputData, addLight);
	    }
	#endif
	*/

    half NdotV = max(0, dot(inputData.worldNormal, inputData.worldView));
    NdotV = smoothstep(0, 1.0, 1.0 - NdotV);
    half fresnel = max(pow(NdotV, _InSideRimPower), 1e-3);

    half3 frensnelEmissive = lerp(half3(0, 0, 0), _InSideRimColor.rgb, fresnel) * _InSideRimIntensity;
    color += frensnelEmissive;

    MixFogCustom(color, inputData);

    half outAlpha = _RenderingMode > 0.5 ? brdfData.alpha : 1.0;

    outAlpha *= clipAlpha;

    //特效
    if(_EffectType == 1){
        //Dissolve  (_EffectType == 1)
        half dissolveAlpha = outAlpha;

        half dissolved = step(_DissolveDirection, inputData.worldPos.y);
        dissolved = _DissolveReverse ? (1 - dissolved) : dissolved;
        dissolveAlpha = dissolved ? 0 : 1;

        half cutBorder = (inputData.worldPos.y < (_DissolveDirection + _DissolveCutWidth) && inputData.worldPos.y > (_DissolveDirection - _DissolveCutWidth));
        half distance = abs(inputData.worldPos.y - _DissolveDirection + (_DissolveReverse ? _DissolveCutWidth : _DissolveCutWidth * -1));
        dissolveAlpha = cutBorder ? outAlpha * (distance * _DissolveDivisor) : dissolveAlpha;

        outAlpha *= dissolveAlpha;
    }
    else if(_EffectType == 2)
    {
        //Sweep  (_EffectType == 2)
        half rad = _SweepRotator * UNITY_PI_DIV_180;
        half2 uvSweepTex = inputData.worldPos.xy * _SweepTex_ST.xy + _SweepTex_ST.zw;
        half2 uvRotator = mul( uvSweepTex - half2(0.5,0.5) , half2x2(cos(rad), -sin(rad), sin(rad), cos(rad) )) + half2(0.5,0.5);

        half4 lightSweepAlbedo = tex2D( _SweepTex, uvRotator );

        outAlpha = (1 - lightSweepAlbedo.r) * _ForceTransparent * outAlpha  + outAlpha * ( 1- _ForceTransparent);
    }


    #if defined(tattoAlpha)
    outAlpha *= 1.0 + _TattoAlphaOffset * tattoAlpha;
    #endif
    #if defined(_SPARKLE_ON) //闪点
    outAlpha = saturate(pow(brdfData.sparkleSpecTerm,_SparkleEnhancePow) * surfaceData.sparkleColor.a * _SparkleAplhaEnhance * 10.0f + outAlpha);
    #endif

    return half4(color, outAlpha);
}

// ------------------------------ Meta Pass ------------------------------

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"

struct MetaAttributes
{
    float4 vertex : POSITION;
    half2 uv0 : TEXCOORD0;
    half2 uv1 : TEXCOORD1;
    half2 uv2 : TEXCOORD2;
    half2 uv3 : TEXCOORD3;
    half2 lightmapUV : TEXCOORD4;
    half2 dynamicLightmapUV : TEXCOORD5;
};

struct MetaVaryings
{
    float4 pos : SV_POSITION;
    half2 uv0 : TEXCOORD0;
    half2 uv1 : TEXCOORD1;
    half2 uv2 : TEXCOORD2;
    half2 uv3 : TEXCOORD3;
};

MetaVaryings MetaVertex(MetaAttributes v)
{
    MetaVaryings o = (MetaVaryings) 0;
    o.pos = MetaVertexPosition(v.vertex, v.lightmapUV, v.dynamicLightmapUV, unity_LightmapST, unity_DynamicLightmapST);
    o.uv0 = v.uv0;
    o.uv1 = v.uv1;
    o.uv2 = v.uv2;
    o.uv3 = v.uv3;
    return o;
}

half4 MetaFragment(MetaVaryings i) : SV_Target
{
    half2 uv0 = RedirectUV(i.uv0, i.uv1, i.uv2, i.uv3, _UV0);
    half2 uv2 = RedirectUV(i.uv0, i.uv1, i.uv2, i.uv3, _UV2);
    half2 uv3 = RedirectUV(i.uv0, i.uv1, i.uv2, i.uv3, _UV3);

	// Surface Data -> BRDF Data
	SURFACE_DATA surfaceData = INITIALIZE_SURFACE_DATA(uv0, uv2, uv3);
	BRDF_DATA brdfData = INITIALIZE_BRDF_DATA(surfaceData);

	#ifdef _ALPHATEST_ON
		clip(surfaceData.alpha - _Cutoff);
	#endif

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
    half3 normalOS     : NORMAL;
    half2 uv0 : TEXCOORD0;
    half2 uv1 : TEXCOORD1;
    half2 uv2 : TEXCOORD2;
    half2 uv3 : TEXCOORD3;
};

struct ShadowPassVaryings
{
    half2 uv0 : TEXCOORD0;
    half2 uv1 : TEXCOORD1;
    half2 uv2 : TEXCOORD2;
    half2 uv3 : TEXCOORD3;
    float4 positionCS   : SV_POSITION;
};

half4 GetShadowPositionHClip(ShadowPassAttributes input)
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
    output.uv0 = input.uv0;
    output.uv1 = input.uv1;
    output.uv2 = input.uv2;
    output.uv3 = input.uv3;
    output.positionCS = GetShadowPositionHClip(input);
    return output;
}

half4 ShadowPassFragment(ShadowPassVaryings input) : SV_TARGET
{
    #ifdef _ALPHATEST_ON
    half mainAlbedo = _MainTex.Sample(sampler_MainTex, input.uv0).a;
    clip(mainAlbedo - _Cutoff);
    #endif
    
    return 0;
}
// ------------------------------ PlanarShadow Pass ------------------------------

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

struct PlanarShadowPassAttributes
{
    float4 positionOS   : POSITION;
};

struct PlanarShadowPassVaryings
{
    float4 positionCS   : SV_POSITION;
    half4 color   : COLOR;

};

PlanarShadowPassVaryings PlanarShadowPassVertex(PlanarShadowPassAttributes input)
{
    PlanarShadowPassVaryings output = (PlanarShadowPassVaryings) 0;
    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    half3 lightDir = normalize(_LightDirection);

    float3 shadowPos;

    shadowPos.y = min(positionWS.y,0);
    shadowPos.xz = positionWS.xz - lightDir.xz * max(0, positionWS.y - 0) / lightDir.y;
    output.positionCS = TransformWorldToHClip(shadowPos);

    half4 color;
    color.rgb = half3(0.1, 0.1, 0.1);
    half3 center = half3(unity_ObjectToWorld[0].w, 0, unity_ObjectToWorld[2].w);

    half falloff = 1.0 - saturate(distance(shadowPos, center) * 0.3);

    color.a = falloff;
    output.color = color;
    return output;
}

half4 PlanarShadowPassFragment(PlanarShadowPassVaryings input) : SV_TARGET
{
    return input.color;
}

// ------------------------------ PlanarShadowTrans Pass ------------------------------

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

struct PlanarShadowTransPassAttributes
{
    float4 positionOS   : POSITION;
    half3 normalOS     : NORMAL;
    half2 uv0 : TEXCOORD0;
    half2 uv1 : TEXCOORD1;
    half2 uv2 : TEXCOORD2;
    half2 uv3 : TEXCOORD3;
};

struct PlanarShadowTransPassVaryings
{
    float4 positionCS   : SV_POSITION;
    half4 color   : COLOR;
    half2 uv0 : TEXCOORD0;
    half2 uv1 : TEXCOORD1;
    half2 uv2 : TEXCOORD2;
    half2 uv3 : TEXCOORD3;
};

PlanarShadowTransPassVaryings PlanarShadowTransPassVertex(PlanarShadowTransPassAttributes input)
{
    PlanarShadowTransPassVaryings output = (PlanarShadowTransPassVaryings) 0;
    output.uv0 = input.uv0;
    output.uv1 = input.uv1;
    output.uv2 = input.uv2;
    output.uv3 = input.uv3;
    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    half3 lightDir = normalize(_LightDirection);
    half3 shadowPos;
    shadowPos.y = min(positionWS.y,0);
    shadowPos.xz = positionWS.xz - lightDir.xz * max(0, positionWS.y - 0) / lightDir.y;
    output.positionCS = TransformWorldToHClip(shadowPos);
    half4 color;
    color.rgb = half3(0.3, 0.3, 0.3);
    half3 center = half3(unity_ObjectToWorld[0].w, 0, unity_ObjectToWorld[2].w);
    half falloff = 1.0 - saturate(distance(shadowPos, center) * 0.3);
    //half3 worldViewDir = normalize(_WorldSpaceCameraPos - positionWS);
    //half factor = saturate(1 - dot(normalize(TransformObjectToWorld(input.normalOS)), worldViewDir) + 0.1);
    color.a = falloff;
    output.color = color;
    return output;
}

half4 PlanarShadowTransPassFragment(PlanarShadowTransPassVaryings input) : SV_TARGET
{
    half mainAlbedo = _MainTex.Sample(sampler_MainTex, input.uv0).a;
    input.color.a *= mainAlbedo;
    return input.color;
}

// ------------------------------ DepthOnly Pass ------------------------------

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

struct DepthOnlyAttributes
{
    float4 position     : POSITION;
    half2 uv0 : TEXCOORD0;
    half2 uv1 : TEXCOORD1;
    half2 uv2 : TEXCOORD2;
    half2 uv3 : TEXCOORD3;
};

struct DepthOnlyVaryings
{
    half2 uv0 : TEXCOORD0;
    half2 uv1 : TEXCOORD1;
    half2 uv2 : TEXCOORD2;
    half2 uv3 : TEXCOORD3;
    float4 positionCS   : SV_POSITION;
};

DepthOnlyVaryings DepthOnlyVertex(DepthOnlyAttributes input)
{
    DepthOnlyVaryings output = (DepthOnlyVaryings) 0;
    output.uv0 = input.uv0;
    output.uv1 = input.uv1;
    output.uv2 = input.uv2;
    output.uv3 = input.uv3;
    output.positionCS = TransformObjectToHClip(input.position.xyz);
    return output;
}

half4 DepthOnlyFragment(DepthOnlyVaryings input) : SV_TARGET
{
    #ifdef _ALPHATEST_ON
        SURFACE_DATA surfaceData = (SURFACE_DATA) 0;

        SurfaceSharedData surfaceSharedData = GetSurfaceBlendData(input.uv2, input.uv3);
        half detailWeight = surfaceSharedData.detailWeight;
        // color 叠加顺序 2u 3u 4u 1u
        half alpha = 1;
        half4 mainAlbedo = _MainTex.Sample(sampler_MainTex, input.uv0); //1u 正片叠底
        #if defined(_DETAIL_ON) //uv3
        alpha *= 1 + step(1, _DetailBlend) * (detailWeight - 1); //正片叠底才会乘透明度
        #endif

        alpha *= mainAlbedo.a * _ColorTint.a;//主体与布料透明 正片叠底
            
        clip(alpha - _Cutoff);
    #endif
    
    return 0;
}
