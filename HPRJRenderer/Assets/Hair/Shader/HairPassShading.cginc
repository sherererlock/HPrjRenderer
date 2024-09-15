#ifndef HAIRPASS_MARSCHNER
#define HAIRPASS_MARSCHNER
#include "HairShading.cginc"
#include "HairShadow.cginc"



float3 GlossyEnvironmentReflectionCustom(float3 reflectVector, half perceptualRoughness)
{
    half mip = PerceptualRoughnessToMipmapLevel(perceptualRoughness);
    half4 encodedIrradiance = SAMPLE_TEXTURECUBE_LOD(_charCubeMap, samplerunity_SpecCube0, reflectVector, mip);
    half3 irradiance = DecodeHDREnvironment(encodedIrradiance, unity_SpecCube0_HDR);
    return irradiance;
	//return GlossyEnvironmentReflection(reflectVector, perceptualRoughness, 1.0);
}

struct appdata
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0;
    float2 uv2 : TEXCOORD1;
    float2 uv3 : TEXCOORD2;
    float4 vertexColor : COLOR;
};

struct v2f
{
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float4 uv2 : TEXCOORD7;

    // tangent to world matrix, world pos stored in w
    float4 TtoW0 : TEXCOORD1;
    float4 TtoW1 : TEXCOORD2;
    float4 TtoW2 : TEXCOORD3;

    float fogFactor : TEXCOORD4;

    #ifdef _MAIN_LIGHT_SHADOWS
        float4 shadowCoord : TEXCOORD5;// mainlight light space coords
    #endif

    float4 screenPos : TEXCOORD6;
    float4 vertexColor : TEXCOORD8;
    int characterShadowLayerIndex : TEXCOORD9;
};

v2f vert (appdata v)
{
    v2f o = (v2f)0;
    VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(v.normal, v.tangent);

    o.pos = vertexInput.positionCS;
    o.uv = v.uv;
    o.uv2.xy = v.uv2;
    o.uv2.zw = v.uv3;
    o.vertexColor = v.vertexColor;

    // Compute the matrix that transform directions from tangent space to world space
    // Put world space position in w component for optimization
    o.TtoW0 = float4(normalInput.tangentWS.x, normalInput.bitangentWS.x, normalInput.normalWS.x, vertexInput.positionWS.x);
    o.TtoW1 = float4(normalInput.tangentWS.y, normalInput.bitangentWS.y, normalInput.normalWS.y, vertexInput.positionWS.y);
    o.TtoW2 = float4(normalInput.tangentWS.z, normalInput.bitangentWS.z, normalInput.normalWS.z, vertexInput.positionWS.z);

    o.fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

    #if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
    o.shadowCoord = GetMixedCharactersShadowCoord(vertexInput, _SupportingCharacterIndex);
    #endif

    o.screenPos = ComputeScreenPos(o.pos);

    return o;
}
half _IndirectDiffuseScale;

inline float randomNoise(half2 uv)
{
    return frac(sin(dot(uv, half2(2.9, 8.2))) * 0.5);
}
inline float valueNoise(float2 uv)
{
    float2 intPos = floor(uv);
    float2 fracPos = frac(uv);
    float2 u = fracPos * fracPos * (3.0 - 2.0 * fracPos);
    uv = abs(frac(uv) - 0.5);

    float va = randomNoise(intPos + float2(0.0, 0.0));
    float vb = randomNoise(intPos + float2(1.0, 0.0));
    float vc = randomNoise(intPos + float2(0.0, 1.0));
    float vd = randomNoise(intPos + float2(1.0, 1.0));
    float value1 = lerp(va, vb, u.x);
    float value2 = lerp(vc, vd, u.x);
    float value = lerp(value1, value2, u.y);
    return value;
}

