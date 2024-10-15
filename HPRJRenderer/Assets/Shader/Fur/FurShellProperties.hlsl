#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// CBUFFER_START(UnityPerMaterial)
    //主体
    half4 _ColorTint;
    sampler2D _AlbedoMap;
    sampler2D _DetailMap;
    sampler2D _NormalMap;
    half _NormalScale;
    half _RoughnessScale;
    half _OcclusionScale;
    half _MANUALCOLORSHADING;
    sampler2D _FurNoiseMap;
    sampler2D _CustomLUT;
    TEXTURE2D(_ParamMaskMap);
    SAMPLER(sampler_ParamMaskMap);
    half _IntensityMaskScale;
    half _FurScale;
    half _FurLength;
    half _FurOcclusion;
    half _AlphaCutout;
    half _EdgeFade;
    int _SupportingCharacterIndex;
    //int _SupportingCharacterAmount;
    half _EdgeControl;

    half _RimPower;
    half _RimIntensity;
    half _ClipAdjust;

    half4 _ScatterColor;
    half _ScatterScale;

    half4 _DeepAreaColor;

    half _GravityStrength;
    half4 _GravityDir;
    half _WindStrength;
    half4 _WindDir;
    half4 _WindFreq;
    //half4 _WindTest;

    half _TransparentShadowFactor;
// CBUFFER_END
int _CullMode;
half _IndirectDiffuseScale;
half3 _IndirectDiffuseColor;
int _UseIndirectDiffuseColor;
