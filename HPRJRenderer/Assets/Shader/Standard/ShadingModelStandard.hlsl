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

#ifdef _ANISOTROPY_ON
	void AnisotropicModifiedNormalAndRoughness(
		float3 tangent, float3 bitangent, float3 normal, float3 view, half anisotropyScale, half perceptualRoughness,
		out float3 iblNormal, out half iblPerceptualRoughness)
	{
	    float3 grainDirWS = (anisotropyScale >= 0.0) ? bitangent : tangent;
	    half stretch = abs(anisotropyScale) * saturate(1.5 * sqrt(perceptualRoughness));
	    iblNormal = GetAnisotropicModifiedNormal(grainDirWS, normal, view, stretch);
	    iblPerceptualRoughness = perceptualRoughness * saturate(1.2 - abs(anisotropyScale));
	}
#endif

struct SurfaceDataStandard
{
	half3 albedo;
	half metallic;
	half perceptualRoughness;
	half alpha;
	half occlusion;
	half3 tNormal;

	#ifdef _SHEEN_ON
		half3 sheen;
		half3 sheenNormal;
		half sheenPerceptualRoughness;
	#endif

	#ifdef _ANISOTROPY_ON
		half2 anisoRotateVect;
	#endif

	#ifdef _CLEARCOAT_ON
		float clearCoat;
		half clearCoatPerceptualRoughness;
		float3 clearCoatTNormal;
	#endif

	#ifdef _EMISSION_ON
		float3 emission;
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
		half3 sheenSplitSum;
		half3 sheenNormal;
	#endif

	#ifdef _CLEARCOAT_ON
		float clearCoat;
		half clearCoatRoughness;
		half clearCoatPerceptualRoughness;
	#endif

	#ifdef _EMISSION_ON
		float3 emission;
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

	#ifdef _CLEARCOAT_ON
		brdfData.clearCoat = s.clearCoat;
		brdfData.clearCoatRoughness = max(PerceptualRoughnessToRoughness(s.clearCoatPerceptualRoughness), HALF_MIN_SQRT);
		brdfData.clearCoatPerceptualRoughness = s.clearCoatPerceptualRoughness;
	#endif

