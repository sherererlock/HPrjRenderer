#include "../Common.hlsl"
#include "../HCustomLowFunc.hlsl"

#ifdef _SHEEN_ON
	// Ref: https://knarkowicz.wordpress.com/2018/01/04/cloth-shading/
	half CharlieD(half NdotH, half roughness)
	{
	    half invR = rcp(roughness);
	    half cos2h = NdotH * NdotH;
	    half sin2h = 1.0 - cos2h;
	    // Note: We have sin^2 so multiply by 0.5 to cancel it
	    return (2.0 + invR) * PositivePow(sin2h, invR * 0.5) / (2.0 * PI);
	}

	// We use V_Ashikhmin instead of V_Charlie in practice for game due to the cost of V_Charlie
	half AshikhminV(half NdotL, half NdotV)
	{
	    // Use soft visibility term introduce in: Crafting a Next-Gen Material Pipeline for The Order : 1886
	    return 1.0 / (4.0 * (NdotL + NdotV - NdotL * NdotV));
	}

	half3 WrappedDiffuse(half NoL_unclamped, half3 subsurfaceColor, half w)
	{
		half denominator = (1.0 + w) * (1.0 + w);
		half wrapTerm = saturate((NoL_unclamped + w) / denominator);
		half NoL = saturate(NoL_unclamped);
		half3 subsurfaceTerm = saturate(subsurfaceColor + NoL);
	    return wrapTerm * subsurfaceTerm;
	}
#endif

struct SurfaceDataStandard
{
	half3 albedo;
	half metallic;
	half perceptualRoughness;
	half alpha;
	half occlusion;
	float3 tNormal;

	#ifdef _SHEEN_ON
		half3 sheen;
		half sheenPerceptualRoughness;
	#endif

	#ifdef _SPARKLE_ON
		half4 sparkleColor;
		float2 sparkleNoHPhase;
		half sparkleScale;
		half sparkleDependency;
		half sparklePerceptualRoughness;
	#endif
};

struct BRDFDataStandard
{
	half3 diffColor;
	half3 specColor;
	half oneMinusReflectivity;
	half reflectivity;
	half perceptualRoughness;
	half roughness;
	half roughness2;

	half alpha;
	half occlusion;

	#ifdef _SHEEN_ON
		half3 sheen;
		half sheenRoughness;
		half sheenPerceptualRoughness;
		half sheenDFG;
		half sheenScaling;// factor to scale base layer contribution(avoid energy gain)
	#endif

	#ifdef _SPARKLE_ON
		half4 sparkleColor;
		float2 sparkleNoHPhase;
		half sparkleScale;
		half sparkleDependency;
		half sparkleRoughness;
		half sparkleSpecTerm;
	#endif
};

void EnergyConservationStandard(half3 albedo, half metallic, out half3 diffColor, out half3 specColor, out half oneMinusReflectivity)
{
	specColor = lerp(0.04, albedo, metallic);
	oneMinusReflectivity = 1.0 - lerp(0.04, 1.0, metallic);
	diffColor = albedo * oneMinusReflectivity;
}

BRDFDataStandard InitializeBRDFDataStandard(SurfaceDataStandard s)
{
	BRDFDataStandard brdfData = (BRDFDataStandard) 0;
	EnergyConservationStandard(s.albedo, s.metallic, brdfData.diffColor, brdfData.specColor, brdfData.oneMinusReflectivity);
	brdfData.reflectivity = 1.0 - brdfData.oneMinusReflectivity;
	brdfData.perceptualRoughness = s.perceptualRoughness;
	brdfData.roughness = max(PerceptualRoughnessToRoughness(s.perceptualRoughness), HALF_MIN_SQRT);
	brdfData.roughness2 = max(brdfData.roughness * brdfData.roughness, HALF_MIN);

	brdfData.occlusion = s.occlusion;

	#ifdef _SHEEN_ON
		brdfData.sheen = s.sheen;
		brdfData.sheenRoughness = max(PerceptualRoughnessToRoughness(s.sheenPerceptualRoughness), HALF_MIN_SQRT);
		brdfData.sheenPerceptualRoughness = s.sheenPerceptualRoughness;
	#endif
	
	#ifdef _SPARKLE_ON
		brdfData.sparkleColor = s.sparkleColor;
		brdfData.sparkleNoHPhase = s.sparkleNoHPhase;
		brdfData.sparkleScale = s.sparkleScale;
		brdfData.sparkleDependency = s.sparkleDependency;
		brdfData.sparkleRoughness = max(PerceptualRoughnessToRoughness(s.sparklePerceptualRoughness), HALF_MIN_SQRT);
	#endif

	return brdfData;
}

