Shader "H/Substance/FurShell"
{
    Properties
    {
        [HideInInspector]_IsFurShell ("is FurShell", Float) = 1.0

        [Main(g1, _, 3)]_PARAMS ("基本参数", Float) = 0
        [SubEnum(g1, Add_0, 0, Add_1, 1, Add_2, 2, Add_3, 3, Add_4, 4, Add_5, 5, Add_6, 6, Add_7, 7, Add_8, 8, Add_9, 9, 0)]_QueueOffset("渲染优先级（半透有效）", Int) = 0

        //[HideInInspector][SubToggle(g1, _CHARACTERSHADOWCASTER_YES)]_CharacterShadowCaster("投射角色阴影",Float)=1
        [HideInInspector][KeywordEnum(Char01(Main), char02(Sup),  char03(Sup), char04(Sup),  char05(Sup))]_SupportingCharacterIndex("配角层级", Float)=0

		[HideInInspector]_ColorTint("Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
		[Tex(g1, _ColorTint)]_AlbedoMap("Albedo(RGB:颜色, A:长度)", 2D) = "white" {}
		[Tex(g1)]_DetailMap("贴图控制RA 粗糙度（R）AO遮蔽（A）无金属度", 2D) = "green" {}
		[Tex(g1)]_NormalMap("法线贴图", 2D) = "bump" {}
        [Sub(g1)]_NormalScale("法线强度调节", Range(0.0, 2.0)) = 1.0
        [Sub(g1)]_RoughnessScale("粗糙度调节(相乘)", Range(0.0, 1.0)) = 1.0
        [Sub(g1)]_OcclusionScale("AO 调节(1到纹理值插值)", Range(0.0, 1.0)) = 1.0

        [Main(g2, _, 3)]_FUR ("皮毛参数", Float) = 0
		[Tex(g2)]_FurNoiseMap("皮毛噪声贴图", 2D) = "white" {}
		[Sub(g2)]_FurScale("皮毛密度", Range(0.1, 200.0)) = 50.0
		[Sub(g2)]_FurLength("皮毛长度", Range(0.0, 1.0)) = 0.2
        [Sub(g2)]_FurOcclusion("皮毛遮蔽", Range(0.0, 1.0)) = 0.3
		[Sub(g2)]_AlphaCutout("透明度剔除", Range(0.0, 1.0)) = 1.0
		[Sub(g2)]_EdgeFade("边缘渐隐", Range(0.0, 1.0)) = 0.5
        
        [Main(g7, _, 3)]_FLOWMAPPROP ("边缘处理", Float) = 0
        [Sub(g7)]_ClipAdjust("毛发尖端粗细调整（为1时无调整）", range(0,1)) = 0.25
        [SubToggle(g7, _FRESNELEDGE_ON)]_FRESNELEDGE("启用边缘增强",Float)=0
		[Sub(g7)]_DeepAreaColor("边缘颜色", Color) = (0.6, 0.4, 0.4, 1.0)
        [Sub(g7)]_RimIntensity("边缘强度", range(0,3)) = 0.9
        [Sub(g7)]_RimPower("边缘范围（对内）", range(0,5)) = 3.0
        [Sub(g7)]_EdgeControl("边缘长度（对外）", range(0,1)) = 0.36

        [Main(g3, _, 3)]_SCATTER ("散射参数", Float) = 0
		[Sub(g3)]_ScatterColor("散射颜色", Color) = (0.0, 0.0, 0.0, 1.0)
		[Sub(g3)]_ScatterScale("散射范围", Range(0, 1)) = 1.0

		[Main(g4, _, 3)]_ANIMATION ("模型空间动画", Float) = 0
		[Sub(g4)]_GravityStrength("重力强度", Range(0.0, 1.0)) = 0.3
		[Sub(g4)]_GravityDir("重力方向(xyz)", Vector) = (0.0, 0.0, -1.0, 0.0)
		[Sub(g4)]_WindStrength("风力强度", Range(0.0, 1.0)) = 0.1
	    [Sub(g4)]_WindDir("风力方向(xyz)", Vector) = (0.2, 0.3, 0.2, 0.0)
	    [Sub(g4)]_WindFreq("风力频率(xyz)", Vector) = (0.5, 0.7, 0.9, 1.0)
        
        [Main(g5, _, 3)]_INTENSITY_MASK ("区域控制", Float) = 0
        [Tex(g5)]_ParamMaskMap("区域控制贴图", 2D) = "white" {}
        [Sub(g5)]_IntensityMaskScale("区域贴图调节", Range(0,1)) = 1


        //半透阴影
        [Main(g6, _, 3)]_TRANSPARENTSHADOW ("半透阴影", Float) = 0
        [SubToggle(g6, _TRANSPARENTSHADOWRECEIVER_YES)]_TransparentShadowReceiver("接受半透阴影",Float)=0
        [SubToggle(g6, _TRANSPARENTSHADOWCASTER_YES)]_TransparentShadowCaster("投射半透阴影",Float)=0
        [SubToggle(g6_TRANSPARENTSHADOWCASTER_YES, _TRANSPARENTSHADOWFACTORBOOL_YES)]_TransparentShadowFactorBool("是否手调阴影透明度",Float)=0
        [Sub(g6_TRANSPARENTSHADOWFACTORBOOL_YES)]_TransparentShadowFactor("阴影透明度",Range(0.0, 1.0))=0.2
        [SubEnum(g6_TRANSPARENTSHADOWCASTER_YES, Off, 0, Front, 1, Back, 2, 0)]_TransparentCullMode("半透阴影剔除方式", Int) = 0
        
        //[Main(g7, _, 1)]_MANUALCOLORSHADING("手动Color Grading", Float) = 0
        //[Tex(g7)]_CustomLUT("Custom LUT", 2D) = "white"{}
        
        
    }
    SubShader
    {
        Tags{"RenderPipeline" = "UniversalPipeline" "Queue" = "Transparent" "RenderType" = "Transparent"}
        LOD 800
        Pass
        {
            Tags { "LightMode" = "FurShell0" }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                 //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                
                #pragma shader_feature _ _FRESNELEDGE_ON
                #pragma shader_feature _ _APPLY_COLORGRADING_MANUAL
                #pragma shader_feature _ _TRANSPARENTSHADOWRECEIVER_YES
                #pragma multi_compile _ _GLOBAL_TRANSPARENTSHADOW
            
                //---------------------------------------
                // Character Shadow Keywords
                //#pragma shader_feature _ _IsSupCharacter
                #define _NORMALMAP
                #pragma target 3.0
                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment

                #define SHELL_OFFSET 0.0
                #include "FurShellCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "FurShell1" }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                 //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                
                #pragma shader_feature _ _FRESNELEDGE_ON
                #pragma shader_feature _ _APPLY_COLORGRADING_MANUAL
                #pragma shader_feature _ _TRANSPARENTSHADOWRECEIVER_YES
                #pragma multi_compile _ _GLOBAL_TRANSPARENTSHADOW
            
                //---------------------------------------
                // Character Shadow Keywords
                //#pragma shader_feature _ _IsSupCharacter

                #pragma target 3.0
                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment

                #define SHELL_OFFSET 0.08333
                #include "FurShellCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "FurShell2" }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                 //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                
                #pragma shader_feature _ _FRESNELEDGE_ON
                #pragma shader_feature _ _APPLY_COLORGRADING_MANUAL
                #pragma shader_feature _ _TRANSPARENTSHADOWRECEIVER_YES
                #pragma multi_compile _ _GLOBAL_TRANSPARENTSHADOW
            
                //---------------------------------------
                // Character Shadow Keywords
                //#pragma shader_feature _ _IsSupCharacter

                #pragma target 3.0
                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment

                #define SHELL_OFFSET 0.16666
                #include "FurShellCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "FurShell3" }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                 //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                
                #pragma shader_feature _ _FRESNELEDGE_ON
                #pragma shader_feature _ _APPLY_COLORGRADING_MANUAL
                #pragma shader_feature _ _TRANSPARENTSHADOWRECEIVER_YES
                #pragma multi_compile _ _GLOBAL_TRANSPARENTSHADOW
            
                //---------------------------------------
                // Character Shadow Keywords
                //#pragma shader_feature _ _IsSupCharacter

                #pragma target 3.0
                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment

                #define SHELL_OFFSET 0.25
                #include "FurShellCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "FurShell4" }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                 //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                
                #pragma shader_feature _ _FRESNELEDGE_ON
                #pragma shader_feature _ _APPLY_COLORGRADING_MANUAL
                #pragma shader_feature _ _TRANSPARENTSHADOWRECEIVER_YES
                #pragma multi_compile _ _GLOBAL_TRANSPARENTSHADOW
            
                //---------------------------------------
                // Character Shadow Keywords
                //#pragma shader_feature _ _IsSupCharacter

                #pragma target 3.0
                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment

                #define SHELL_OFFSET 0.33333
                #include "FurShellCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "FurShell5" }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                 //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                
                #pragma shader_feature _ _FRESNELEDGE_ON
                #pragma shader_feature _ _APPLY_COLORGRADING_MANUAL
                #pragma shader_feature _ _TRANSPARENTSHADOWRECEIVER_YES
                #pragma multi_compile _ _GLOBAL_TRANSPARENTSHADOW
            
                //---------------------------------------
                // Character Shadow Keywords
                //#pragma shader_feature _ _IsSupCharacter

                #pragma target 3.0
                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment

                #define SHELL_OFFSET 0.41666
                #include "FurShellCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "FurShell6" }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                 //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                
                #pragma shader_feature _ _FRESNELEDGE_ON
                #pragma shader_feature _ _APPLY_COLORGRADING_MANUAL
                #pragma shader_feature _ _TRANSPARENTSHADOWRECEIVER_YES
                #pragma multi_compile _ _GLOBAL_TRANSPARENTSHADOW
            
                //---------------------------------------
                // Character Shadow Keywords
                //#pragma shader_feature _ _IsSupCharacter

                #pragma target 3.0
                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment

                #define SHELL_OFFSET 0.5
                #include "FurShellCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "FurShell7" }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                 //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                
                #pragma shader_feature _ _FRESNELEDGE_ON
                #pragma shader_feature _ _APPLY_COLORGRADING_MANUAL
                #pragma shader_feature _ _TRANSPARENTSHADOWRECEIVER_YES
                #pragma multi_compile _ _GLOBAL_TRANSPARENTSHADOW
            
                //---------------------------------------
                // Character Shadow Keywords
                //#pragma shader_feature _ _IsSupCharacter

                #pragma target 3.0
                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment

                #define SHELL_OFFSET 0.58333
                #include "FurShellCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "FurShell8" }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                 //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                
                #pragma shader_feature _ _FRESNELEDGE_ON
                #pragma shader_feature _ _APPLY_COLORGRADING_MANUAL
                #pragma shader_feature _ _TRANSPARENTSHADOWRECEIVER_YES
                #pragma multi_compile _ _GLOBAL_TRANSPARENTSHADOW
            
                //---------------------------------------
                // Character Shadow Keywords
                //#pragma shader_feature _ _IsSupCharacter

                #pragma target 3.0
                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment

                #define SHELL_OFFSET 0.66667
                #include "FurShellCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "FurShell9" }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                 //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                
                #pragma shader_feature _ _FRESNELEDGE_ON
                #pragma shader_feature _ _APPLY_COLORGRADING_MANUAL
                #pragma shader_feature _ _TRANSPARENTSHADOWRECEIVER_YES
                #pragma multi_compile _ _GLOBAL_TRANSPARENTSHADOW
            
                //---------------------------------------
                // Character Shadow Keywords
                //#pragma shader_feature _ _IsSupCharacter

                #pragma target 3.0
                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment

                #define SHELL_OFFSET 0.75
                #include "FurShellCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "FurShell10" }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                 //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                
                #pragma shader_feature _ _FRESNELEDGE_ON
                #pragma shader_feature _ _APPLY_COLORGRADING_MANUAL
                #pragma shader_feature _ _TRANSPARENTSHADOWRECEIVER_YES
                #pragma multi_compile _ _GLOBAL_TRANSPARENTSHADOW
            
                //---------------------------------------
                // Character Shadow Keywords
                //#pragma shader_feature _ _IsSupCharacter

                #pragma target 3.0
                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment

                #define SHELL_OFFSET 0.83333
                #include "FurShellCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "FurShell11" }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                 //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                
                #pragma shader_feature _ _FRESNELEDGE_ON
                #pragma shader_feature _ _APPLY_COLORGRADING_MANUAL
                #pragma shader_feature _ _TRANSPARENTSHADOWRECEIVER_YES
                #pragma multi_compile _ _GLOBAL_TRANSPARENTSHADOW
            
                //---------------------------------------
                // Character Shadow Keywords
                //#pragma shader_feature _ _IsSupCharacter

                #pragma target 3.0
                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment

                #define SHELL_OFFSET 0.91667
                #include "FurShellCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "FurShell12" }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                 //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                
                #pragma shader_feature _ _FRESNELEDGE_ON
                #pragma shader_feature _ _APPLY_COLORGRADING_MANUAL
                #pragma shader_feature _ _TRANSPARENTSHADOWRECEIVER_YES
                #pragma multi_compile _ _GLOBAL_TRANSPARENTSHADOW
            
                //---------------------------------------
                // Character Shadow Keywords
                //#pragma shader_feature _ _IsSupCharacter

                #pragma target 3.0
                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment

                #define SHELL_OFFSET 1.0
                #include "FurShellCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
                // -------------------------------------
                #pragma vertex ShadowPassVertex
                #pragma fragment ShadowPassFragment

                #include "FurShellCore.hlsl"
            ENDHLSL
        }
                
//        Pass
//        {
//            Name "CharacterShadowCaster"
//            Tags { "LightMode" = "CharacterShadowCaster" }
//
//            ZWrite On
//            ZTest LEqual
//            ColorMask 0
//            Cull Back
//
//            HLSLPROGRAM
//                // -------------------------------------
//                #pragma vertex ShadowPassVertex
//                #pragma fragment CharacterShadowPassFragment
//
//                #include "FurShellCore.hlsl"
//            ENDHLSL
//        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull Back

            HLSLPROGRAM
                // -------------------------------------

                #pragma vertex DepthOnlyVertex
                #pragma fragment DepthOnlyFragment
                #include "FurShellCore.hlsl"
            ENDHLSL
        }
        // ------------------------------------------------------------------
        // Transparent Shadow Pass
        Pass
        {
            Name "TransparentShadowCaster"
            Tags { "LightMode" = "TransparentShadowCaster" }
            
            ZWrite On
            ZTest LEqual
            Cull [_TransparentCullMode]
            
            HLSLPROGRAM
            
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
             //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT//柔化阴影，得到软阴影
                        
            #pragma vertex TransparentSupVertex
            #pragma fragment TransparentFragment

            #include "FurShellCore.hlsl"
            ENDHLSL
        }

        // ------------------------------------------------------------------
        // Transparent Shadow Pass

        Pass 
        {
            Name "TranspSupShadowCaster"
            Tags { "LightMode" = "TranspSupShadowCaster" }
            //Blend SrcAlpha OneMinusSrcAlpha
            //Blend Zero DstAlpha
            //Blend SrcAlpha OneMinusSrcAlpha
            Blend Zero SrcColor
            BlendOp Add
            ZWrite Off
            ZTest Off
            Cull [_TransparentCullMode]

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON
            
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
             //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT//柔化阴影，得到软阴影
            
             
            #pragma shader_feature _ _TRANSPARENTSHADOWFACTORBOOL_YES

            #pragma vertex TransparentSupVertex
            #pragma fragment TransparentSupFragment

            #include "FurShellCore.hlsl"
            ENDHLSL
        }
    }
    SubShader
    {
        Tags{"RenderPipeline" = "UniversalPipeline" "Queue" = "Transparent" "RenderType" = "Transparent"}
        LOD 300

        Pass
        {
            Tags { "LightMode" = "FurShell0" }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                 //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                #define _NORMALMAP
                #pragma shader_feature _ _FRESNELEDGE_ON
                #pragma shader_feature _ _APPLY_COLORGRADING_MANUAL

                #pragma target 3.0
                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment

                #define SHELL_OFFSET 0.0
                #include "FurShellCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "FurShell1" }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                 //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                
                #pragma shader_feature _ _FRESNELEDGE_ON
                #pragma shader_feature _ _APPLY_COLORGRADING_MANUAL

                #pragma target 3.0
                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment

                #define SHELL_OFFSET 0.14286
                #include "FurShellCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "FurShell2" }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                 //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                
                #pragma shader_feature _ _FRESNELEDGE_ON
                #pragma shader_feature _ _APPLY_COLORGRADING_MANUAL

                #pragma target 3.0
                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment

                #define SHELL_OFFSET 0.28571
                #include "FurShellCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "FurShell3" }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                 //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                
                #pragma shader_feature _ _FRESNELEDGE_ON
                #pragma shader_feature _ _APPLY_COLORGRADING_MANUAL

                #pragma target 3.0
                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment

                #define SHELL_OFFSET 0.42857
                #include "FurShellCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "FurShell4" }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                 //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                
                #pragma shader_feature _ _FRESNELEDGE_ON
                #pragma shader_feature _ _APPLY_COLORGRADING_MANUAL

                #pragma target 3.0
                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment

                #define SHELL_OFFSET 0.57142
                #include "FurShellCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "FurShell5" }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                 //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                
                #pragma shader_feature _ _FRESNELEDGE_ON
                #pragma shader_feature _ _APPLY_COLORGRADING_MANUAL

                #pragma target 3.0
                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment

                #define SHELL_OFFSET 0.71429
                #include "FurShellCore.hlsl"

            ENDHLSL
        }    

        Pass
        {
            Tags { "LightMode" = "FurShell6" }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                 //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                
                #pragma shader_feature _ _FRESNELEDGE_ON
                #pragma shader_feature _ _APPLY_COLORGRADING_MANUAL

                #pragma target 3.0
                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment

                #define SHELL_OFFSET 0.85714
                #include "FurShellCore.hlsl"

            ENDHLSL
        } 

        Pass
        {
            Tags { "LightMode" = "FurShell7" }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                 //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
                
                #pragma shader_feature _ _FRESNELEDGE_ON
                #pragma shader_feature _ _APPLY_COLORGRADING_MANUAL

                #pragma target 3.0
                #pragma vertex ShadingVertex
                #pragma fragment ShadingFragment

                #define SHELL_OFFSET 1.0
                #include "FurShellCore.hlsl"

            ENDHLSL
        } 

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
                // -------------------------------------
                #pragma vertex ShadowPassVertex
                #pragma fragment ShadowPassFragment

                #include "FurShellCore.hlsl"
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

                #pragma vertex DepthOnlyVertex
                #pragma fragment DepthOnlyFragment
                #include "FurShellCore.hlsl"
            ENDHLSL
        }
    }
   	CustomEditor "JTRP.ShaderDrawer.LWGUI"
}
