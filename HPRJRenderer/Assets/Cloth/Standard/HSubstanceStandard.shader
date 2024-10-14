Shader "H/Substance/Standard"
{
    Properties
    {
        //主体
		[Main(g1, _, 3)]_MAIN ("主体", Float) = 0
        //[HideInInspector][SubToggle(g1, _CHARACTERSHADOWCASTER_YES)]_CharacterShadowCaster("投射角色阴影",Float)=1
        [SubEnum(g1, Char01(Main), 0, char02(Sup), 1, char03(Sup), 2, char04(Sup), 3, char05(Sup), 4, 0)]_SupportingCharacterIndex("配角层级", Int)=0
        [SubEnum(g1, Standard, 0, Clip, 1, Overdraw, 2, ClipPlusOverdraw, 3, ST_Front_Back, 4, ST_FB_Layer, 5, 0)]_StandardMode ("Standard模式", Int) = 0

        [SubEnum(g1, uv1, 0, uv2, 1, uv3, 2, uv4, 3, 0)]_UV0 ("主体uv使用第几套", Int) = 0
        [SubEnum(g1, Off, 0, Front, 1, Back, 2, 0)]_CullMode("Cull Mode剔除方式", Int) = 2
        [HideInInspector][SubEnum(g1, Always, 0, Less, 2, Equal, 3, LEqual, 4, GEqual, 5, 4)]_ModifiedZTest("LWGUI修改后ZTest操作方式", Int) = 2
        [RenderingMode(g1)]_RenderingMode ("Rendering Mode", Float) = 0.0
        [SubEnum(g1, Add_0, 0, Add_1, 1, Add_2, 2, Add_3, 3, Add_4, 4, 0)]_QueueOffset("渲染优先级（半透有效）", Int) = 0
        [SubToggle(g1, _ALPHATEST_ON)]_AlphaTest("透明度剔除", Float) = 0.0
        [Sub(g1_ALPHATEST_ON)]_Cutoff("透明度剔除阈值", Range(0.0, 1.0)) = 0.5
        [HideInInspector]_SrcBlend ("__src", Float) = 1.0
        [HideInInspector]_DstBlend ("__dst", Float) = 0.0
        [HideInInspector]_ZWrite ("__zw", Float) = 1.0

        [Color(g1, _)]_Specular("高光颜色", Color) = (1.0, 1.0, 1.0, 1.0)
        [HideInInspector]_ColorTint("Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
        [Tex(g1, _ColorTint)]_MainTex("Albedo (RGB) 主基础色", 2D) = "white" {}
        [Tex(g1)]_MainColorWeight ("色块比重(丝袜专用)", Range(0, 1)) = 1
        [Tex(g1)]_DetailMap("贴图控制RAM 粗糙度（R）AO遮蔽（A）金属度（M）不贴默认111", 2D) = "white" {}
        [Tex(g1)]_NormalMap("Normal Map 主法线贴图", 2D) = "bump" {}

        [Sub(g1)]_RoughnessScale("粗糙度调节(相乘)", Range(0.0, 1.0)) = 1.0
        [Sub(g1)]_OcclusionScale("AO 调节(1到纹理值插值)", Range(0.0, 1.0)) = 1.0
        [Sub(g1)]_MetallicScale ("金属度调节(相乘)", Range(0.0, 1.0)) = 1.0
        
        [SubToggle(g1)]_Furlight("插片毛明暗开关【低画质无】", Float) = 0.0

        [SubToggle(g1, _ANISOTROPY_ON)]_Anisotropy("各向异性开关【低画质无】", Float) = 0.0
        [Sub(g1_ANISOTROPY_ON)]_AnisotropyScale("Anisotropy Scale各项异性范围", Range(-1.0, 1.0)) = 0.0
        [Sub(g1_ANISOTROPY_ON)]_AnisDirection("Anisotropy各项异性方向", Range(0.0, 360.0)) = 0.0

        [SubToggle(g1, _SHEEN_ON)]_Sheen("Sheen 开关 ", Float) = 0.0
        [Color(g1_SHEEN_ON, _)]_SheenColor("Sheen 颜色", Color) = (1.0, 1.0, 1.0, 1.0)
        [Tex(g1_SHEEN_ON)]_SheenTex("Sheen Map", 2D) = "white" {}
        [Sub(g1_SHEEN_ON)]_SheenTiling("Sheen Map密度",Range(0,500)) = 1
        [Tex(g1_SHEEN_ON)]_SheenNormalMap("Sheen Normal Map(高画质有效)", 2D) = "bump" {}
        [Sub(g1_SHEEN_ON)]_SheenNoramlIntensity("Sheen Noraml 强度",Range(0,1)) = 0
        [Sub(g1_SHEEN_ON)]_SheenWarp("Sheen扭动(X,Y SheenMap;Z,W Normal Scale)", Vector) = (1.0, 1.0, 1.0, 1.0)
        [Tex(g1_SHEEN_ON)]_ClothDFG("Cloth LUT", 2D) = "white" {}
        [Sub(g1_SHEEN_ON)]_SheenScale("Sheen 强度", Range(0.0, 5.0)) = 1.0
        [Sub(g1_SHEEN_ON)]_SheenRoughnessScale("Sheen 粗糙度范围", Range(-1.0, 1.0)) = 1.0
        [Sub(g1_SHEEN_ON)]_SheenMetallic("Sheen 金属度", Range(0.0, 1.0)) = 1.0

        [SubToggle(g1, _COLOR_CAST_ON)]_ColorCast("偏色开关【低画质无】", Float) = 0.0
        [Tex(g1_COLOR_CAST_ON)]_ColorCastMap ("偏色贴图", 2D) = "white" {}
        [Sub(g1_COLOR_CAST_ON)]_ColorCastTiling("偏色贴图缩放",Range(0,5)) = 1
        [Sub(g1_COLOR_CAST_ON)]_ColorCastIntensity("偏色贴图强度",Range(0,1)) = 1


        [SubToggle(g1, _CLEARCOAT_ON)]_ClearCoat("清漆开关【低画质无】", Float) = 0.0
        [Sub(g1_CLEARCOAT_ON)]_ClearCoatScale("清漆强度", Range(0.0, 1.0)) = 0.5
        [Sub(g1_CLEARCOAT_ON)]_ClearCoatRoughness("清漆粗糙度", Range(0.0, 1.0)) = 0.5
        [Tex(g1_CLEARCOAT_ON)]_ClearCoatNormalTex("清漆法线贴图", 2D) = "bump" {}
        [Sub(g1_CLEARCOAT_ON)]_ClearCoatBumpScale("清漆法线强度", Range(0.0, 2.0)) = 1.0

        [Emission(g1, _EMISSION_ON)]_EmissionOn("Emission 自发光开关【低画质无】", Float) = 0.0
        [HideInInspector][HDR]_EmissionColor("Emission Color 自发光颜色", Color) = (0.0, 0.0, 0.0, 1.0)
        [Tex(g1_EMISSION_ON, _EmissionColor)]_EmissionTex("Emission Map 自发光贴图", 2D) = "white" {}
        [Sub(g1)]_DarkColor("暗部颜色", Color) = (0,0,0,1)
        [Sub(g1)]_DarkPow("暗部颜色限制",Range(1,10)) = 2
        //底色属性已废弃,但getint必须
		// [Main(g2, _, 3)]_ALBEDO ("底色", Float) = 0
		//[HideInInspector][SubEnum(g2, uv1, 0, uv2, 1, uv3, 2, uv4, 3, 0)]_UV1 ("底色uv使用第几套", Int) = 1
		// [Tex(g2)]_AlbedoMap ("Albedo (RGB) 基色映射", 2D) = "white" {} //主要是全局变色用

        //布料纹理 
        [Main(g3, _DETAIL_ON, 1)]_DETAIL ("布料纹理", Float) = 0
		[SubEnum(g3, uv1, 0, uv2, 1, uv3, 2, uv4, 3, 0)]_UV2 ("布料纹理uv使用第几套", Int) = 2
		[SubEnum(g3, ALPHA, 0, MULTI, 1, 0)]_DetailBlend ("颜色叠加方式：alpha透明叠加/multi正片叠底", Int) = 0
		[Tex(g3)]_DetailDiffuseMap ("Detail RGBA 布料固有色 A透明度", 2D) = "white" {}
        [Sub(g3)]_DetailDiffuseTiling("纹理图案密度",Range(0,500)) = 1
		[Tex(g3)]_DetailNormalMap ("纹理法线贴图", 2D) = "bump" {}
        [Sub(g3)]_DetailNormalTiling("纹理法线密度",Range(0,500)) = 1
		[Sub(g3)]_DetailNormalScale("纹理法线强度",Range(0, 2.5)) = 1
		[Tex(g3)]_DetailDetailMap ("细节RAM R粗糙度 G环境遮蔽 B金属度 【低画质无】", 2D) = "white" {}
        [Sub(g3)]_DetailRoughnessScale("粗糙度调节", Range(0.0, 1.0)) = 1.0
        [Sub(g3)]_DetailOcclusionScale("AO 调节", Range(0.0, 1.5)) = 1.0
        [Sub(g3)]_DetailMetallicScale ("金属度调节(相乘)", Range(0.0, 1.0)) = 1.0

        //花纹
		[Main(g4, _PATTERN_ON, 1)]_PATTERN ("花纹", Float) = 0
		[SubEnum(g4, uv1, 0, uv2, 1, uv3, 2, uv4, 3, 0)]_UV3 ("花纹uv使用第几套", Int) = 3
		// 花纹 有单独ram
        [SubEnum(g3, OVERRIDE, 0, ADD, 1, 0)]_PatternBlend ("图片叠加方式：OVERRIDE覆盖/ADD叠加", Int) = 0
        [HideInInspector]_PatternColorTint("花纹Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
		[Tex(g4, _PatternColorTint)]_PatternDiffuseMap ("花纹固有色", 2D) = "white" {}
		[Tex(g4)]_PatternNormalMap ("花纹法线RG B通道作透明度 【低画质无】", 2D) = "bump" {}
        [Tex(g4)]_PatternDetailMap("花纹RAM图 【低画质无】", 2D) = "white" {}
		[Sub(g4)]_PatternDetailWeight("花纹RAM权重", Range(0, 1)) = 0
		[Sub(g4)]_PatternTiling("花纹密度",Range(0,500)) = 1
		[Sub(g4)]_PatternOffsetX("花纹偏移x",Float) = 0
		[Sub(g4)]_PatternOffsetY("花纹偏移x",Float) = 0
		[Sub(g4)]_PatternNormalWeight("花纹混合法线权重",Range(0,1)) = 1
        [Sub(g4)]_PatternRoughnessScale("粗糙度调节", Range(0.0, 1.0)) = 1.0
        [Sub(g4)]_PatternOcclusionScale("AO 调节", Range(0.0, 1.5)) = 1.0
        [Sub(g4)]_PatternMetallicScale ("金属度调节(相乘)", Range(0.0, 1.0)) = 1.0
        [Sub(g4)]_PatternRotateAngle("花纹贴图旋转角度（顺时针）", Range(0, 360)) = 0

        //闪点
        [Main(g5, _SPARKLE_ON, 1)]_SPARKLE ("闪点", Float) = 0
        [SubToggle(g5, _SPARKLE_ENHANCE_ON)]_SparkleAplhaEnhance("闪点透明度增强", Float) = 0.0
        [Sub(g5_SPARKLE_ENHANCE_ON)]_SparkleEnhancePow("闪点增强调控", Range(1,4)) = 2
        [SubEnum(g5, uv1, 0, uv2, 1, uv3, 2, uv4, 3, 0)]_UV4 ("闪点uv使用第几套", Int) = 0
        [Tex(g5)]_SparkleShapeMap ("闪点形状（R 白色实，黑色非闪点）【低画质默认圆形】", 2D) = "white" {}
        [HideInInspector][HDR]_SparkleColor("闪点颜色", Color) = (1.0, 1.0, 1.0, 1.0)
        [Tex(g5, _SparkleColor)]_SparkleColorMap("闪点颜色贴图【低画质无】", 2D) = "white" {}
        [Tex(g5)]_SparkleScaleMap ("闪点密度亮度图", 2D) = "white" {}
        [Sub(g5)]_SparkleCutoff ("闪点密度", Range(0, 1)) = 0.5
        [Sub(g5)]_SparkleSize ("闪点尺寸", Range(50, 2000)) = 500
        [Sub(g5)]_SparkleScaleMin ("随机缩放", Range(0.01, 1)) = 0.5
        [Sub(g5)]_SparkleDependency ("独立性", Range(0.01, 1)) = 0.5
        [Sub(g5)]_SparkleRoughness ("粗糙度", Range(0, 1)) = 0.5
        [Sub(g5)]_SparkleFrequency ("闪烁频率", Range(100, 2000)) = 500
        //Cubemap
        [Main(g6, _CUSTOM_REFLECTION_ON, 1)]_CUBEMAP("自定义环境反射开关 【低画质无】", Float) = 0 
        [HideInInspector]_CubeColor("Cubemap颜色", Color) = (1, 1, 1, 1)
        [Tex(g6, _CubeColor)]_CustomCubemap ("反射贴图Cubemap", Cube) = "white" {}
        [Sub(g6)]_CubeGlossinessScale ("Cubemap光滑度", Range(0, 1)) = 1
        [Sub(g6)]_CubeColorIntensity ("Cubemap颜色强度", Range(0, 1)) = 1   
        [Sub(g6)]_CubemapRotationX("旋转角度x", Range(0.0, 360.0)) = 0.0
        [Sub(g6)]_CubemapRotationY("旋转角度y", Range(0.0, 360.0)) = 0.0
        [Sub(g6)]_CubemapRotationZ("旋转角度z", Range(0.0, 360.0)) = 0.0
        
        //半透阴影
        [Main(g7, _, 3)]_TRANSPARENTSHADOW ("半透阴影 【低画质无】", Float) = 0
        [SubToggle(g7, _TRANSPARENTSHADOWRECEIVER_YES)]_TransparentShadowReceiver("接受半透阴影",Float)=0
        [SubToggle(g7, _TRANSPARENTSHADOWCASTER_YES)]_TransparentShadowCaster("投射半透阴影",Float)=0
        [SubToggle(g7_TRANSPARENTSHADOWCASTER_YES, _TRANSPARENTSHADOWFACTORBOOL_YES)]_TransparentShadowFactorBool("是否手调阴影透明度",Float)=0
        [Sub(g7_TRANSPARENTSHADOWFACTORBOOL_YES)]_TransparentShadowFactor("阴影透明度",Range(0.0, 1.0))=0.2
        [SubEnum(g7_TRANSPARENTSHADOWCASTER_YES, Off, 0, Front, 1, Back, 2, 0)]_TransparentCullMode("半透阴影剔除方式", Int) = 0
        
        [Main(g9, _, 3)]_RimColor ("边缘光【低画质无】", Float) = 0
        [Sub(g9)]_InSideRimColor ("RimColor", Color) = (1,1,1,1)
        [Sub(g9)]_InSideRimPower("边缘光范围", Range(0.0,10)) = 10 
        [Sub(g9)]_InSideRimIntensity("边缘光强度", Range(0.0,50)) = 0.1 
        
        
        [Main(g8, _, 3)]_EFFECT("特效", Float) = 0
        [SubEnum(g8, NORMAL, 0, DISSOLVE, 1, SWEEP, 2, 0)]_EffectType("特效类型", Int) = 0
        //溶解
        [Sub(g8)]_DissolveCutWidth("溶解区域宽度", Range(0, 0.5)) = 0.03
        [HideInInspector]_DissolveDivisor("边缘位置计算所需除数倒数", Float) = 1
        [Sub(g8)]_DissolveReverse("反向溶解", Float) = 0
        [Sub(g8)]_DissolveDirection("溶解方向", Range(0, 2)) = 2
        //扫光
        [HideInInspector][HDR]_SweepColor("扫光颜色", Color) = (1.5, 1.5, 1.5, 1)
        [Sub(g8)]_SweepColorIntensity("扫光颜色强度", Float) = 1
        [Tex(g8, _SweepColor, 1)]_SweepTex("扫光纹理", 2D) = "black"{}
        // [Tex(g8, _, 1)]_RampTex("扫光叠加纹理", 2D) = "black"{}
        [Sub(g8)]_SweepIntensity("扫光强度", Float) = 1
        [Sub(g8)]_SweepRotator("扫光旋转角度", Float) = 0
        [HideInInspector]_ForceTransparent("强行打开半透", Float) = 0

        //闪烁引导颜色
        [HideInInspector]_Guide_Twinkle_On("引导闪烁开关", Float) = 0
        [HideInInspector]_GuideColor("引导颜色", Color) = (1.0, 1.0, 1.0, 0.0)
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "Queue" = "Geometry" "RenderPipeline" = "UniversalPipeline"}
        LOD 500
        
		Pass {
			Name "StandardPreZ"
			Tags{"LightMode" = "StandardPreZ"}
            ZWrite On
            ColorMask 0
            Cull [_CullMode]

            HLSLPROGRAM
                // -------------------------------------
                // Material Keywords
                #pragma shader_feature_local_fragment _ _PATTERN_ON
                #pragma shader_feature_local_fragment _ _DETAIL_ON
                #pragma shader_feature_local_fragment _ _ALPHATEST_ON

                #pragma vertex ShadingVertex
                #pragma fragment DepthOnlyFragment
                #include "StandardProperties.hlsl"
                #include "StandardCore.hlsl"
            ENDHLSL
        }
        
        Pass
        {
            Name "TransparentPreZ"
            Tags{"LightMode" = "SpecialTranspPreZ"}

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
                // -------------------------------------
                // Material Keywords
                #pragma shader_feature_local_fragment _ _PATTERN_ON
                #pragma shader_feature_local_fragment _ _DETAIL_ON
                #pragma shader_feature_local_fragment _ _ALPHATEST_ON

                #pragma vertex ShadingVertex
                #pragma fragment DepthOnlyFragment
                #include "StandardProperties.hlsl"
                #include "StandardCore.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "TransparentLayerPreZ"
            Tags{"LightMode" = "SRPDefaultUnlit1"}

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
                // -------------------------------------
                // Material Keywords
                #pragma shader_feature_local_fragment _ _PATTERN_ON
                #pragma shader_feature_local_fragment _ _DETAIL_ON
                #pragma shader_feature_local_fragment _ _ALPHATEST_ON

                #pragma vertex ShadingVertex
                #pragma fragment DepthOnlyFragment
                #include "StandardProperties.hlsl"
                #include "StandardCore.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "ClothStencil"
            Tags{"LightMode" = "ClothStencil"}
            ZWrite Off
            ZTest Always
            ColorMask 0
            Cull Back
            
            Stencil
            {
                Ref 3
                Comp Always
                Pass replace
            }
            
            HLSLPROGRAM
                // -------------------------------------
                // Material Keywords
                #pragma shader_feature_local_fragment _ _PATTERN_ON
                #pragma shader_feature_local_fragment _ _DETAIL_ON
                #pragma shader_feature_local_fragment _ _ALPHATEST_ON

                #pragma vertex ShadingVertex
                #pragma fragment DepthOnlyFragment
                #include "StandardProperties.hlsl"
                #include "StandardCore.hlsl"
            ENDHLSL
        }
        
        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            Cull [_CullMode]
            ZTest [_ModifiedZTest]
            Stencil
            {
                Ref 1
                CompFront Always
                PassFront Zero

                CompBack GEqual
                PassBack Keep
            }

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                #pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                
                // -------------------------------------
                // Material Keywords
                #define _NORMALMAP
                #pragma shader_feature_local_fragment _ _DETAIL_ON
                #pragma shader_feature_local_fragment _ _PATTERN_ON
                #pragma shader_feature_local_fragment _ _SPARKLE_ON
                #pragma shader_feature_local_fragment _ _ANISOTROPY_ON
                #pragma shader_feature_local_fragment _ _SHEEN_ON
                #pragma shader_feature_local_fragment _ _CLEARCOAT_ON
                #pragma shader_feature_local_fragment _ _ALPHATEST_ON
                #pragma shader_feature_local_fragment _ _COLOR_CAST_ON
                #pragma shader_feature_local_fragment _ _EMISSION_ON
                //#pragma shader_feature_local_fragment _ _ALPHAPREMULTIPLY_ON
                #pragma shader_feature_local_fragment _ _CUSTOM_REFLECTION_ON

                // -------------------------------------
                // Transparent Shadow Keywords
                #pragma shader_feature _ _TRANSPARENTSHADOWRECEIVER_YES
                 
                #pragma target 3.0
                #pragma multi_compile _ _GLOBAL_TRANSPARENTSHADOW
                #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS

                //---------------------------------------
                // Character Shadow Keywords
                //#pragma shader_feature _ _IsSupCharacter

                #pragma enable_cbuffer

                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment
                #include "StandardProperties.hlsl"
                #include "StandardCore.hlsl"

            ENDHLSL
        }
        
        Pass
        {
            Name "CharacterClothShadowCaster"
            Tags { "LightMode" = "CharacterClothShadowCaster" }
            
            Stencil
            {
                Ref 2
                Comp Always
                Pass replace
            }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
                // -------------------------------------
                // Material Keywords
                #pragma shader_feature_local_fragment _ _PATTERN_ON
                #pragma shader_feature_local_fragment _ _DETAIL_ON
                #pragma shader_feature_local_fragment _ _ALPHATEST_ON
                //#pragma multi_compile _ _MixedShadowTest

                #pragma vertex ShadowPassVertex
                #pragma fragment CharacterShadowPassFragment
                #include "StandardProperties.hlsl"
                #include "StandardCore.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull Back

            HLSLPROGRAM
                // -------------------------------------
                // Material Keywords
                #pragma shader_feature_local_fragment _ _PATTERN_ON
                #pragma shader_feature_local_fragment _ _DETAIL_ON
                #pragma shader_feature_local_fragment _ _ALPHATEST_ON

                #pragma vertex ShadingVertex
                #pragma fragment DepthOnlyFragment
                #include "StandardProperties.hlsl"
                #include "StandardCore.hlsl"
            ENDHLSL
        }
		Pass
        {
            Name "Mask"
            Tags{"LightMode" = "Mask"}

            ZWrite On
            Cull[_CullMode]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "StandardProperties.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                output.uv = input.uv;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.vertex = vertexInput.positionCS;

                return output;
            }

            float4 frag(Varyings input) : SV_Target
            {
                float alpha = _MainTex.Sample(sampler_MainTex, input.uv).a;
                clip(alpha - _Cutoff + 0.0001f);
                return 0;
            }

            ENDHLSL
        }
        
        // ------------------------------------------------------------------
        // Transparent Shadow Pass
//        Pass
//        {
//            Name "TransparentShadowCaster"
//            Tags { "LightMode" = "TransparentShadowCaster" }
//            
//            ZWrite On
//            ZTest LEqual
//            Cull [_TransparentCullMode]
//            
//            HLSLPROGRAM
//            
//            #pragma shader_feature_local_fragment _ALPHATEST_ON
//            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
//             //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
//            #pragma multi_compile _ _SHADOWS_SOFT//柔化阴影，得到软阴影
//
//            #pragma vertex TransparentVertex
//            #pragma fragment TransparentFragment
//            
//            #include "StandardProperties.hlsl"
//            #include "Packages/com.unity.render-pipelines.universal/Shaders/TransparentShadowPass.hlsl"
//            ENDHLSL
//        }

        // ------------------------------------------------------------------
        // Transparent Shadow Pass

//        Pass 
//        {
//            Name "TranspSupShadowCaster"
//            Tags { "LightMode" = "TranspSupShadowCaster" }
//            //Blend SrcAlpha OneMinusSrcAlpha
//            //Blend Zero DstAlpha
//            //Blend SrcAlpha OneMinusSrcAlpha
//            Blend Zero SrcColor
//            BlendOp Add
//            ZWrite Off
//            ZTest Off
//            Cull [_TransparentCullMode]
//
//            HLSLPROGRAM
//            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
//
//            // -------------------------------------
//            // Material Keywords
//            #pragma shader_feature_local_fragment _ALPHATEST_ON
//            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
//
//            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
//            //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
//            #pragma multi_compile _ _SHADOWS_SOFT//柔化阴影，得到软阴影
//            
//            #pragma shader_feature _ _TRANSPARENTSHADOWFACTORBOOL_YES
//
//            #pragma vertex TransparentSupVertex
//            #pragma fragment TransparentSupFragment
//            #include "StandardProperties.hlsl"
//            #include "Packages/com.unity.render-pipelines.universal/Shaders/TransparentSupportShadowPass.hlsl"
//            ENDHLSL
//        }
//        
        
    }
    
    SubShader
    {
        Tags{"RenderType" = "Opaque" "Queue" = "Geometry" "RenderPipeline" = "UniversalPipeline"}
        LOD 300
        
		Pass {
			Name "StandardPreZ"
			Tags{"LightMode" = "StandardPreZ"}
            ZWrite On
            ColorMask 0
            Cull [_CullMode]

            HLSLPROGRAM
                // -------------------------------------
                // Material Keywords
                #pragma shader_feature_local_fragment _ _PATTERN_ON
                #pragma shader_feature_local_fragment _ _DETAIL_ON
                #pragma shader_feature_local_fragment _ _ALPHATEST_ON

                #pragma vertex ShadingVertex
                #pragma fragment DepthOnlyFragment
                #include "StandardProperties.hlsl"
                #include "StandardCore.hlsl"
            ENDHLSL
        }
        
        Pass
        {
            Name "ClothStencil"
            Tags{"LightMode" = "ClothStencil"}
            ZWrite Off
            ZTest Always
            ColorMask 0
            Cull Back
            
            Stencil
            {
                Ref 3
                Comp Always
                Pass replace
            }
            
            HLSLPROGRAM
                // -------------------------------------
                // Material Keywords
                #pragma shader_feature_local_fragment _ _PATTERN_ON
                #pragma shader_feature_local_fragment _ _DETAIL_ON
                #pragma shader_feature_local_fragment _ _ALPHATEST_ON

                #pragma vertex ShadingVertex
                #pragma fragment DepthOnlyFragment
                #include "StandardProperties.hlsl"
                #include "StandardCore.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "TransparentLayerPreZ"
            Tags{"LightMode" = "SRPDefaultUnlit"}

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
                // -------------------------------------
                // Material Keywords
                #pragma shader_feature_local_fragment _ _PATTERN_ON
                #pragma shader_feature_local_fragment _ _DETAIL_ON
                #pragma shader_feature_local_fragment _ _ALPHATEST_ON

                #pragma vertex ShadingVertex
                #pragma fragment DepthOnlyFragment
                #include "StandardProperties.hlsl"
                #include "StandardCore.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            Cull [_CullMode]
            ZTest [_ModifiedZTest]
            Stencil
            {
                Ref 1
                CompFront Always
                CompBack GEqual
            }

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                
                // -------------------------------------
                // Material Keywords
                #define _NORMALMAP
                #pragma shader_feature_local_fragment _ _DETAIL_ON
                #pragma shader_feature_local_fragment _ _PATTERN_ON
                //#pragma shader_feature_local_fragment _ _ANISOTROPY_ON
                #pragma shader_feature_local_fragment _ _SHEEN_ON
                #pragma shader_feature_local_fragment _ _ALPHATEST_ON
                //#pragma shader_feature_local_fragment _ _COLOR_CAST_ON
                //#pragma shader_feature_local_fragment _ _CUSTOM_REFLECTION_ON
                #pragma shader_feature_local_fragment _ _SPARKLE_ON

                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment
                #include "StandardProperties.hlsl"
                #include "LowStandardCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull Back

            HLSLPROGRAM
                // -------------------------------------
                // Material Keywords
                #pragma shader_feature_local_fragment _ _PATTERN_ON
                #pragma shader_feature_local_fragment _ _DETAIL_ON
                #pragma shader_feature_local_fragment _ _ALPHATEST_ON

                #pragma vertex ShadingVertex
                #pragma fragment DepthOnlyFragment
                #include "StandardProperties.hlsl"
                #include "StandardCore.hlsl"
            ENDHLSL
        }
        
        Pass
        {
            Name "TransparentPreZ"
            Tags{"LightMode" = "SpecialTranspPreZ"}

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
                // -------------------------------------
                // Material Keywords
                #pragma shader_feature_local_fragment _ _PATTERN_ON
                #pragma shader_feature_local_fragment _ _DETAIL_ON
                #pragma shader_feature_local_fragment _ _ALPHATEST_ON

                #pragma vertex ShadingVertex
                #pragma fragment DepthOnlyFragment
                #include "StandardProperties.hlsl"
                #include "StandardCore.hlsl"
            ENDHLSL
        }
        
		Pass
        {
            Name "Mask"
            Tags{"LightMode" = "Mask"}

            ZWrite On
            Cull[_CullMode]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "StandardProperties.hlsl"


            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                output.uv = input.uv;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.vertex = vertexInput.positionCS;

                return output;
            }

            float4 frag(Varyings input) : SV_Target
            {
                float alpha = _MainTex.Sample(sampler_MainTex, input.uv).a;
                clip(alpha - _Cutoff + 0.0001f);
                return 0;
            }

            ENDHLSL
        }
    }
   	CustomEditor "JTRP.ShaderDrawer.LWGUI"
}
//