float4 frag (v2f i) : SV_Target
{
    float4 mainMap = tex2D(_MainMap, i.uv);
    #if _HAIRUV_UV1 
        float4 colorMap = tex2D(_ColorMap, i.uv);
    #else
        float4 colorMap = tex2D(_ColorMap, i.uv2.xy);
    #endif
    float4 occMap = tex2D(_BakedOcclusionMap, i.uv2);

    // calculate params for shading model
    float alpha = mainMap.a;
    float id = mainMap.r;
    float root = mainMap.g;
    float occ = saturate(lerp(1.0, mainMap.b * occMap.r, _OcclusionIntensity));
    float roughness = max(0.0001, square(_PerceptualRoughness));

    float3 albedo = colorMap.rgb * _Color.rgb;
    #ifdef _GRADIENTMODE_ROOT
        float gradient = root;
    #else
        float gradient = 1.0 - i.uv2.w;
    #endif
    gradient = saturate(gradient * tan((2.0 - _RootPower) * _PI / 4));
    albedo *= lerp(_RootColor, _TipColor, gradient).rgb;
    albedo *= lerp(1, id * 2, _BrightnessVariation);
    albedo = HueShift(albedo, (id - 0.5) * _HueVariation);
    //albedo *= HueShift(lerp(1, float3(1,0,0), _HueVariation), id);

    float3 flow = FlowDir(i.uv);// tangent space flow dir
    flow = normalize(flow + float3(0, 0, (id - 0.5) * _FlowVariation));

    // calculate position, flow dir(T), view dir(V), fake normal, all in world space
    float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
    float3 worldNormal = normalize(float3(i.TtoW0.z, i.TtoW1.z, i.TtoW2.z));
    float3 T = normalize(half3(dot(i.TtoW0.xyz, flow), dot(i.TtoW1.xyz, flow), dot(i.TtoW2.xyz, flow)));
    float3 V = normalize(_WorldSpaceCameraPos.xyz - worldPos);
    float3 fakeNormal = normalize(V - T * dot(V, T));

    #if defined(_VIS_ALPHA)
        return float4(alpha, alpha, alpha, 1.0);
    #endif
    
    half clipAlpha = 1.0f;

    // alpha test
    #ifdef OPAQUE_PASS
        //clip(alpha - _AlphaCutoff);
        clipAlpha = step(0, alpha - _AlphaCutoff);
        alpha *= clipAlpha; 
    #else
        // clip(_AlphaCutoff - alpha);
        // alpha /= _AlphaCutoff;
        alpha = saturate(alpha / _AlphaCutoff);
    #endif

    // visualization
    #if defined(_VIS_COLOR)
        return float4(albedo, alpha);
    #elif defined(_VIS_ID)
        return float4(id, id, id, alpha);
    #elif defined(_VIS_ROOT)
        return float4(root, root, root, alpha);
    #elif defined(_VIS_OCCLUSION)
        return float4(occ, occ, occ, alpha);
    #elif defined(_VIS_FLOW)
        return float4(T, alpha);
    #else
        // _VIS_OFF, do nothing
    #endif

    float hairShadow = SampleHairShadow(i.screenPos.xy / i.screenPos.w);
    #if !defined(_HAIR_SHADOWS)
        hairShadow = saturate(lerp(1.0, tex2D(_BakedShadowTex, i.uv2.xy).r, _BakedShadowIntensity));
    #endif

    hairShadow = saturate(lerp(1.0, hairShadow, _ShadowIntensity));
    hairShadow = lerp(hairShadow, 1.0, root * _ShadowRoot);
    #ifdef _LIGHTPATH_SHADOW
        return float4(hairShadow, hairShadow, hairShadow, alpha);
    #endif

    float3 col = float3(0.0, 0.0, 0.0);
    float4 lighting_params = float4(_Scatter, _HighlightIntensity, _InnerHighlightIntensity, _BacklitIntensity);
    float3 L;
    float atten;

    // Main Light
    #if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
        float4 shadowCoord = i.shadowCoord;
    #else
        float4 shadowCoord = float4(0, 0, 0, 0);
    #endif
    Light mainLight = GetMainLight(shadowCoord);
    //return float4(mainLight.color,1);

    L = normalize(mainLight.direction);
    atten = hairShadow;

    #if defined(_LIGHTCOMPONENT_ALL) | defined(_LIGHTCOMPONENT_DIRECT)
        col += mainLight.color * atten * HairShading(albedo, roughness, lighting_params, L, V, T, atten, root, 0.0);
    #endif

    // Additional Light
    // force additional light to be calculated per-pixel
    /*
    #if defined(_ADDITIONAL_LIGHTS) || defined(_ADDITIONAL_LIGHTS_VERTEX)
        int pixelLightCount = GetAdditionalLightsCount();

        for (int k = 0; k < pixelLightCount; ++k)
        {
            Light addLight = GetAdditionalLight(k, worldPos, float4(1,1,1,1), _SupportingCharacterIndex);
            L = normalize(addLight.direction);
            atten = hairShadow;
            #if defined(_LIGHTCOMPONENT_ALL) | defined(_LIGHTCOMPONENT_DIRECT)
                col += addLight.color * atten * HairShadingSimple(albedo, roughness, lighting_params, L, V, T, 1.0, root, 0.0) * _AddLightIntensity;
            #endif
        }
    #endif
    */
    #if defined(_ADDITIONAL_LIGHTS)
    int pixelLightCount = GetAdditionalLightsCount();
    for (int k = 0; k < pixelLightCount; ++k)
    {
        int perObjectLightIndex = GetPerObjectLightIndex(k);

        Light addLight = GetAdditionalLight(k, worldPos, float4(1,1,1,1));
        L = normalize(addLight.direction);

        atten = hairShadow * addLight.shadowAttenuation * addLight.distanceAttenuation;
        col += addLight.color * atten * HairShadingSimple(albedo, roughness, lighting_params, L, V, T, 1.0, root, 0.0) * _AddLightIntensity;
    }
    #endif

    // Environment Lighting
    // use fake normal to sample SH, call SampleSH() directly to force totally per-pixel sampling
    float3 reflectVector = reflect(-V, fakeNormal);
    float3 env = GlossyEnvironmentReflectionCustom(reflectVector, saturate(_PerceptualRoughness + 0.2));
    float3 ambient = SampleSH(worldNormal) * _IndirectDiffuseScale;
    #if defined(_LIGHTCOMPONENT_ALL) | defined(_LIGHTCOMPONENT_INDIRECT)
        lighting_params.x = 0;
        col += env * HairShadingSimple(albedo, roughness, lighting_params, reflectVector, V, T, 1.0, 0.0, 0.2) * _IndirectIntensity;
        #if defined(_LIGHTPATH_ALL) | defined(_LIGHTPATH_SCATTER)
            col += ambient * ScatterTerm_Simple(albedo, roughness, _Scatter, fakeNormal, V, T, 1.0, 0.0, 0.2) * _IndirectIntensity;
        #endif
    #endif

    float3 shadowTint = lerp(_ShadowTintColor.rgb, 1, pow(abs(hairShadow * occ), _ShadowTintPower));
    col *= _Brightness * occ * shadowTint;

    #if defined(_EFFECT_ON)
        //Dissolve  (_EffectType == 1)
        half dissolveAlpha = alpha;

        half dissolved = step(_DissolveDirection, worldPos.y);
        dissolved = _DissolveReverse ? (1 - dissolved) : dissolved;
        dissolveAlpha = dissolved ? 0 : 1;

        half cutBorder = (worldPos.y < (_DissolveDirection + _DissolveCutWidth) && worldPos.y > (_DissolveDirection - _DissolveCutWidth));
        half distance = abs(worldPos.y - _DissolveDirection + (_DissolveReverse ? _DissolveCutWidth : _DissolveCutWidth * -1));
        dissolveAlpha = cutBorder ? alpha * (distance * _DissolveDivisor) : dissolveAlpha;

        alpha = (_EffectType == 1) ? dissolveAlpha * alpha : alpha;

        //Sweep  (_EffectType == 2)
        half rad = _SweepRotator * UNITY_PI_DIV_180;
        half2 uvSweepTex = worldPos.xy * _SweepTex_ST.xy + _SweepTex_ST.zw;
        half2 uvRotator = mul( uvSweepTex - half2(0.5,0.5) , half2x2(cos(rad), -sin(rad), sin(rad), cos(rad) )) + half2(0.5,0.5);

        half x = fmod(abs(uvSweepTex.x), 1.0) * 2;
        x = (x > 1) ? 2 - x : x;
        half3 col1 = pow(half3(255, 245, 172) / 255.0, 2.2);
        half3 col2 = pow(half3(255, 203, 111) / 255.0, 2.2);
        half3 col3 = pow(half3(235, 129, 199) / 255.0, 2.2);
        half3 col4 = pow(half3(176, 123, 238) / 255.0, 2.2);
        half3 col5 = pow(half3(70, 174, 238) / 255.0, 2.2);
        half3 col6 = pow(half3(27, 222, 237) / 255.0, 2.2);
        half3 rColor = step(0.0, x) * step(x, 0.2) * lerp(col1, col2, max(pow(fmod(x, 0.2) * 5, 1.5), 1e-3))
                     + step(0.2, x) * step(x, 0.4) * lerp(col2, col3, max(pow(fmod(x, 0.2) * 5, 1.5), 1e-3))
                     + step(0.4, x) * step(x, 0.6) * lerp(col3, col4, max(pow(fmod(x, 0.2) * 5, 1.5), 1e-3))
                     + step(0.6, x) * step(x, 0.8) * lerp(col4, col5, max(pow(fmod(x, 0.2) * 5, 1.5), 1e-3))
                     + step(0.8, x) * step(x, 1.0) * lerp(col5, col6, max(pow(fmod(x, 0.2) * 5, 1.5), 1e-3));
        half4 rampColor = half4(rColor, 1);

        // half4 rampColor = tex2D( _RampTex,  uvSweepTex);
        half4 lightSweepAlbedo = tex2D( _SweepTex, uvRotator);
        half4 outputLightSweep = saturate(lightSweepAlbedo * _SweepColor * _SweepColorIntensity * _SweepIntensity * rampColor);

        half3 sweepColor = outputLightSweep.a * outputLightSweep.rgb + col;
        half3 sweepAlpha = alpha;

        col = (_EffectType == 2) ? sweepColor : col;
        alpha = (_EffectType == 2) ? sweepAlpha * alpha : alpha;
    #endif

    return float4(col, alpha);
}

