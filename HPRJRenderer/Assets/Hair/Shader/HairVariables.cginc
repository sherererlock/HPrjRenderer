#ifndef HAIR_VARIABLES
#define HAIR_VARIABLES

//#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

sampler2D _BakedOcclusionMap;
sampler2D _ColorMap;
sampler2D _DirectionMap;
sampler2D _BakedShadowTex;
float _BakedShadowIntensity;

// NOTE: Do not ifdef the properties here as SRP batcher can not handle different layouts.
CBUFFER_START(UnityPerMaterial)
    // Material Properties
    sampler2D _MainMap;
    int _SupportingCharacterIndex;
    float _AlphaCutoff;
    float _PerceptualRoughness;
    float _Brightness;

    float _IndirectIntensity;
    float _AddLightIntensity;
    float _Scatter;
    float _HighlightIntensity;
    float _InnerHighlightIntensity;
    float _BacklitIntensity;

    float _ShadowIntensity;
    float _Absorbtion;
    float _ShadowRoot;
    float _ShadowBlur;
    float _DepthOffset;
    float _OcclusionIntensity;

    float4 _ShadowTintColor;
    float _ShadowTintPower;

    float4 _Color;
    float4 _TipColor;
    float4 _RootColor;
    float _RootPower;
    float _HueVariation;
    float _BrightnessVariation;

    float _FlowDirection;
    float _FlowVariation;

    float _Vis;
    float _LightPath;
    float _LightComponent;
    float _DebugValue;

CBUFFER_END

// Global Shader Variables
float Hair_TexelSize;
float4 Hair_ShadowFrustumParams;// x : isOrthographic, y : (orthographic) frustum size, z : (perspective) near, w : (perspective) far
float4x4 Hair_WorldToShadow;
int _SupportingCharacterAmount;
float3 _LightDirection;

TEXTURE2D_SHADOW(_HairDepthTextureCMP);
SAMPLER_CMP(sampler_HairDepthTextureCMP);
float4 _HairDepthTextureCMP_TexelSize;
TEXTURE2D(_HairDepthTexture);
SAMPLER(sampler_HairDepthTexture);
sampler2D _DeepOpacityTexture;
sampler2D _HairShadowTexture;
sampler2D _SweepTex;
sampler2D _RampTex;
int _ShadowLightIndex;

half _EffectType;
half4 _SweepColor;
half _SweepColorIntensity;
float4 _SweepTex_ST;
half _SweepIntensity;
half _SweepRotator;        

// Constants & Definitions
#define SHADOW_DIST 0.05 // total width of four layers
static const float s_LayerBounds[5] = { 0.0, 0.1 * SHADOW_DIST, 0.4 * SHADOW_DIST, 0.7 * SHADOW_DIST, 1.0 * SHADOW_DIST };// bounds of four layers
#define RANGE_SCALE 5.0 // LDR buffer can only preserve alpha sum from 0 to 1, scale it for a wider range
#define SOFT_SHADOW_DIST 2

#define DEPTH_OFFSET 0.03
#define SHADOW_BIAS_DEPTH 0.002
#define SHADOW_BIAS_NORMAL 0.01

#define _PI 3.1415926

#endif