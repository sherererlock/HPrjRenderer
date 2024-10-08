﻿Shader "Hair/Gaussian Blur Flow"
{
	Properties
	{
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_BlurSize ("Blur Size", Float) = 1.0
	}
	SubShader
	{
		ZTest Off
		Cull Off
		ZWrite Off

		Pass
		{
			NAME "GAUSSIAN_BLUR_FLOW"

			CGPROGRAM
				#pragma vertex vertBlurFlow
				#pragma fragment fragBlurFlow

				#pragma enable_d3d11_debug_symbols
			
				#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
			
				sampler2D _BlitTexture;  
				half4 _BlitTexture_TexelSize;
				float _BlurSize;

				struct appdata
				{
				    float4 vertex : POSITION;
				    float2 uv : TEXCOORD0;
					uint vertexID : SV_VertexID;
				};

				struct v2f {
					float4 pos : SV_POSITION;
					float2 uv : TEXCOORD0;
				};

				v2f vertBlurFlow(appdata v)
				{
					v2f o = (v2f)0;

					#if SHADER_API_GLES
					    float4 pos = input.positionOS;
					    float2 uv  = input.uv;
					#else
					    float4 pos = GetFullScreenTriangleVertexPosition(v.vertexID);
					    float2 uv  = GetFullScreenTriangleTexCoord(v.vertexID);
					#endif
						o.pos = pos;
						o.uv = uv;
					
					return o;
				}
			
				fixed4 fragBlurFlow(v2f i) : SV_Target
				{
					float weight[3] = {0.4026, 0.2442, 0.0545};
					
					float4 sample0 = tex2D(_BlitTexture, i.uv);
					float2 flow = sample0.gb * 2 - 1;

					float4 sample1 = tex2D(_BlitTexture, i.uv + _BlitTexture_TexelSize.xy * flow * 1.0 * _BlurSize);
					float4 sample2 = tex2D(_BlitTexture, i.uv - _BlitTexture_TexelSize.xy * flow * 1.0 * _BlurSize);
					float4 sample3 = tex2D(_BlitTexture, i.uv + _BlitTexture_TexelSize.xy * flow * 2.0 * _BlurSize);
					float4 sample4 = tex2D(_BlitTexture, i.uv - _BlitTexture_TexelSize.xy * flow * 2.0 * _BlurSize);

					float4 sum = sample0 * weight[0] + (sample1 + sample2) * weight[1] + (sample3 + sample4) * weight[2];
					return sum;
				}
			ENDCG

		}
	}
}
