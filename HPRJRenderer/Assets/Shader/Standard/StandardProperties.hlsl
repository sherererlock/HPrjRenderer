#ifndef STANDARDPROPERTIES_INCLUDED
#define STANDARDPROPERTIES_INCLUDED
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

half _IndirectDiffuseScale;
//int _SupportingCharacterAmount;
half3 _IndirectDiffuseColor;
int _UseIndirectDiffuseColor;

CBUFFER_START(UnityPerMaterial)
    int _SupportingCharacterIndex;

    //uv设置
    int _UV0;
    //int _UV1;
    int _UV2;
    int _UV3;
    half _MainColorWeight;

    //主体
    half4 _Specular;
    half4 _ColorTint;

    int _CullMode;

    half _RoughnessScale;
    half _OcclusionScale;
    half _MetallicScale;

    half _RenderingMode;
    half _Cutoff;

    half _Furlight;

    half4 _InSideRimColor;
    half _InSideRimPower;
    half _InSideRimIntensity;

    half _ColorCastTiling;
    half _ColorCastIntensity;

    // 暗部颜色
    half4 _DarkColor;
    half _DarkPow;

    half4 _EmissionColor;
    int _DetailBlend;
    half _DetailDiffuseTiling;
    half _DetailMetallicScale;
    half _DetailRoughnessScale;
    half _DetailOcclusionScale;
    float _DetailNormalScale;
    half _DetailNormalTiling;
    float _ClearCoatScale;
    half _ClearCoatRoughness;
    float _ClearCoatBumpScale;

    int _PatternBlend;
    half4 _PatternColorTint;
    half _PatternDetailWeight;
    half _PatternTiling; //花纹密度
    half _PatternOffsetX; //花纹密度
    half _PatternOffsetY; //花纹密度
    half _PatternNormalWeight; //花纹法线融合度
    half _PatternRoughnessScale;
    half _PatternOcclusionScale;
    half _PatternMetallicScale;
    //底色

    half _AnisotropyScale;
    half _AnisDirection;

    half4 _SheenColor;
    half _SheenTiling;
    half _SheenScale;
    half _SheenRoughnessScale;
    half _SheenMetallic;
    half _SheenNoramlIntensity;
    half4 _SheenWarp;
    // 布料纹理
    //#ifdef _DETAIL_ON
    //纹理层颜色叠加方式


    //#endif

    // 布料花纹
    //#ifdef _PATTERN_ON

    //#endif

    //闪点
    //#ifdef _SPARKLE_ON
    int _UV4;
    half4 _SparkleColor;
    half _SparkleAplhaEnhance;
    int _SparkleEnhancePow;

    half _SparkleCutoff;
    half _SparkleSize;
    half _SparkleScaleMin;
    half _SparkleDependency;
    half _SparkleRoughness;
    half _SparkleFrequency;

    half _EffectType;

    half _DissolveCutWidth;
    half _DissolveDivisor;
    half _DissolveReverse;
    half _DissolveDirection;

    half4 _SweepColor;
    half _SweepColorIntensity;
    float4 _SweepTex_ST;
    half _SweepIntensity;
    half _ForceTransparent;
    half _SweepRotator;        

    half _CubeColorIntensity;
    half _CubeGlossinessScale;
    float _CubemapRotationX;
    float _CubemapRotationY;
    float _CubemapRotationZ;
    half4 _CubeColor;
    float4 _CustomCubemap_HDR;

    half _TransparentShadowFactor;
    half _AlphaTest;
    half _PatternRotateAngle; //花纹旋转角度（角度制）

CBUFFER_END

//half _ALPHAPREMULTIPLY_ON;
half  _AlphaPremultiply;
half _TattoAlphaOffset;

TextureCube _CustomCubemap;
SamplerState sampler_CustomCubemap;
sampler2D _SweepTex;
sampler2D _RampTex;
sampler2D _SparkleColorMap;
sampler2D _SparkleScaleMap;
sampler2D _SparkleShapeMap;
Texture2D _MainTex;
Texture2D _DetailMap;
sampler2D _SheenTex;
sampler2D _SheenNormalMap;
Texture2D _PatternDiffuseMap; //花纹颜色
Texture2D _PatternDetailMap; //花纹ram
SamplerState sampler_PatternDiffuseMap;
sampler2D _PatternNormalMap; //花纹normal
Texture2D _DetailDiffuseMap;
Texture2D _DetailDetailMap; //ram
SamplerState sampler_DetailDiffuseMap;
sampler2D _DetailNormalMap; //normal
//#endif
SamplerState sampler_MainTex;
sampler2D _NormalMap;
//#ifdef _CLEARCOAT_ON
sampler2D _ClearCoatNormalTex;
sampler2D _ClothDFG;
sampler2D _EmissionTex;
sampler2D _ColorCastMap;

#endif
