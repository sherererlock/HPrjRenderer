#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


//for ShadowCaster Pass
float3 _LightDirection; 

struct InputDataCustom
{
    float3 worldPos;
    float3 worldVertexNormal;
    float3 worldNormal;
    float3 worldTangent;
    float3 worldBitangent;
    float3 worldView;
    half facing;
    float4 shadowCoord;
    float fogCoord;
    float3 vertexLighting;
    float2 screenUV;
    float3 bakedGI;
    float4 shadowMask;

    #ifdef _CLEARCOAT_ON
    float3 clearCoatWorldNormal;
    #endif

    half4 transpShadowCoord;
};

float3 GlossyEnvironmentReflectionCustom(float3 reflectVector, half perceptualRoughness)
{
	return GlossyEnvironmentReflection(reflectVector, perceptualRoughness, 1.0);
}

half3 GlossyEnvironmentReflectionCustom(float3 reflectVector, half perceptualRoughness, TextureCube specCube, SamplerState samplerSpecCube, float4 specCube_HDR)
{
    #if !defined(_ENVIRONMENTREFLECTIONS_OFF)
        half mip = PerceptualRoughnessToMipmapLevel(perceptualRoughness);
        half4 encodedIrradiance = SAMPLE_TEXTURECUBE_LOD(specCube, samplerSpecCube, reflectVector, mip);

        //TODO:DOTS - we need to port probes to live in c# so we can manage this manually.
        #if defined(UNITY_USE_NATIVE_HDR) || defined(UNITY_DOTS_INSTANCING_ENABLED)
            half3 irradiance = encodedIrradiance.rgb;
        #else
            half3 irradiance = DecodeHDREnvironment(encodedIrradiance, specCube_HDR);
        #endif

        return irradiance;
    #endif // GLOSSY_REFLECTIONS

    return _GlossyEnvironmentColor.rgb;
}

void MixFogCustom(inout half3 color, InputDataCustom input)
{
    #if defined(_HEIGHT_FOG_ON)
    color.rgb = MixFog(color.rgb, input.fogCoord, input.worldPos);
    #else
    color.rgb = MixFog(color.rgb, input.fogCoord);
    #endif
}

half max3(half3 i)
{
    return max(i.x, max(i.y, i.z));
}

void FlipBackfaceNormal(inout InputDataCustom input, in int cullMode)
{
    if (cullMode < 0.5 && input.facing < 0)
        input.worldNormal *= -1;
}

half shEvaluateDiffuseL1Geomerics(half L0, half3 L1, half3 n)
{
    // average energy
    half R0 = L0;

    // avg direction of incoming light
    half3 R1 = 0.5f * L1;

    // directional brightness
    half lenR1 = length(R1);

    // linear angle between normal and direction 0-1
    //half q = 0.5f * (1.0f + dot(R1 / lenR1, n));
    //half q = dot(R1 / lenR1, n) * 0.5 + 0.5;
    half q = dot(normalize(R1 + 0.000001f), n) * 0.5 + 0.5;

    // power for q
    // lerps from 1 (linear) to 3 (cubic) based on directionality
    half p = 1.0f + 2.0f * lenR1 / R0;

    // dynamic range constant
    // should vary between 4 (highly directional) and 0 (ambient)
    half a = (1.0f - lenR1 / R0) / (1.0f + lenR1 / R0);

    return R0 * (a + (1.0f - a) * (p + 1.0f) * pow(q, p));
}
//应用此方法的Shader要求不会有LightMap，一定是动态的，BakedGI只能来源于LightProbe或者Skybox
half3 SampleNonLinearBakedGI(float3 worldNormal)
{
    float3 L0 = float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
    float3 bakedGI = 0;
    bakedGI.r = shEvaluateDiffuseL1Geomerics(L0.r, unity_SHAr.xyz, worldNormal);
    bakedGI.g = shEvaluateDiffuseL1Geomerics(L0.g, unity_SHAg.xyz, worldNormal);
    bakedGI.b = shEvaluateDiffuseL1Geomerics(L0.b, unity_SHAb.xyz, worldNormal);
    return bakedGI;
}