	#ifdef _EMISSION_ON
		brdfData.emission = s.emission;
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
		brdfData.sheenSplitSum = clothDFG.rgb;
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

void GlobalIlluminationStandard(inout float3 color, BRDFDataStandard brdf, InputDataCustom input)
{
	half3 diffuse = brdf.diffColor * input.bakedGI;

	#ifdef _ANISOTROPY_ON
		float3 iblNormal;
		half iblPerceptualRoughness;
		AnisotropicModifiedNormalAndRoughness(
			input.worldTangent, input.worldBitangent, input.worldNormal, input.worldView, _AnisotropyScale, brdf.perceptualRoughness,
			iblNormal, iblPerceptualRoughness);
		half3 reflectVector = reflect(-input.worldView, iblNormal);
		half3 env = GlossyEnvironmentReflectionStandard(reflectVector, iblPerceptualRoughness, input);
	#else
		half3 reflectVector = reflect(-input.worldView, input.worldNormal);
		half3 env = GlossyEnvironmentReflectionStandard(reflectVector, brdf.perceptualRoughness, input);
	#endif

	float NoV = saturate(dot(input.worldNormal, input.worldView));
	
    float fresnelTerm = Pow4(1.0 - NoV);
    half surfaceReduction = 1.0 / (brdf.roughness2 + 1.0);
    half grazingTerm = saturate(2.0 - brdf.perceptualRoughness - brdf.oneMinusReflectivity);
	half3 specular = lerp(brdf.specColor, grazingTerm, fresnelTerm) * surfaceReduction * env * _Specular.rgb;

	half3 contrib = diffuse + specular;

	#ifdef _SHEEN_ON
		half3 sheenRefVec = reflect(-input.worldView, brdf.sheenNormal);
		sheenRefVec = lerp(reflectVector, sheenRefVec, _SheenNoramlIntensity);
		half3 sheen_env = clamp(GlossyEnvironmentReflectionStandard(sheenRefVec, brdf.sheenPerceptualRoughness, input), 0.0, 1.0);
		half3 sheenF = lerp(0.04, brdf.sheen, _SheenMetallic);
		half3 sheen = (sheenF * brdf.sheenSplitSum.x + brdf.sheenSplitSum.y) * brdf.sheenDFG * sheen_env;
		contrib = contrib * brdf.sheenScaling + sheen;
	#endif

	#ifdef _CLEARCOAT_ON
		half3 cc_reflectVector = reflect(-input.worldView, input.clearCoatWorldNormal);
		half3 cc_env = GlossyEnvironmentReflectionStandard(cc_reflectVector, brdf.clearCoatPerceptualRoughness, input);
		half cc_roughness2 = brdf.clearCoatRoughness * brdf.clearCoatRoughness;
		half cc_surfaceReduction = 1.0 / (cc_roughness2  + 1.0);
		half cc_grazingTerm = saturate(1.0 - brdf.clearCoatPerceptualRoughness);
		float cc_NoV = saturate(dot(input.clearCoatWorldNormal, input.worldView));
		float cc_fresnelTerm = Pow4(1.0 - cc_NoV);
		half3 clearCoat = lerp(0.04, cc_grazingTerm, cc_fresnelTerm) * cc_surfaceReduction * cc_env * brdf.clearCoat;
			
		float cc_F = F_Schlick(0.04, 1.0, cc_NoV) * brdf.clearCoat;

		contrib = contrib * (1.0 - cc_F) + clearCoat;
	#endif
	
	color += contrib * brdf.occlusion;
}

half V_Kelemen(half LoH)
{
	return 0.25 / (LoH * LoH);
}

void LightingStandard(inout half3 color, inout BRDFDataStandard brdf, InputDataCustom input, Light light)
{
	half3 halfDir = SafeNormalize(half3(light.direction) + half3(input.worldView));
	half NoH = saturate(dot(input.worldNormal, halfDir));
	half NoL = saturate(dot(input.worldNormal, light.direction));
	half NoV = saturate(dot(input.worldNormal, input.worldView));
	half LoH = saturate(dot(light.direction, halfDir));
	half LoV = dot(light.direction, input.worldView);

	half3 radianceFurlight = light.color * light.distanceAttenuation * light.shadowAttenuation * sin(sqrt(1 - pow(dot(input.worldBitangent, light.direction), 2)));
	half3 radiance = light.color * light.distanceAttenuation * light.shadowAttenuation * NoL;
	radianceFurlight = saturate(radianceFurlight);
	radiance = lerp(radiance, radianceFurlight, _Furlight);
	// half3 diffuse = brdf.diffColor * DisneyDiffuseNoPI(NoV, NoL, LoV, brdf.perceptualRoughness);
	half3 diffuse = brdf.diffColor;

	#ifdef _ANISOTROPY_ON
	    // For anisotropy we must not saturate these values
	    half TdotH = dot(input.worldTangent, halfDir);
	    half TdotL = dot(input.worldTangent, light.direction);
	    half BdotH = dot(input.worldBitangent, halfDir);
	    half BdotL = dot(input.worldBitangent, light.direction);

	    half TdotV = dot(input.worldTangent, input.worldView);
	    half BdotV = dot(input.worldBitangent, input.worldView);

	    // Use the parametrization of Sony Imageworks.
	    // Ref: Revisiting Physically Based Shading at Imageworks, p. 15.
	    half roughnessT = brdf.roughness * (1 + _AnisotropyScale);
	    half roughnessB = brdf.roughness * (1 - _AnisotropyScale);

	    half D = D_GGXAnisoNoPI(TdotH, BdotH, NoH, roughnessT, roughnessB);
	    half V = V_SmithJointGGXAniso(TdotV, BdotV, NoV, TdotL, BdotL, NoL, roughnessT, roughnessB);
	    half3 F = brdf.specColor;

	    half3 specular = saturate(D * V * F);
	#else
		half d = NoH * NoH * (brdf.roughness2 - 1.0) + 1.00001;
		half LoH2 = LoH * LoH;
		half normalizationTerm = brdf.roughness * 4.0 + 2.0;

		half3 specular = clamp(brdf.specColor * brdf.roughness2 / (0.0001 + d * d * max(0.1h, LoH2) * normalizationTerm), 0.0, 100.0);
	#endif

	half3 contrib = diffuse + specular * _Specular.rgb;

	#ifdef _SHEEN_ON
		half3 fakeNormal = normalize(lerp(input.worldNormal, brdf.sheenNormal, _SheenNoramlIntensity));
		half sheenNoH = saturate(dot(fakeNormal, halfDir));
		half sheenNoL = saturate(dot(fakeNormal, light.direction));
		half sheenNoV = saturate(dot(fakeNormal, input.worldView));
	    half sheen_D = CharlieD(sheenNoH, max(brdf.sheenRoughness, 0.0001));
	    half sheen_V = AshikhminV(sheenNoL, max(sheenNoV, 0.0001));
	    half3 sheen_F = lerp(0.04, brdf.sheen, _SheenMetallic);
		sheen_F = sheen_F + (1.0 - sheen_F) * pow(1.0 - saturate(dot(input.worldView, halfDir)), 5.0);
		half3 sheen = sheen_F * saturate(sheen_V * sheen_D) * PI;// use saturate to get rid of artifacts around the borders.
		color += sheen * light.color * light.distanceAttenuation * light.shadowAttenuation * sheenNoL;
		contrib = contrib * brdf.sheenScaling;
	#endif

	#ifdef _CLEARCOAT_ON
		half cc_PerceptualRoughness = clamp(brdf.clearCoatRoughness * brdf.clearCoatRoughness, 0.089, 1);
		half cc_ValidRoughness = clamp(cc_PerceptualRoughness * cc_PerceptualRoughness, 0.089, 1);
		float cc_NoH = saturate(dot(input.clearCoatWorldNormal, halfDir));
		float cc_Dc = D_GGX(cc_NoH, cc_ValidRoughness);
		half cc_Vc = V_Kelemen(LoH);
		half cc_Fc = F_Schlick(0.04, LoH);
		float cc_Frc = (cc_Dc * cc_Vc) * cc_Fc;
		contrib += ((diffuse + specular * _Specular.rgb * (1.0 - cc_Fc)) * (1.0 - cc_Fc) + cc_Frc) * brdf.clearCoat;

		//原版ClearCoat
		/*
		float cc_roughness2 = brdf.clearCoatRoughness * brdf.clearCoatRoughness;
		half cc_NoH = saturate(dot(input.clearCoatWorldNormal, halfDir));
		half cc_d = cc_NoH * cc_NoH * (cc_roughness2 - 1.0) + 1.00001;
		half cc_LoH2 = LoH * LoH;
		half cc_normalizationTerm = brdf.clearCoatRoughness * 4.0 + 2.0;
		half3 clearCoat = brdf.clearCoat * cc_roughness2 / ( 0.001 + cc_d * cc_d * max(0.1h, cc_LoH2) * cc_normalizationTerm);
		half cc_F = F_Schlick(0.04, 1.0, LoH) * brdf.clearCoat;
		contrib = contrib * (1.0 - cc_F) + clearCoat;*/	
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

void EmissionStandard(inout half3 color, BRDFDataStandard brdf)
{
	#ifdef _EMISSION_ON
		color += brdf.emission;
	#endif
}

#define SURFACE_DATA SurfaceDataStandard
#define BRDF_DATA BRDFDataStandard
#define INITIALIZE_BRDF_DATA InitializeBRDFDataStandard
#define POST_INITIALIZE_BRDF_DATA PostInitializeBRDFDataStandard
#define GLOBAL_ILLUMINATION GlobalIlluminationStandard
#define LIGHTING_MAIN LightingStandard
#define LIGHTING_ADD LightingStandard
#define LIGHTING_VERTEX VertexLightingStandard
#define EMISSION EmissionStandard
