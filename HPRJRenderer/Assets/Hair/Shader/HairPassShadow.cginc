#ifndef HAIRSHADOWPASS_MARSCHNER
#define HAIRSHADOWPASS_MARSCHNER

#include "HairVariables.cginc"
#include "HairShadow.cginc"

struct appdata
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0;
};

struct v2f
{
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;

    // tangent to world matrix, world pos stored in w
    float4 TtoW0 : TEXCOORD1;
    float4 TtoW1 : TEXCOORD2;
    float4 TtoW2 : TEXCOORD3;
};

v2f vert (appdata v)
{
    v2f o = (v2f)0;
    VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(v.normal, v.tangent);
    o.pos = vertexInput.positionCS;

    o.uv = v.uv;

    // Compute the matrix that transform directions from tangent space to world space
    // Put world space position in w component for optimization
    o.TtoW0 = float4(normalInput.tangentWS.x, normalInput.bitangentWS.x, normalInput.normalWS.x, vertexInput.positionWS.x);
    o.TtoW1 = float4(normalInput.tangentWS.y, normalInput.bitangentWS.y, normalInput.normalWS.y, vertexInput.positionWS.y);
    o.TtoW2 = float4(normalInput.tangentWS.z, normalInput.bitangentWS.z, normalInput.normalWS.z, vertexInput.positionWS.z);

    return o;
}

float4 frag (v2f i) : SV_Target
{
    float4 mainMap = tex2D(_MainMap, i.uv);

    float alpha = mainMap.a;
    float id = mainMap.r;

    float3 flow = FlowDir(i.uv);// tangent space flow dir
    // flow = normalize(flow + float3(0, 0, (id - 0.5) * _FlowVariation));

    float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
    float3 worldNormal = normalize(float3(i.TtoW0.z, i.TtoW1.z, i.TtoW2.z));
    float3 worldFlow = normalize(half3(dot(i.TtoW0.xyz, flow), dot(i.TtoW1.xyz, flow), dot(i.TtoW2.xyz, flow)));
    float3 viewFlow = mul((float3x3)UNITY_MATRIX_V, worldFlow);

    // do alpha clip
    #ifdef OPAQUE_PASS
        clip(alpha - _AlphaCutoff);
    #else
        clip(_AlphaCutoff - alpha);
        alpha /= _AlphaCutoff;
    #endif

    float4 shadowCoord = mul(Hair_WorldToShadow, float4(worldPos, 1.0));
    float atten = CalculateHairShadow(shadowCoord);

    float4 col;
    col.gb = viewFlow.rg * 0.5 + 0.5;
    col.r = atten;
    col.a = alpha;

    #if defined(_EFFECT_ON)
        half dissolved = step(_DissolveDirection, i.TtoW1.w + (_DissolveReverse ? _DissolveCutWidth : _DissolveCutWidth * -1));
        dissolved = _DissolveReverse ? (1 - dissolved) : dissolved;
        clip((_EffectType == 1 && dissolved) ? -1: 1);
    #endif

    return col;
}

#endif