void PostInitializeBRDFDataStandard(inout BRDFDataStandard brdfData, InputDataCustom i)
{
	// sheenDFG and sheenScaling need NoV to initialize
    #ifdef _SHEEN_ON
        half NoV = saturate(dot(i.worldNormal, i.worldView));
        half4 clothDFG = tex2D(_ClothDFG, half2(NoV, brdfData.sheenPerceptualRoughness));
        brdfData.sheenDFG = clothDFG.z;
        brdfData.sheenScaling = 1.0 - max3(brdfData.sheen) * brdfData.sheenDFG;
    #endif
}

half3 GlossyEnvironmentReflectionStandard(half3 reflectVector, half perceptualRoughness, InputDataCustom input)
{
	#ifdef _CUSTOM_REFLECTION_ON
	half smoothness = _CubeGlossinessScale;
	half roughness = PerceptualSmoothnessToPerceptualRoughness(smoothness);
	half mip = PerceptualRoughnessToMipmapLevel(roughness);    
	half3 reflUVW = half3(0.0, 0.0, 0.0);
	reflUVW = reflect(-input.worldView, input.worldNormal);
	RotateCubemap(reflUVW, _CubemapRotationX, _CubemapRotationY, _CubemapRotationZ);
	half4 encodedIrradiance = SAMPLE_TEXTURECUBE_LOD(_CustomCubemap, sampler_CustomCubemap, reflUVW, mip);
	half3 env = DecodeHDREnvironment(encodedIrradiance, _CustomCubemap_HDR);
	half3 reflectColor = env;
	env = dot(reflectColor, _CubeColor) * _CubeColor + reflectColor;
	env = lerp(reflectColor, env, _CubeColorIntensity);
	#else
	half3 env = GlossyEnvironmentReflectionCustom(reflectVector, perceptualRoughness);
	#endif
	return env;
}

void GlobalIlluminationStandard(inout half3 color, BRDFDataStandard brdf, InputDataCustom input)
{
	float3 diffuse = brdf.diffColor * input.bakedGI;

	half3 reflectVector = reflect(-input.worldView, input.worldNormal);
	half3 env = GlossyEnvironmentReflectionStandard(reflectVector, brdf.perceptualRoughness, input);

	float NoV = saturate(dot(input.worldNormal, input.worldView));
    float fresnelTerm = Pow4(1.0 - NoV);
    half surfaceReduction = 1.0 / (brdf.roughness2 + 1.0);
    half grazingTerm = saturate(2.0 - brdf.perceptualRoughness - brdf.oneMinusReflectivity);
	half3 specular = lerp(brdf.specColor, grazingTerm, fresnelTerm) * surfaceReduction * env * _Specular.rgb;

	half3 contrib = diffuse + specular;

	#ifdef _SHEEN_ON
		half3 sheen_env = clamp(GlossyEnvironmentReflectionStandard(reflectVector, brdf.sheenPerceptualRoughness, input), 0.0, 1.0);
		half3 sheen = brdf.sheen * brdf.sheenDFG * sheen_env;
		contrib = contrib * brdf.sheenScaling + sheen;
	#endif
	
	color += contrib * brdf.occlusion;
}

