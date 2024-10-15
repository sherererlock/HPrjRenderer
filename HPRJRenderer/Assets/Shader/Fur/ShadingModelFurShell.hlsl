
struct SurfaceDataStandard
{
	half3 albedo;
	half perceptualRoughness;
	half occlusion;
	float3 tNormal;
	half furNoise;
	half furNoiseDetail;
	half4 scatter;
	half furNoiseOffSet;
};

struct BRDFDataStandard
{
	half3 diffColor;
	half3 specColor;
	half noiseScale;
	half oneMinusReflectivity;
	half perceptualRoughness;
	half roughness;
	half roughness2;

	half occlusion;
	half4 scatter;
};

inline half FabricScatterFresnelLerp(half nv, half scale)
{
    half t0 = Pow4 (1 - nv); 
    half t1 = 0.4 * (1 - nv);
    return (t1 - t0) * scale + t0;
}

BRDFDataStandard InitializeBRDFDataStandard(SurfaceDataStandard s)
{
	BRDFDataStandard brdfData = (BRDFDataStandard) 0;
	brdfData.specColor = 0.04;
	brdfData.oneMinusReflectivity = 0.96;
	brdfData.diffColor = s.albedo * brdfData.oneMinusReflectivity;
	brdfData.perceptualRoughness = s.perceptualRoughness;
	brdfData.roughness = max(PerceptualRoughnessToRoughness(s.perceptualRoughness), HALF_MIN_SQRT);
	brdfData.roughness2 = max(brdfData.roughness * brdfData.roughness, HALF_MIN);

	brdfData.occlusion = s.occlusion;
	brdfData.scatter = s.scatter;

	return brdfData;
}

void GlobalIlluminationStandard(inout half3 color, BRDFDataStandard brdf, InputDataCustom input)
{
	half3 diffuse = brdf.diffColor * input.bakedGI;

	half3 reflectVector = reflect(-input.worldView, input.worldNormal);
	half3 env = GlossyEnvironmentReflectionCustom(reflectVector, brdf.perceptualRoughness);

	half NoV = saturate(dot(input.worldNormal, input.worldView));
    half fresnelTerm = Pow4(1.0 - NoV);
    half surfaceReduction = 1.0 / (brdf.roughness2 + 1.0);
    half grazingTerm = saturate(2.0 - brdf.perceptualRoughness - brdf.oneMinusReflectivity);
	half3 specular = lerp(brdf.specColor, grazingTerm, fresnelTerm) * surfaceReduction * env;

	half3 contrib = diffuse + specular;
	
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

	half3 radiance = light.color * light.distanceAttenuation * light.shadowAttenuation * NoL;

	// half3 diffuse = brdf.diffColor * DisneyDiffuseNoPI(NoV, NoL, LoV, brdf.perceptualRoughness);
	half3 diffuse = brdf.diffColor;

	half d = NoH * NoH * (brdf.roughness2 - 1.0) + 1.00001;
	half LoH2 = LoH * LoH;
	half normalizationTerm = brdf.roughness * 4.0 + 2.0;

	half3 specular = brdf.specColor * brdf.roughness2 / (0.0001 + d * d * max(0.1h, LoH2) * normalizationTerm);

	half3 contrib = diffuse + specular;

	color += contrib * radiance;

	color += brdf.scatter.rgb * (NoL * 0.5 + 0.5) * FabricScatterFresnelLerp(NoV, brdf.scatter.w);
}

void VertexLightingStandard(inout half3 color, BRDFDataStandard brdf, InputDataCustom input)
{
	color += input.vertexLighting * brdf.diffColor;
}

half3 ApplyLut2D(sampler2D tex, float3 uvw, float3 scaleOffset)
{
	// Strip format where `height = sqrt(width)`
	uvw.z *= scaleOffset.z;
	float shift = floor(uvw.z);
	uvw.xy = uvw.xy * scaleOffset.z * scaleOffset.xy + scaleOffset.xy * 0.5;
	uvw.x += shift * scaleOffset.y;
	uvw.xyz = lerp(
        tex2Dlod(tex, float4(uvw.xy, 0.0, 0.0)).rgb,
        tex2Dlod(tex, float4(uvw.xy + float2(scaleOffset.y, 0.0), 0.0, 0.0)).rgb,
        uvw.z - shift
    );
	//return SAMPLE_TEXTURE2D_LOD(tex, samplerTex, uvw.xy, 0.0).rgb;
	return uvw;
}

half3 ApplyColorGrading(half3 input, float postExposure, float3 lutParams, sampler2D userLutTex)
{
	// Artist request to fine tune exposure in post without affecting bloom, dof etc
	input *= postExposure;
	float3 inputLutSpace = saturate(LinearToLogC(input)); // LUT space is in LogC
	            
	input = ApplyLut2D(userLutTex, inputLutSpace, lutParams);
	return input;
}


#define SURFACE_DATA SurfaceDataStandard
#define BRDF_DATA BRDFDataStandard
#define INITIALIZE_BRDF_DATA InitializeBRDFDataStandard
#define GLOBAL_ILLUMINATION GlobalIlluminationStandard
#define LIGHTING_MAIN LightingStandard
#define LIGHTING_ADD LightingStandard
#define LIGHTING_VERTEX VertexLightingStandard
