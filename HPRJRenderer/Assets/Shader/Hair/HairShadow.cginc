#ifndef HAIR_SHADOW
#define HAIR_SHADOW

inline float3 FlowDir(float2 uv)
{
    #ifdef _FLOWDIRECTION_DIRECTIONMAP// sample flowmap
        float3 dir = tex2D(_DirectionMap, uv).xyz * 2 - 1;
        dir.y *= -1;
        return dir;
    #endif
    #ifdef _FLOWDIRECTION_U// use +U as flow dir
        return float3(1.0, 0.0, 0.0);
    #endif
    #ifdef _FLOWDIRECTION_V// use -V as flow dir
        return float3(0.0, -1.0, 0.0);
    #endif
    return float3(0.0, -1.0, 0.0);
}

#if UNITY_REVERSED_Z
    #define DEPTH_SUBTRACT(depth, nearest) (nearest - depth)
#else
    #define DEPTH_SUBTRACT(depth, nearest) (depth - nearest)
#endif

float HairShadowLinearDepth(float depth)
{
    float otho = depth * Hair_ShadowFrustumParams.y;
    float n = Hair_ShadowFrustumParams.z;
    float f = Hair_ShadowFrustumParams.w;
    float persp = (n * f) / ((n - f) * depth + f);
    return Hair_ShadowFrustumParams.x > 0.5 ? otho : persp;
}

inline float SampleDepthTextureCMP(float2 uvs[5], float depth)
{
    #ifdef _HAIRSHADOW_SOFT// 4xPCF
        #if 1
            real fetchesWeights[9];
            real2 fetchesUV[9];
            SampleShadow_ComputeSamples_Tent_5x5(_HairDepthTextureCMP_TexelSize, uvs[0], fetchesWeights, fetchesUV);

            float atten = 0.0;
            atten += fetchesWeights[0] * SAMPLE_TEXTURE2D_SHADOW(_HairDepthTextureCMP, sampler_HairDepthTextureCMP, float3(fetchesUV[0].xy, depth)).r;
            atten += fetchesWeights[1] * SAMPLE_TEXTURE2D_SHADOW(_HairDepthTextureCMP, sampler_HairDepthTextureCMP, float3(fetchesUV[1].xy, depth)).r;
            atten += fetchesWeights[2] * SAMPLE_TEXTURE2D_SHADOW(_HairDepthTextureCMP, sampler_HairDepthTextureCMP, float3(fetchesUV[2].xy, depth)).r;
            atten += fetchesWeights[3] * SAMPLE_TEXTURE2D_SHADOW(_HairDepthTextureCMP, sampler_HairDepthTextureCMP, float3(fetchesUV[3].xy, depth)).r;
            atten += fetchesWeights[4] * SAMPLE_TEXTURE2D_SHADOW(_HairDepthTextureCMP, sampler_HairDepthTextureCMP, float3(fetchesUV[4].xy, depth)).r;
            atten += fetchesWeights[5] * SAMPLE_TEXTURE2D_SHADOW(_HairDepthTextureCMP, sampler_HairDepthTextureCMP, float3(fetchesUV[5].xy, depth)).r;
            atten += fetchesWeights[6] * SAMPLE_TEXTURE2D_SHADOW(_HairDepthTextureCMP, sampler_HairDepthTextureCMP, float3(fetchesUV[6].xy, depth)).r;
            atten += fetchesWeights[7] * SAMPLE_TEXTURE2D_SHADOW(_HairDepthTextureCMP, sampler_HairDepthTextureCMP, float3(fetchesUV[7].xy, depth)).r;
            atten += fetchesWeights[8] * SAMPLE_TEXTURE2D_SHADOW(_HairDepthTextureCMP, sampler_HairDepthTextureCMP, float3(fetchesUV[8].xy, depth)).r;
            return atten;
        #else
            float4 atten4;
            atten4.x = SAMPLE_TEXTURE2D_SHADOW(_HairDepthTextureCMP, sampler_HairDepthTextureCMP, float3(uvs[1], depth)).r;
            atten4.y = SAMPLE_TEXTURE2D_SHADOW(_HairDepthTextureCMP, sampler_HairDepthTextureCMP, float3(uvs[2], depth)).r;
            atten4.z = SAMPLE_TEXTURE2D_SHADOW(_HairDepthTextureCMP, sampler_HairDepthTextureCMP, float3(uvs[3], depth)).r;
            atten4.w = SAMPLE_TEXTURE2D_SHADOW(_HairDepthTextureCMP, sampler_HairDepthTextureCMP, float3(uvs[4], depth)).r;
            return dot(atten4, 0.25);
        #endif
    #else
        return SAMPLE_TEXTURE2D_SHADOW(_HairDepthTextureCMP, sampler_HairDepthTextureCMP, float3(uvs[0], depth)).r;
    #endif
}

inline float SampleDepthTexture(float2 uvs[5])
{
    #ifdef _HAIRSHADOW_SOFT// 4xPCF
        float4 depth4;
        depth4.x = SAMPLE_TEXTURE2D(_HairDepthTexture, sampler_HairDepthTexture, uvs[1]).r;
        depth4.y = SAMPLE_TEXTURE2D(_HairDepthTexture, sampler_HairDepthTexture, uvs[2]).r;
        depth4.z = SAMPLE_TEXTURE2D(_HairDepthTexture, sampler_HairDepthTexture, uvs[3]).r;
        depth4.w = SAMPLE_TEXTURE2D(_HairDepthTexture, sampler_HairDepthTexture, uvs[4]).r;
        return dot(depth4, 0.25);
    #else
        return SAMPLE_TEXTURE2D(_HairDepthTexture, sampler_HairDepthTexture, uvs[0]).r;
    #endif
}