void LightingStandard(inout half3 color, BRDFDataStandard brdf, InputDataCustom input, Light light)
{
	half3 halfDir = SafeNormalize(half3(light.direction) + half3(input.worldView));
	half NoH = saturate(dot(input.worldNormal, halfDir));
	half NoL = saturate(dot(input.worldNormal, light.direction));
	half NoV = saturate(dot(input.worldNormal, input.worldView));
	half LoH = saturate(dot(light.direction, halfDir));
	half LoV = dot(light.direction, input.worldView);

	//***************************************************
	//half3 radiance = light.color * light.distanceAttenuation * light.shadowAttenuation * NoL;
	half3 radiance = light.color * light.distanceAttenuation * light.shadowAttenuation * NoL;
	// half3 diffuse = brdf.diffColor * DisneyDiffuseNoPI(NoV, NoL, LoV, brdf.perceptualRoughness);
	half3 diffuse = brdf.diffColor;

	half d = NoH * NoH * (brdf.roughness2 - 1.0) + 1.00001;
	half LoH2 = LoH * LoH;
	half normalizationTerm = brdf.roughness * 4.0 + 2.0;

	half3 specular = clamp(brdf.specColor * brdf.roughness2 / (0.0001 + d * d * max(0.1h, LoH2) * normalizationTerm), 0.0, 100.0);

	half3 contrib = diffuse + specular * _Specular.rgb;
	
	#ifdef _SHEEN_ON
	    half sheen_D = CharlieD(NoH, max(brdf.sheenRoughness, 0.0001));
	    half sheen_V = AshikhminV(NoL, max(NoV, 0.0001));
	    half3 sheen = brdf.sheen * saturate(sheen_V * sheen_D);// use saturate to get rid of artifacts around the borders.
	    contrib = contrib * brdf.sheenScaling + sheen;
	#endif

	#ifdef _SPARKLE_ON
		half sparkle_roughness2 = max(brdf.sparkleRoughness * brdf.sparkleRoughness, HALF_MIN);
		float vertexNormalNoH = saturate(dot(input.worldVertexNormal, halfDir));
		float pureSparkleNoH  = sin((brdf.sparkleNoHPhase + 0.01f) * _SparkleFrequency * dot(light.direction, input.worldView)) / 2 + 0.5f;
		float sparkle_NoH = lerp(vertexNormalNoH, pureSparkleNoH, brdf.sparkleDependency);
		float sparkle_d = sparkle_NoH * sparkle_NoH * (sparkle_roughness2 - 1.0f) + 1.00001f;
		float sparkle_LoH2 = LoH * LoH;
		float sparkle_normalizationTerm = brdf.sparkleRoughness * 4.0f + 2.0f;

		half sparkleSpec = clamp(brdf.sparkleScale * sparkle_roughness2 / (sparkle_d * sparkle_d * max(0.1h, sparkle_LoH2) * sparkle_normalizationTerm), 0.0, 100.0);
		brdf.sparkleSpecTerm = sparkleSpec * radiance;

		half3 sparkle = sparkleSpec * brdf.sparkleColor;
		contrib += saturate(sparkle);
	#endif

	color += contrib * radiance;
}

void VertexLightingStandard(inout half3 color, BRDFDataStandard brdf, InputDataCustom input)
{
	color += input.vertexLighting * brdf.diffColor;
}


#define SURFACE_DATA SurfaceDataStandard
#define BRDF_DATA BRDFDataStandard
#define INITIALIZE_BRDF_DATA InitializeBRDFDataStandard
#define POST_INITIALIZE_BRDF_DATA PostInitializeBRDFDataStandard
#define GLOBAL_ILLUMINATION GlobalIlluminationStandard
#define LIGHTING_MAIN LightingStandard
#define LIGHTING_ADD LightingStandard
#define LIGHTING_VERTEX VertexLightingStandard