float4 lowFrag (v2f i) : SV_Target
{
    float4 mainMap = tex2D(_MainMap, i.uv);
    #if _HAIRUV_UV1 
        float4 colorMap = tex2D(_ColorMap, i.uv);
    #else
        float4 colorMap = tex2D(_ColorMap, i.uv2.xy);
    #endif

    // calculate params for shading model
    float alpha = mainMap.a;
    float id = mainMap.r;
    float root = mainMap.g;
    float occ = saturate(lerp(1.0, mainMap.b.r, _OcclusionIntensity));
    float roughness = max(0.0001, square(_PerceptualRoughness));

    float3 albedo = colorMap.rgb * _Color.rgb;
    #ifdef _GRADIENTMODE_ROOT
        float gradient = root;
    #else
        float gradient = 1.0 - i.uv2.w;
    #endif
    gradient = saturate(gradient * tan((2.0 - _RootPower) * _PI / 4));
    albedo *= lerp(_RootColor, _TipColor, gradient).rgb;
    albedo *= lerp(1, id * 2, _BrightnessVariation);
    albedo = HueShift(albedo, (id - 0.5) * _HueVariation);
    //albedo *= HueShift(lerp(1, float3(1,0,0), _HueVariation), id);

    float3 flow = FlowDir(i.uv);// tangent space flow dir
    flow = normalize(flow + float3(0, 0, (id - 0.5) * _FlowVariation));

    // calculate position, flow dir(T), view dir(V), fake normal, all in world space
    float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
    float3 worldNormal = normalize(float3(i.TtoW0.z, i.TtoW1.z, i.TtoW2.z));
    float3 T = normalize(half3(dot(i.TtoW0.xyz, flow), dot(i.TtoW1.xyz, flow), dot(i.TtoW2.xyz, flow)));
    float3 V = normalize(_WorldSpaceCameraPos.xyz - worldPos);
    float3 fakeNormal = normalize(V - T * dot(V, T));

    #if defined(_VIS_ALPHA)
        return float4(alpha, alpha, alpha, 1.0);
    #endif

    half clipAlpha = 1.0f;

    // alpha test
    #ifdef OPAQUE_PASS
    //clip(alpha - _AlphaCutoff);
    clipAlpha = step(0, alpha - _AlphaCutoff);
    alpha *= clipAlpha; 
    #else
    // clip(_AlphaCutoff - alpha);
    // alpha /= _AlphaCutoff;
    alpha = saturate(alpha / _AlphaCutoff);
    #endif

    // visualization
    #if defined(_VIS_COLOR)
        return float4(albedo, alpha);
    #elif defined(_VIS_ID)
        return float4(id, id, id, alpha);
    #elif defined(_VIS_ROOT)
        return float4(root, root, root, alpha);
    #elif defined(_VIS_OCCLUSION)
        return float4(occ, occ, occ, alpha);
    #elif defined(_VIS_FLOW)
        return float4(T, alpha);
    #else
        // _VIS_OFF, do nothing
    #endif

    float hairShadow = saturate(lerp(1.0, tex2D(_BakedShadowTex, i.uv2.xy).r, _BakedShadowIntensity));

    hairShadow = saturate(lerp(1.0, hairShadow, _ShadowIntensity));
    hairShadow = lerp(hairShadow, 1.0, root * _ShadowRoot);
    #ifdef _LIGHTPATH_SHADOW
        return float4(hairShadow, hairShadow, hairShadow, alpha);
    #endif

    float3 col = float3(0.0, 0.0, 0.0);
    float4 lighting_params = float4(_Scatter, _HighlightIntensity, _InnerHighlightIntensity, _BacklitIntensity);
    float3 L;
    float atten;

    // Main Light
    #if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
        float4 shadowCoord = i.shadowCoord;
    #else
        float4 shadowCoord = float4(0, 0, 0, 0);
    #endif
    Light mainLight = GetMainLight(shadowCoord);

    L = normalize(mainLight.direction);
    atten = hairShadow;

    #if defined(_LIGHTCOMPONENT_ALL) | defined(_LIGHTCOMPONENT_DIRECT)
        col += mainLight.color * atten * HairShadingSimple(albedo, roughness, lighting_params, L, V, T, atten, root, 0.0);
    #endif

    float3 shadowTint = lerp(_ShadowTintColor.rgb, 1, pow(abs(atten * occ), _ShadowTintPower));
    col *= _Brightness * occ * shadowTint;

    #if defined(_EFFECT_ON)
        //Dissolve  (_EffectType == 1)
        half dissolveAlpha = alpha;

        half dissolved = step(_DissolveDirection, worldPos.y);
        dissolved = _DissolveReverse ? (1 - dissolved) : dissolved;
        dissolveAlpha = dissolved ? 0 : 1;

        half cutBorder = (worldPos.y < (_DissolveDirection + _DissolveCutWidth) && worldPos.y > (_DissolveDirection - _DissolveCutWidth));
        half distance = abs(worldPos.y - _DissolveDirection + (_DissolveReverse ? _DissolveCutWidth : _DissolveCutWidth * -1));
        dissolveAlpha = cutBorder ? alpha * (distance * _DissolveDivisor) : dissolveAlpha;

        alpha = (_EffectType == 1) ? dissolveAlpha * alpha : alpha;

        //Sweep  (_EffectType == 2)
        half rad = _SweepRotator * UNITY_PI_DIV_180;
        half2 uvSweepTex = worldPos.xy * _SweepTex_ST.xy + _SweepTex_ST.zw;
        half2 uvRotator = mul( uvSweepTex - half2(0.5,0.5) , half2x2(cos(rad), -sin(rad), sin(rad), cos(rad) )) + half2(0.5,0.5);

        half x = fmod(abs(uvSweepTex.x), 1.0) * 2;
        x = (x > 1) ? 2 - x : x;
        half3 col1 = pow(half3(255, 245, 172) / 255.0, 2.2);
        half3 col2 = pow(half3(255, 203, 111) / 255.0, 2.2);
        half3 col3 = pow(half3(235, 129, 199) / 255.0, 2.2);
        half3 col4 = pow(half3(176, 123, 238) / 255.0, 2.2);
        half3 col5 = pow(half3(70, 174, 238) / 255.0, 2.2);
        half3 col6 = pow(half3(27, 222, 237) / 255.0, 2.2);
        half3 rColor = step(0.0, x) * step(x, 0.2) * lerp(col1, col2, max(pow(fmod(x, 0.2) * 5, 1.5), 1e-3))
                     + step(0.2, x) * step(x, 0.4) * lerp(col2, col3, max(pow(fmod(x, 0.2) * 5, 1.5), 1e-3))
                     + step(0.4, x) * step(x, 0.6) * lerp(col3, col4, max(pow(fmod(x, 0.2) * 5, 1.5), 1e-3))
                     + step(0.6, x) * step(x, 0.8) * lerp(col4, col5, max(pow(fmod(x, 0.2) * 5, 1.5), 1e-3))
                     + step(0.8, x) * step(x, 1.0) * lerp(col5, col6, max(pow(fmod(x, 0.2) * 5, 1.5), 1e-3));
        half4 rampColor = half4(rColor, 1);

        // half4 rampColor = tex2D( _RampTex,  uvSweepTex);
        half4 lightSweepAlbedo = tex2D( _SweepTex, uvRotator);
        half4 outputLightSweep = saturate(lightSweepAlbedo * _SweepColor * _SweepColorIntensity * _SweepIntensity * rampColor);

        half3 sweepColor = outputLightSweep.a * outputLightSweep.rgb + col;
        half3 sweepAlpha = alpha;

        col = (_EffectType == 2) ? sweepColor : col;
        alpha = (_EffectType == 2) ? sweepAlpha * alpha : alpha;
    #endif


    return float4(col, alpha);
}

#endif