inline float4 SampleDeepOpacityTexture(float2 uvs[5])
{
    #ifdef _HAIRSHADOW_SOFT// 4xPCF
        float4 dom4[4];
        dom4[0] = tex2D(_DeepOpacityTexture, uvs[1]);
        dom4[1] = tex2D(_DeepOpacityTexture, uvs[2]);
        dom4[2] = tex2D(_DeepOpacityTexture, uvs[3]);
        dom4[3] = tex2D(_DeepOpacityTexture, uvs[4]);
        return (dom4[0] + dom4[1] + dom4[2] + dom4[3]) * 0.25;
    #else
        return tex2D(_DeepOpacityTexture, uvs[0]);
    #endif
}

float ShadowAtten_Shadowmap(float2 uvs[5], float depth)
{
    return SampleDepthTextureCMP(uvs, depth);
}

float ShadowAtten_ExpFalloff(float2 uvs[5], float depth)
{
    float depth_linear = HairShadowLinearDepth(depth);

    float dist;

    #ifdef _HAIRSHADOW_SOFT// 4xPCF
        float dists[5];
        dists[1] = max(0.0, DEPTH_SUBTRACT(depth_linear, HairShadowLinearDepth(SAMPLE_TEXTURE2D(_HairDepthTexture, sampler_HairDepthTexture, uvs[1]).r)));
        dists[2] = max(0.0, DEPTH_SUBTRACT(depth_linear, HairShadowLinearDepth(SAMPLE_TEXTURE2D(_HairDepthTexture, sampler_HairDepthTexture, uvs[2]).r)));
        dists[3] = max(0.0, DEPTH_SUBTRACT(depth_linear, HairShadowLinearDepth(SAMPLE_TEXTURE2D(_HairDepthTexture, sampler_HairDepthTexture, uvs[3]).r)));
        dists[4] = max(0.0, DEPTH_SUBTRACT(depth_linear, HairShadowLinearDepth(SAMPLE_TEXTURE2D(_HairDepthTexture, sampler_HairDepthTexture, uvs[4]).r)));
        //dists[0] = max(0.0, DEPTH_SUBTRACT(depth_linear, HairShadowLinearDepth(SAMPLE_TEXTURE2D(_HairDepthTexture, sampler_HairDepthTexture, uvs[0]).r)));

        //dist = (dists[0] + dists[1] + dists[2] + dists[3] + dists[4]) / 5.0;
        dist = (dists[1] + dists[2] + dists[3] + dists[4]) / 4.0;
    #else
        dist = max(0.0, DEPTH_SUBTRACT(depth_linear, HairShadowLinearDepth(SAMPLE_TEXTURE2D(_HairDepthTexture, sampler_HairDepthTexture, uvs[0]).r)));
    #endif

    return saturate(exp(-5.0 * _Absorbtion * dist) - 0.01);
}

float ShadowAtten_DeepOpacity(float2 uvs[5], float depth)
{
    float nearest = SampleDepthTexture(uvs);
    float nearest_linear = HairShadowLinearDepth(nearest);
    float depth_linear = HairShadowLinearDepth(depth);

    float dist = DEPTH_SUBTRACT(depth_linear, nearest_linear);

    float4 dom = SampleDeepOpacityTexture(uvs);

    float4 percent = saturate(float4(
        (dist - s_LayerBounds[0]) / (s_LayerBounds[1] - s_LayerBounds[0]),
        (dist - s_LayerBounds[1]) / (s_LayerBounds[2] - s_LayerBounds[1]),
        (dist - s_LayerBounds[2]) / (s_LayerBounds[3] - s_LayerBounds[2]),
        (dist - s_LayerBounds[3]) / (s_LayerBounds[4] - s_LayerBounds[3])));

    float absorb = dot(percent, dom) * RANGE_SCALE;
    absorb += max(0.0, dist - s_LayerBounds[4]) * 100;
    return saturate(exp(-0.06 * _Absorbtion * absorb));
}

// Shadow Receiver Helper Function
float CalculateHairShadow(float4 shadowCoord)
{
    shadowCoord.xyz /= shadowCoord.w;

    float2 uvs[5] = {
                        shadowCoord.xy,
                        shadowCoord.xy + float2(1.0, 1.0) * Hair_TexelSize * 0.5 * _ShadowBlur,
                        shadowCoord.xy + float2(1.0, -1.0) * Hair_TexelSize * 0.5 * _ShadowBlur,
                        shadowCoord.xy + float2(-1.0, 1.0) * Hair_TexelSize * 0.5 * _ShadowBlur,
                        shadowCoord.xy + float2(-1.0, -1.0) * Hair_TexelSize * 0.5 * _ShadowBlur
                    };
    
    #if defined(_HAIRSHADOW_SHADOWMAP)
        return ShadowAtten_Shadowmap(uvs, shadowCoord.z);
    #elif defined(_HAIRSHADOW_EXPFALLOFF)
        return ShadowAtten_ExpFalloff(uvs, shadowCoord.z);
    #else
        return ShadowAtten_DeepOpacity(uvs, shadowCoord.z);
    #endif
}

float SampleHairShadow(float2 screenUV)
{
    #if (!defined(_HAIR_SHADOWS) && !defined(_ADDITIONAL_LIGHT_SHADOWS)) || defined(_RECEIVE_SHADOWS_OFF)
        return 1.0f;
    #endif
    return tex2D(_HairShadowTexture, screenUV).r;
}

/*float CalculateLightShadow(Light light, float hairShadow, int index)
{
    if(index == _ShadowLightIndex)
        light.shadowAttenuation = hairShadow;
    else
        light.shadowAttenuation = saturate(lerp(1.0, light.shadowAttenuation, _ShadowIntensity));
    return light.shadowAttenuation * light.distanceAttenuation;
}*/

#endif
