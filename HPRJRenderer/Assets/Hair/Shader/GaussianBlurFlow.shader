Shader "Hair/Gaussian Blur Flow"
{
	Properties
	{
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_BlurSize ("Blur Size", Float) = 1.0
	}
	SubShader
	{
		ZTest Always
		Cull Off
		ZWrite Off

		Pass
		{
			NAME "GAUSSIAN_BLUR_FLOW"

			CGPROGRAM
				#pragma vertex vertBlurFlow
				#pragma fragment fragBlurFlow

				#include "UnityCG.cginc"

				sampler2D _MainTex;  
				half4 _MainTex_TexelSize;
				float _BlurSize;

				struct appdata
				{
				    float4 vertex : POSITION;
				    float2 uv : TEXCOORD0;
				};

				struct v2f {
					float4 pos : SV_POSITION;
					float2 uv : TEXCOORD0;
				};

				v2f vertBlurFlow(appdata v)
				{
					v2f o = (v2f)0;
    				o.pos = UnityObjectToClipPos(v.vertex);
					o.uv = v.uv;
					return o;
				}

				fixed4 fragBlurFlow(v2f i) : SV_Target
				{
					float weight[3] = {0.4026, 0.2442, 0.0545};
					
					float4 sample0 = tex2D(_MainTex, i.uv);
					float2 flow = sample0.gb * 2 - 1;

					float4 sample1 = tex2D(_MainTex, i.uv + _MainTex_TexelSize.xy * flow * 1.0 * _BlurSize);
					float4 sample2 = tex2D(_MainTex, i.uv - _MainTex_TexelSize.xy * flow * 1.0 * _BlurSize);
					float4 sample3 = tex2D(_MainTex, i.uv + _MainTex_TexelSize.xy * flow * 2.0 * _BlurSize);
					float4 sample4 = tex2D(_MainTex, i.uv - _MainTex_TexelSize.xy * flow * 2.0 * _BlurSize);

					float4 sum = sample0 * weight[0] + (sample1 + sample2) * weight[1] + (sample3 + sample4) * weight[2];
					return sum;
				}
			ENDCG

		}
	}
}
