#ifndef STANDARDPROPERTIES_INCLUDED
#define STANDARDPROPERTIES_INCLUDED
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

half _IndirectDiffuseScale;
//int _SupportingCharacterAmount;
half3 _IndirectDiffuseColor;
int  _UseIndirectDiffuseColor;

CBUFFER_START(UnityPerMaterial)

    //uv设置
    int _UV0;
    //int _UV1;
    int _UV2;
    int _UV3;
    //int _UV4; uv4写在下面
    int _SupportingCharacterIndex;
    //主体
    half _MainColorWeight;
    half4 _Specular;
    half4 _ColorTint;
    Texture2D _MainTex;
    Texture2D _DetailMap;
    SamplerState sampler_MainTex;
    sampler2D _NormalMap;
    half _RoughnessScale;
    half _OcclusionScale;
    half _MetallicScale;
    int _CullMode;
    half _RenderingMode;
    half _Cutoff;
    half _AnisotropyScale;
    half _AnisDirection;
    half4 _SheenColor;
    sampler2D _SheenTex;
    half _SheenTiling;
    sampler2D _ClothDFG;
    half _SheenScale;
    half _SheenRoughnessScale;

    sampler2D _ColorCastMap;
    half _ColorCastTiling;
    half _ColorCastIntensity;

    // 暗部颜色
    half4 _DarkColor;
    half _DarkPow;

    half4 _EmissionColor;
    sampler2D _EmissionTex;

    // 布料纹理
    //#ifdef _DETAIL_ON
    int _DetailBlend;   //纹理层颜色叠加方式
    Texture2D _DetailDiffuseMap;
    Texture2D _DetailDetailMap; //ram
    SamplerState sampler_DetailDiffuseMap;
    // 砍掉纹理的法线贴图
    sampler2D _DetailNormalMap; //normal

    float _DetailNormalScale;
    half _DetailDiffuseTiling;
    half _DetailNormalTiling;
    half _DetailRoughnessScale;
    half _DetailOcclusionScale;
    half _DetailMetallicScale;
    //#endif

    // 布料花纹
    //#ifdef _PATTERN_ON
    int _PatternBlend;
    half4 _PatternColorTint;
    Texture2D _PatternDiffuseMap; //花纹颜色
    Texture2D _PatternDetailMap; //花纹ram
    SamplerState sampler_PatternDiffuseMap;
    //砍掉花纹的法线贴图
    // sampler2D _PatternNormalMap; //花纹normal
    half _PatternDetailWeight;
    half _PatternTiling; //花纹密度
    half _PatternNormalWeight; //花纹法线融合度
    half _PatternRoughnessScale;
    half _PatternOcclusionScale;
    half _PatternMetallicScale;
    half _PatternRotateAngle; //花纹旋转角度（角度制）
    //#endif

    half _TransparentShadowFactor;
    half _TattoAlphaOffset;

    half4 _SweepColor;
    float4 _SweepTex_ST;
    half _ForceTransparent;
    half _SweepRotator;
    sampler2D _SweepTex;

CBUFFER_END

#endif

//底色
