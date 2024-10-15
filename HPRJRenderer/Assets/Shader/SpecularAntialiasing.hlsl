#ifndef UNIVERSAL_SPECULARAA_INCLUDED
#define UNIVERSAL_SPECULARAA_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


half SpecularAASmoothness(half percepSmoothness, half3 normalWS)
{
    half perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(percepSmoothness);
    half roughness = max(PerceptualRoughnessToRoughness(perceptualRoughness), HALF_MIN_SQRT);
    half3 dxy = max(abs(ddx(normalWS)), abs(ddy(normalWS)));
    half roughnessFactor = 0.04 + max(max(dxy.x, dxy.y), dxy.z);
    roughness = max(roughness, roughnessFactor);
    half newPercepSmoothness = PerceptualRoughnessToPerceptualSmoothness(RoughnessToPerceptualRoughness(roughness));
    return newPercepSmoothness;
}

half SpecularAARoughness(half percepRoughness, half3 normalWS)
{
    half roughness = max(PerceptualRoughnessToRoughness(percepRoughness), HALF_MIN_SQRT);
    half3 dxy = max(abs(ddx(normalWS)), abs(ddy(normalWS)));
    half roughnessFactor = 0.04 + max(max(dxy.x, dxy.y), dxy.z);
    roughness = max(roughness, roughnessFactor);
    half newPercepRoughness = RoughnessToPerceptualRoughness(roughness);
    return newPercepRoughness;
}

#endif

