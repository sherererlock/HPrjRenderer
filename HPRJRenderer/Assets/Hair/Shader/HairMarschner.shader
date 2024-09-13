Shader "Hair/Marschner"
{
    Properties
    {
        [NoScaleOffset] _MainMap("四合一主贴图(R:ID, G:Root, B:Occlusion, A: Alpha)", 2D) = "white" {}
        [KeywordEnum(Char01(Main), char02(Sup),  char03(Sup), char04(Sup),  char05(Sup))]_SupportingCharacterIndex("配角层级", Float)=0

        _AlphaCutoff("透明度剔除阈值", Range(0.0, 1.0)) = 0.333
        _PerceptualRoughness("粗糙度", Range(0.0, 2.0)) = 1.0
        _Brightness("亮度", Range(0.0, 4.0)) = 1.0

        _IndirectIntensity("间接光照强度", Range(0.0, 2.0)) = 1.0
        _AddLightIntensity("主光以外直接光强度", Range(0.0, 1.0)) = 1.0
        _Scatter("散射强度", Range(0.0, 2.0)) = 1.0
        _HighlightIntensity("高光强度", Range(0.0, 10.0)) = 1.0
        _InnerHighlightIntensity("内部高光强度", Range(0.0, 5.0)) = 1.0
        _BacklitIntensity("背面透光强度", Range(0.0, 2.0)) = 1.0

        _ShadowIntensity("阴影强度", Range(0.0, 2.0)) = 1.0
        _Absorbtion("光线吸收强度", Range(0.0, 20.0)) = 8.0
        _ShadowRoot("阴影发根至发梢变化", Range(0.0, 1.0)) = 0.0
        _ShadowBlur("阴影模糊程度",Range(0.0, 10.0)) = 1.0
        _DepthOffset("深度偏移 当前无用不生效）", Range(0.0, 10.0)) = 0.0
        [NoScaleOffset] _BakedOcclusionMap("预烘焙遮蔽贴图(UV2)", 2D) = "white" {}
        _OcclusionIntensity("遮蔽强度", Range(0.0, 2.0)) = 1.0
        [NoScaleOffset] _BakedShadowTex("预烘焙阴影贴图(UV2)", 2D) = "white" {}
        _BakedShadowIntensity("预烘焙阴影强度", Range(0.0, 2.0)) = 1.0
        
        _ShadowTintColor("阴影颜色", Color) = (1, 1, 1, 1)
        _ShadowTintPower("阴影颜色范围", Range(0.3, 2.0)) = 1.0

        [KeywordEnum(UV1, UV2, UV3)] _HAIRUV("颜色贴图适用UV", Float) = 0
        [NoScaleOffset] _ColorMap("颜色贴图(RGB)", 2D) = "white" {}
        [KeywordEnum(Root, UV3)] _GradientMode("颜色渐变依据", Float) = 0
        _Color("整体颜色", Color) = (1, 1, 1, 1)
        _TipColor("发梢颜色", Color) = (1, 1, 1, 1)
        _RootColor("发根颜色", Color) = (1, 1, 1, 1)
        _RootPower("发根至发梢变化速度", Range(0.0, 2.0)) = 1.0
        _HueVariation("发丝层面色相变化", Range(0.0, 1.0)) = 0.0
        _BrightnessVariation("发丝层面明度变化", Range(0.0, 1.0)) = 0.0

        [NoScaleOffset] _DirectionMap("发丝走向贴图", 2D) = "grey" {}
        [KeywordEnum(V, DirectionMap, U)] _FlowDirection ("发丝走向", Float) = 0
        _FlowVariation("发丝方向随机性", Range(0.0, 1.0)) = 0.6

        [KeywordEnum(Off, Color, ID, Root, Occlusion, Alpha, Flow)] _Vis ("调试检视的属性", Float) = 0
        [KeywordEnum(All, R, TT, TRT, Scatter, Shadow)] _LightPath ("检视各光路的亮度贡献", Float) = 0
        [KeywordEnum(All, Direct, Indirect)] _LightComponent ("检视直接光或间接光的贡献", Float) = 0
        _DebugValue("无意义，程序测试用", Range(-1.0, 1.0)) = 1.0

        [Enum(NORMAL, 0, DISSOLVE, 1, SWEEP, 2, 0)]_EffectType("特效类型", Int) = 0
        //扫光
        [HDR]_SweepColor("扫光颜色", Color) = (1.5, 1.5, 1.5, 1)
        _SweepColorIntensity("扫光颜色强度", Float) = 1
        _SweepTex("扫光纹理", 2D) = "black"{}
        _RampTex("扫光叠加纹理", 2D) = "black"{}
        _SweepIntensity("扫光强度", Float) = 1
        _SweepRotator("扫光旋转角度", Float) = 0
    }
    SubShader
    {
        Tags{ "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline" = "UniversalPipeline"}
        LOD 500

        /*
        // Pass 0 - Marschner hair shading opaque pass
        // This pass should be added to render feature, after rendering opaque
        Pass
        {
            Name "HairShadingMarschnerOpaque"
            Tags{ "LightMode" = "HairShadingMarschnerOpaque" }

            Cull Off
            ZTest LEqual
            ZWrite On

            HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                // Material Keywords
                #pragma shader_feature_local _FLOWDIRECTION_V _FLOWDIRECTION_DIRECTIONMAP _FLOWDIRECTION_U
                #pragma shader_feature_local _VIS_OFF _VIS_COLOR _VIS_ID _VIS_ROOT _VIS_OCCLUSION _VIS_ALPHA _VIS_FLOW
                #pragma shader_feature_local _LIGHTPATH_ALL _LIGHTPATH_R _LIGHTPATH_TT _LIGHTPATH_TRT _LIGHTPATH_SCATTER _LIGHTPATH_SHADOW
                #pragma shader_feature_local _LIGHTCOMPONENT_ALL _LIGHTCOMPONENT_DIRECT _LIGHTCOMPONENT_INDIRECT
                #pragma shader_feature_local _GRADIENTMODE_ROOT _GRADIENTMODE_UV3

                // Lightweight Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
                #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
                #pragma multi_compile _ _SHADOWS_SOFT
                #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
                #pragma multi_compile _HAIRUV_UV1 _HAIRUV_UV2

                // Unity defined keywords
                #pragma multi_compile_fog

                #define OPAQUE_PASS
                #include "HairPassShading.cginc"

            ENDHLSL
        }
        */

        // Pass 0 - Marschner hair shading pre depth pass
        // This pass should be added to render feature, after rendering opaque
        Pass
        {
            Name "HairShadingMarschnerPreDepth"
            Tags{ "LightMode" = "HairShadingMarschnerPreDepth" }

            Cull Off
            ZTest LEqual
            ZWrite On
            ColorMask 0

            HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                #include "HairVariables.cginc"

                struct appdata
                {
                    float4 vertex : POSITION;
                    float2 uv : TEXCOORD0;
                };

                struct v2f
                {
                    float4 pos : SV_POSITION;
                    float2 uv : TEXCOORD0;
                };

                v2f vert (appdata v)
                {
                    v2f o = (v2f)0;
                    VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);

                    o.pos = vertexInput.positionCS;
                    o.uv = v.uv;

                    return o;
                }

                float4 frag (v2f i) : SV_Target
                {   
                    // sample textures
                    float4 mainMap = tex2D(_MainMap, i.uv);

                    // calculate params for shading model
                    float alpha = mainMap.a;

                    // alpha test
                    clip(alpha - _AlphaCutoff);
                    
                    return 0.0;
                }

            ENDHLSL
        }

        // Pass 1 - Marschner hair shading transparent pass
        // This pass is called by urp to join transparent sorting
        Pass
        {
            Name "HairShadingMarschnerTransparent"
            Tags{ "LightMode" = "UniversalForward" }

            Cull Off
            ZTest LEqual
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // Material Keywords
                #pragma shader_feature_local _FLOWDIRECTION_V _FLOWDIRECTION_DIRECTIONMAP _FLOWDIRECTION_U
                #pragma shader_feature_local _VIS_OFF _VIS_COLOR _VIS_ID _VIS_ROOT _VIS_OCCLUSION _VIS_ALPHA _VIS_FLOW
                #pragma shader_feature_local _LIGHTPATH_ALL _LIGHTPATH_R _LIGHTPATH_TT _LIGHTPATH_TRT _LIGHTPATH_SCATTER _LIGHTPATH_SHADOW
                #pragma shader_feature_local _LIGHTCOMPONENT_ALL _LIGHTCOMPONENT_DIRECT _LIGHTCOMPONENT_INDIRECT
                #pragma shader_feature_local _GRADIENTMODE_ROOT _GRADIENTMODE_UV3

                // Lightweight Pipeline keywords
                #pragma multi_compile _ _HAIR_SHADOWS
                #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
                #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
                #pragma multi_compile _ _SHADOWS_SOFT
                #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
                #pragma multi_compile _HAIRUV_UV1 _HAIRUV_UV2 _HAIRUV_UV3
            
                //---------------------------------------
                // Character Shadow Keywords
                #pragma shader_feature _ _IsSupCharacter

                #pragma multi_compile _ _GLOBAL_TRANSPARENTSHADOW
            
                // // Unity defined keywords
                #pragma multi_compile_fog
                #pragma multi_compile _ _HEIGHT_FOG_ON
                
                #pragma vertex vert
                #pragma fragment frag
                #include "HairVariables.cginc"
                #include "HairPassShading.cginc"
            ENDHLSL
        }

        // Pass 2 - shadow caster pass
        Pass
        {
            Name "ShadowCaster"
            Tags{ "LightMode" = "ShadowCaster" }

            Cull Off
            ZTest LEqual
            ZWrite On

            HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                
                // Hair Shadow Keywords
                #pragma multi_compile _HAIRSHADOW_SHADOWMAP _HAIRSHADOW_EXPFALLOFF _HAIRSHADOW_DEEPOPACITY
                #pragma multi_compile _ _HAIRSHADOW_SOFT
                #pragma multi_compile _ _RENDERING_HAIR_DEPTH

                #include "HairVariables.cginc"
                #include "HairShadow.cginc"            

                struct appdata
                {
                    float4 vertex : POSITION;
                    float3 normal : NORMAL;
                    float2 uv : TEXCOORD0;
                    float4 vertexColor : COLOR;
                };

                struct v2f
                {
                    float4 pos : SV_POSITION;
                    float2 uv : TEXCOORD0;
                    float4 vertexColor : TEXCOORD1;
                };

                v2f vert(appdata v)
                {
                    v2f o = (v2f)0;
                    o.uv = v.uv;

                    float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                    float3 normalWS = TransformObjectToWorldNormal(v.normal);
                    #ifdef _HAIRSHADOW_SHADOWMAP
                        float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
                    #else
                        float4 positionCS = TransformWorldToHClip(positionWS);
                    #endif

                    #if UNITY_REVERSED_Z
                        positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                    #else
                        positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                    #endif
                    o.vertexColor = v.vertexColor;

                    o.pos = positionCS;
                    return o;
                }

                float4 frag(v2f i) : SV_TARGET
                {
                    clip(i.vertexColor.a-0.5);

                    #if !defined(_RENDERING_HAIR_DEPTH) | defined(_HAIRSHADOW_SHADOWMAP)
                        float alpha = tex2D(_MainMap, i.uv).a;
                        clip(alpha - _AlphaCutoff);
                    #endif
                    return 0;
                }
            ENDHLSL
        }

        // Pass  - Character shadow caster pass
        Pass
        {
            Name "CharacterShadowCaster"
            Tags { "LightMode" = "CharacterShadowCaster" }

            Cull Off
            ZTest LEqual
            ZWrite On

            HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                
                // Hair Shadow Keywords
                #pragma multi_compile _HAIRSHADOW_SHADOWMAP _HAIRSHADOW_EXPFALLOFF _HAIRSHADOW_DEEPOPACITY
                #pragma multi_compile _ _HAIRSHADOW_SOFT
                #pragma multi_compile _ _RENDERING_HAIR_DEPTH

                #include "HairVariables.cginc"
                #include "HairShadow.cginc"

                struct appdata
                {
                    float4 vertex : POSITION;
                    float3 normal : NORMAL;
                    float2 uv : TEXCOORD0;
                    float4 vertexColor : COLOR;

                };

                struct v2f
                {
                    float4 pos : SV_POSITION;
                    float2 uv : TEXCOORD0;
                    float4 vertexColor : TEXCOORD1;
                };

                v2f vert(appdata v)
                {
                    v2f o = (v2f)0;
                    o.uv = v.uv;

                    float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                    float3 normalWS = TransformObjectToWorldNormal(v.normal);

                    #ifdef _HAIRSHADOW_SHADOWMAP
                        float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
                    #else
                        float4 positionCS = TransformWorldToHClip(positionWS);
                    #endif  
    
                    #if UNITY_REVERSED_Z
                        positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                    #else
                        positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                    #endif
                    o.vertexColor = v.vertexColor;

                    o.pos = positionCS;
                    return o;
                }

                float4 frag(v2f i) : SV_TARGET
                {
                    clip(i.vertexColor.a-0.5);
                    #if !defined(_RENDERING_HAIR_DEPTH) | defined(_HAIRSHADOW_SHADOWMAP)
                        float alpha = tex2D(_MainMap, i.uv).a;
                        clip(alpha - _AlphaCutoff);
                    #endif
                    return 0;
                }
            ENDHLSL
        }

        Pass
        {
            Name "PlanarShadowHair"
            Tags{"LightMode" = "PlanarShadowHair"}


            Stencil{
                Ref 0
                Comp equal
                Pass incrWrap
                Fail keep
                ZFail keep
            }
            Blend SrcAlpha OneMinusSrcAlpha
            ColorMask RGBA
            ZWrite Off
            Offset -1 , 0
            

            HLSLPROGRAM
                #pragma vertex PlanarShadowPassVertex
                #pragma fragment PlanarShadowPassFragment
                // Hair Shadow Keywords
                #pragma multi_compile _HAIRSHADOW_SHADOWMAP _HAIRSHADOW_EXPFALLOFF _HAIRSHADOW_DEEPOPACITY
                #pragma multi_compile _ _HAIRSHADOW_SOFT
            
                #include "HairVariables.cginc"
                #include "HairPassShading.cginc"
                #include "HairShadow.cginc"

                struct PlanarShadowPassAttributes
                {
                    float4 positionOS   : POSITION;
                };

                struct PlanarShadowPassVaryings
                {
                    float4 positionCS   : SV_POSITION;
                    float4 color   : COLOR;

                };

                PlanarShadowPassVaryings PlanarShadowPassVertex(PlanarShadowPassAttributes input)
                {
                    PlanarShadowPassVaryings output = (PlanarShadowPassVaryings) 0;
                    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                    float3 lightDir = normalize(_LightDirection);

                    float3 shadowPos;

                    shadowPos.y = min(positionWS.y,0);
                    shadowPos.xz = positionWS.xz - lightDir.xz * max(0, positionWS.y - 0) / lightDir.y;
                    output.positionCS = TransformWorldToHClip(shadowPos);

                    float4 color;
                    color.rgb = float3(0.1, 0.1, 0.1);
                    float3 center = float3(unity_ObjectToWorld[0].w, 0, unity_ObjectToWorld[2].w);

                    float falloff = 1.0 - saturate(distance(shadowPos, center) * 0.3);

                    color.a = falloff;
                    output.color = color;
                    return output;
                }

                float4 PlanarShadowPassFragment(PlanarShadowPassVaryings input) : SV_TARGET
                {
                    return input.color;
                }

            ENDHLSL
        }

        // Pass 3 - deep opacity pass
        Pass
        {
            Name "DeepOpacityPass"
            Tags{ "LightMode" = "DeepOpacity" }

            Cull Off
            ZTest Off
            ZWrite Off
            ColorMask RGBA
            Blend One One

            HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                #include "HairVariables.cginc"
                #include "HairShadow.cginc"

                struct appdata
                {
                    float4 vertex : POSITION;
                    float2 uv : TEXCOORD0;
                };

                struct v2f
                {
                    float4 pos : SV_POSITION;
                    float2 uv : TEXCOORD0;
                    float4 shadowCoord : TEXCOORD1;
                };

                v2f vert (appdata v)
                {
                    v2f o = (v2f)0;
                    o.uv = v.uv;

                    VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
                    o.pos = vertexInput.positionCS;
                    o.shadowCoord = mul(Hair_WorldToShadow, float4(vertexInput.positionWS, 1.0));

                    return o;
                }

                float4 frag (v2f i) : SV_Target
                {
                    float alpha = tex2D(_MainMap, i.uv).a;
                    // alpha = saturate((alpha - _AlphaCutoff) / (1.0001 - _AlphaCutoff));

                    i.shadowCoord.xyz /= i.shadowCoord.w;
                    float nearest = SAMPLE_TEXTURE2D(_HairDepthTexture, sampler_HairDepthTexture, i.shadowCoord.xy).r;
                    float depth = i.shadowCoord.z;

                    float nearest_linear = HairShadowLinearDepth(nearest);
                    float depth_linear = HairShadowLinearDepth(depth);
                    
                    float dist = DEPTH_SUBTRACT(depth_linear, nearest_linear);

                    float4 inLayer = float4(
                        step(dist, s_LayerBounds[1]),
                        step(dist, s_LayerBounds[2]) * step(s_LayerBounds[1], dist),
                        step(dist, s_LayerBounds[3]) * step(s_LayerBounds[2], dist),
                        step(dist, s_LayerBounds[4]) * step(s_LayerBounds[3], dist));
                    return inLayer * alpha / RANGE_SCALE;
                }
            ENDHLSL
        }

        // Pass 4 - depth only pass
        Pass
        {
            Name "DepthOnly"
            Tags{ "LightMode" = "DepthOnly" }

            Cull Off
            ZWrite On
            ColorMask 0

            HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                #include "HairVariables.cginc"
                
                struct appdata
                {
                    float4 vertex : POSITION;
                    float3 normal : NORMAL;
                    float2 uv : TEXCOORD0;
                };

                struct v2f
                {
                    float4 pos : SV_POSITION;
                    float2 uv : TEXCOORD0;
                };

                v2f vert(appdata v)
                {
                    v2f o = (v2f)0;
                    o.uv = v.uv;
                    o.pos = TransformObjectToHClip(v.vertex.xyz);
                    return o;
                }

                float4 frag(v2f i) : SV_TARGET
                {
                    float alpha = tex2D(_MainMap, i.uv).a;
                    clip(alpha - _AlphaCutoff);
                    return 0;
                }
            ENDHLSL
        }

        // Pass 5 - shadow opaque pass
        Pass
        {
            Name "ShadowPassOpaque"
            Tags{ "LightMode" = "HairShadowOpaque" }

            Cull Off
            ZTest LEqual
            ZWrite On

            HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                // Material Keywords
                #pragma shader_feature_local _FLOWDIRECTION_V _FLOWDIRECTION_DIRECTIONMAP _FLOWDIRECTION_U

                // Hair Shadow Keywords
                #pragma multi_compile _HAIRSHADOW_SHADOWMAP _HAIRSHADOW_EXPFALLOFF _HAIRSHADOW_DEEPOPACITY
                #pragma multi_compile _ _HAIRSHADOW_SOFT

                #define OPAQUE_PASS
                #include "HairPassShadow.cginc"
            ENDHLSL
        }

        // Pass 6 - shadow transparent pass
        Pass
        {
            Name "ShadowPassTransparent"
            Tags{ "LightMode" = "HairShadowOpaque" }

            Cull Off
            ZTest LEqual
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                // Material Keywords
                #pragma shader_feature_local _FLOWDIRECTION_V _FLOWDIRECTION_DIRECTIONMAP _FLOWDIRECTION_U

                // Hair Shadow Keywords
                #pragma multi_compile _HAIRSHADOW_SHADOWMAP _HAIRSHADOW_EXPFALLOFF _HAIRSHADOW_DEEPOPACITY
                #pragma multi_compile _ _HAIRSHADOW_SOFT

                #include "HairPassShadow.cginc"
            ENDHLSL
        }
        // Pass 7 - blur mask pass
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

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "HairVariables.cginc"

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

            Varyings vert(Attributes i)
            {
                Varyings o = (Varyings)0;
                o.uv = i.uv;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(i.positionOS.xyz);
                o.vertex = vertexInput.positionCS;

                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float alpha = tex2D(_MainMap, i.uv).a;
                clip(alpha - _AlphaCutoff);
                return half4(0, 0, 0, 0);
            }

            ENDHLSL
        }
    }
    SubShader
    {
        //低LOD，無shadow
        Tags{ "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline" = "UniversalPipeline"}
        LOD 300
        
        // Pass 0 - Marschner hair shading pre depth pass
        // This pass should be added to render feature, after rendering opaque
        Pass
        {
            Name "HairShadingMarschnerPreDepth"
            Tags{ "LightMode" = "HairShadingMarschnerPreDepth" }

            Cull Off
            ZTest LEqual
            ZWrite On
            ColorMask 0

            HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                #include "HairVariables.cginc"

                struct appdata
                {
                    float4 vertex : POSITION;
                    float2 uv : TEXCOORD0;
                };

                struct v2f
                {
                    float4 pos : SV_POSITION;
                    float2 uv : TEXCOORD0;
                };

                v2f vert (appdata v)
                {
                    v2f o = (v2f)0;
                    VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);

                    o.pos = vertexInput.positionCS;
                    o.uv = v.uv;

                    return o;
                }

                float4 frag (v2f i) : SV_Target
                {   
                    // sample textures
                    float4 mainMap = tex2D(_MainMap, i.uv);

                    // calculate params for shading model
                    float alpha = mainMap.a;

                    // alpha test
                    clip(alpha - _AlphaCutoff);
                    
                    return 0.0;
                }

            ENDHLSL
        }

        // Pass 1 - Marschner hair shading transparent pass
        // This pass is called by urp to join transparent sorting
        Pass
        {
            Name "HairShadingMarschnerTransparent"
            Tags{ "LightMode" = "UniversalForward" }

            Cull Off
            ZTest LEqual
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                // Material Keywords
                #pragma shader_feature_local _LIGHTPATH_ALL _LIGHTPATH_R _LIGHTPATH_TT _LIGHTPATH_TRT _LIGHTPATH_SCATTER _LIGHTPATH_SHADOW
                #pragma shader_feature_local _LIGHTCOMPONENT_ALL _LIGHTCOMPONENT_DIRECT _LIGHTCOMPONENT_INDIRECT
	#pragma shader_feature_local _GRADIENTMODE_ROOT _GRADIENTMODE_UV3

                #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
                #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
                #pragma multi_compile _HAIRUV_UV1 _HAIRUV_UV2 _HAIRUV_UV3
            
                #pragma vertex vert
                #pragma fragment lowFrag
            
                #include "HairVariables.cginc"
                #include "HairPassShading.cginc"
            ENDHLSL
        }

        // Pass 3 - deep opacity pass
        Pass
        {
            Name "DeepOpacityPass"
            Tags{ "LightMode" = "DeepOpacity" }

            Cull Off
            ZTest Off
            ZWrite Off
            ColorMask RGBA
            Blend One One

            HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                #include "HairVariables.cginc"
                #include "HairShadow.cginc"

                struct appdata
                {
                    float4 vertex : POSITION;
                    float2 uv : TEXCOORD0;
                };

                struct v2f
                {
                    float4 pos : SV_POSITION;
                    float2 uv : TEXCOORD0;
                    float4 shadowCoord : TEXCOORD1;
                };

                v2f vert (appdata v)
                {
                    v2f o = (v2f)0;
                    o.uv = v.uv;

                    VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
                    o.pos = vertexInput.positionCS;
                    o.shadowCoord = mul(Hair_WorldToShadow, float4(vertexInput.positionWS, 1.0));

                    return o;
                }

                float4 frag (v2f i) : SV_Target
                {
                    float alpha = tex2D(_MainMap, i.uv).a;
                    // alpha = saturate((alpha - _AlphaCutoff) / (1.0001 - _AlphaCutoff));

                    i.shadowCoord.xyz /= i.shadowCoord.w;
                    float nearest = SAMPLE_TEXTURE2D(_HairDepthTexture, sampler_HairDepthTexture, i.shadowCoord.xy).r;
                    float depth = i.shadowCoord.z;

                    float nearest_linear = HairShadowLinearDepth(nearest);
                    float depth_linear = HairShadowLinearDepth(depth);
                    
                    float dist = DEPTH_SUBTRACT(depth_linear, nearest_linear);

                    float4 inLayer = float4(
                        step(dist, s_LayerBounds[1]),
                        step(dist, s_LayerBounds[2]) * step(s_LayerBounds[1], dist),
                        step(dist, s_LayerBounds[3]) * step(s_LayerBounds[2], dist),
                        step(dist, s_LayerBounds[4]) * step(s_LayerBounds[3], dist));
                    return inLayer * alpha / RANGE_SCALE;
                }
            ENDHLSL
        }

        // Pass 4 - depth only pass
        Pass
        {
            Name "DepthOnly"
            Tags{ "LightMode" = "DepthOnly" }

            Cull Off
            ZWrite On
            ColorMask 0

            HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                #include "HairVariables.cginc"
                
                struct appdata
                {
                    float4 vertex : POSITION;
                    float3 normal : NORMAL;
                    float2 uv : TEXCOORD0;
                };

                struct v2f
                {
                    float4 pos : SV_POSITION;
                    float2 uv : TEXCOORD0;
                };

                v2f vert(appdata v)
                {
                    v2f o = (v2f)0;
                    o.uv = v.uv;
                    o.pos = TransformObjectToHClip(v.vertex.xyz);
                    return o;
                }

                float4 frag(v2f i) : SV_TARGET
                {
                    float alpha = tex2D(_MainMap, i.uv).a;
                    clip(alpha - _AlphaCutoff);
                    return 0;
                }
            ENDHLSL
        }


        // Pass 7 - blur mask pass
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

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "HairVariables.cginc"

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

            Varyings vert(Attributes i)
            {
                Varyings o = (Varyings)0;
                o.uv = i.uv;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(i.positionOS.xyz);
                o.vertex = vertexInput.positionCS;

                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float alpha = tex2D(_MainMap, i.uv).a;
                clip(alpha - _AlphaCutoff);
                return half4(0, 0, 0, 0);
            }

            ENDHLSL
        }
    }

    CustomEditor "HairMarschnerEditor"
    // CustomEditor "JTRP.ShaderDrawer.LWGUI"
}
