#ifndef HAIRSHADING_MARSCHNER
#define HAIRSHADING_MARSCHNER

#include "HairVariables.cginc"

inline float square(float x)
{
    return x * x;
}

float acosFast(float inX) 
{
    float x = abs(inX);
    float res = -0.156583f * x + (0.5 * _PI);
    res *= sqrt(1.0f - x);
    return (inX >= 0) ? res : _PI - res;
}

float asinFast( float x )
{
    return (0.5 * _PI) - acosFast(x);
}

float3 HueShift(float3 src, float percent)
{
    float3 axis = float3(0.57735, 0.57735, 0.57735);// normalize(float3(1,1,1))
    float theta = percent * 2 * _PI;
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);
    return src * cosTheta + cross(axis, src) * sinTheta + axis * dot(axis, src) * (1 - cosTheta);// Rodrigues' rotation formula
}

float Hair_g(float B, float Theta)
{
    return exp(-0.5 * square(Theta) / (B * B)) / (sqrt(2 * _PI) * B);
}

float Pow_5(float x)
{
    return x*x*x*x*x;
}

float Hair_Luminance(float3 rgb)
{
    return dot(rgb, float3(0.333, 0.333, 0.333));
    #ifdef UNITY_COLORSPACE_GAMMA
        return dot(rgb, float3(0.22, 0.707, 0.071));
    #else
        return dot(rgb, float3(0.0396819152, 0.458021790, 0.00609653955));
    #endif
}

float Hair_F(float CosTheta)
{
    const float n = 1.55;
    const float F0 = square((1 - n) / (1 + n));
    return F0 + (1 - F0) * Pow_5(1 - CosTheta);
}

float3 ScatterTerm_Unreal(float3 albedo, float roughness, float scatter,
    float3 L, float3 V, float3 T,
    float Shadow, float Backlit, float Area)
{
    // Use soft Kajiya Kay diffuse attenuation
    float KajiyaDiffuse = 1 - abs(dot(T, L));

    float3 FakeNormal = normalize(V - T * dot(V, T));

    // Hack approximation for multiple scattering.
    float Wrap = 1;
    float NoL = saturate((dot(FakeNormal, L) + Wrap) / square(1 + Wrap));
    float DiffuseScatter = (1 / _PI) * scatter * (lerp(NoL, KajiyaDiffuse, 0.33) * 0.7 + 0.3); // wrap to(0.3, 1.0)
    float Luma = Hair_Luminance(albedo);
    float3 ScatterTint = pow(abs(albedo / Luma), 1 - Shadow);
    return sqrt(albedo) * DiffuseScatter * ScatterTint;
}

float3 ScatterTerm_Simple(float3 albedo, float roughness, float scatter,
    float3 L, float3 V, float3 T,
    float Shadow, float Backlit, float Area)
{
    float KajiyaDiffuse = 1 - abs(dot(T, L));

    float3 FakeNormal = normalize(V - T * dot(V, T));

    float Wrap = 1;
    float NoL = saturate((dot(FakeNormal, L) + Wrap) / square(1 + Wrap));
    return albedo * (lerp(NoL, KajiyaDiffuse, 0.33) * 0.7 + 0.3) * scatter;
}

float3 HairShading(float3 albedo, float roughness, float4 lighting_params,
    float3 L, float3 V, float3 T,
    float Shadow, float Backlit, float Area)
{
    float scatter_intensity = lighting_params.x;
    float R_intensity = lighting_params.y;
    float TRT_intensity = lighting_params.z;
    float TT_intensity = lighting_params.w;
    
    const float VoL       = dot(V,L);                                                      
    const float SinThetaL = clamp(dot(T,L), -1.f, 1.f);
    const float SinThetaV = clamp(dot(T,V), -1.f, 1.f);
    float CosThetaD = cos( 0.5 * abs( asinFast( SinThetaV ) - asinFast( SinThetaL ) ) );

    const float3 Lp = L - SinThetaL * T;
    const float3 Vp = V - SinThetaV * T;
    const float CosPhi = dot(Lp,Vp) * rsqrt( dot(Lp,Lp) * dot(Vp,Vp) + 1e-4 );
    const float CosHalfPhi = sqrt( saturate( 0.5 + 0.5 * CosPhi ) );

    float n_prime = 1.19 / CosThetaD + 0.36 * CosThetaD;

    float Shift = 0.035;
    float Alpha[3] =
    {
        -Shift * 2,
        Shift,
        Shift * 4,
    };  
    float B[3] =
    {
        Area + roughness,
        Area + roughness / 2,
        Area + roughness * 2,
    };

    float3 S = 0;
    float Mp, Np, Fp, a, h, f;
    float3 Tp;

    // R
    const float sa = sin(Alpha[0]);
    const float ca = cos(Alpha[0]);
    float RShift = 2 * sa * (ca * CosHalfPhi * sqrt(1 - SinThetaV * SinThetaV) + sa * SinThetaV);
    float BScale = sqrt(2.0) * CosHalfPhi;
    Mp = Hair_g(B[0] * BScale, SinThetaL + SinThetaV - RShift);
    Np = 0.25 * CosHalfPhi;
    Fp = Hair_F(sqrt(saturate(0.5 + 0.5 * VoL)));
    #if defined(_LIGHTPATH_ALL) | defined(_LIGHTPATH_R)
        S += Mp * Np * Fp /** (GBuffer.Specular * 2)*/ * lerp(1, Backlit, saturate(-VoL)) * 2 * R_intensity;
    #endif

    // TT
    Mp = Hair_g( B[1], SinThetaL + SinThetaV - Alpha[1] );
    a = 1 / n_prime;
    h = CosHalfPhi * ( 1 + a * ( 0.6 - 0.8 * CosPhi ) );
    f = Hair_F( CosThetaD * sqrt( saturate( 1 - h*h ) ) );
    Fp = square(1 - f);
    Tp = pow(abs(albedo), 0.5 * sqrt(1 - square(h * a)) / CosThetaD);
    Np = exp( -3.65 * CosPhi - 3.98 );
    #if defined(_LIGHTPATH_ALL) | defined(_LIGHTPATH_TT)
        S += Mp * Np * Fp * Tp * Backlit * TT_intensity;
    #endif

    // TRT
    Mp = Hair_g( B[2], SinThetaL + SinThetaV - Alpha[2] );
    f = Hair_F( CosThetaD * 0.5 );
    Fp = square(1 - f) * f;
    Tp = pow(abs(albedo), 0.8 / CosThetaD );
    Np = exp( 17 * CosPhi - 16.78 );
    #if defined(_LIGHTPATH_ALL) | defined(_LIGHTPATH_TRT)
        S += Mp * Np * Fp * Tp * TRT_intensity;
    #endif

    // multi scatter
    #if defined(_LIGHTPATH_ALL) | defined(_LIGHTPATH_SCATTER)
        S += ScatterTerm_Simple(albedo, roughness, scatter_intensity, L, V, T, Shadow, Backlit, Area);
    #endif

    S = -min(-S, 0.0);
    return S;
}

float3 HairShadingSimple(float3 albedo, float roughness, float4 lighting_params,
    float3 L, float3 V, float3 T,
    float Shadow, float Backlit, float Area)
{
    float scatter_intensity = lighting_params.x;
    float R_intensity = lighting_params.y;
    float TRT_intensity = lighting_params.z;
    float TT_intensity = lighting_params.w;
    
    const float VoL       = dot(V,L);                                                      
    const float SinThetaL = clamp(dot(T,L), -1.f, 1.f);
    const float SinThetaV = clamp(dot(T,V), -1.f, 1.f);
    float CosThetaD = cos( 0.5 * abs( asinFast( SinThetaV ) - asinFast( SinThetaL ) ) );

    const float3 Lp = L - SinThetaL * T;
    const float3 Vp = V - SinThetaV * T;
    const float CosPhi = dot(Lp,Vp) * rsqrt( dot(Lp,Lp) * dot(Vp,Vp) + 1e-4 );
    const float CosHalfPhi = sqrt( saturate( 0.5 + 0.5 * CosPhi ) );

    float n_prime = 1.19 / CosThetaD + 0.36 * CosThetaD;

    float Shift = 0.035;
    float Alpha[3] =
    {
        -Shift * 2,
        Shift,
        Shift * 4,
    };  
    float B[3] =
    {
        Area + roughness,
        Area + roughness / 2,
        Area + roughness * 2,
    };

    float3 S = 0;
    float Mp, Np, Fp, a, h, f;
    float3 Tp;

    // R
    const float sa = sin(Alpha[0]);
    const float ca = cos(Alpha[0]);
    float RShift = 2 * sa * (ca * CosHalfPhi * sqrt(1 - SinThetaV * SinThetaV) + sa * SinThetaV);
    float BScale = sqrt(2.0) * CosHalfPhi;
    Mp = Hair_g(B[0] * BScale, SinThetaL + SinThetaV - RShift);
    Np = 0.25 * CosHalfPhi;
    Fp = Hair_F(sqrt(saturate(0.5 + 0.5 * VoL)));
    #if defined(_LIGHTPATH_ALL) | defined(_LIGHTPATH_R)
        S += Mp * Np * Fp /** (GBuffer.Specular * 2)*/ * lerp(1, Backlit, saturate(-VoL)) * 2 * R_intensity;
    #endif

    // // TT
    // Mp = Hair_g( B[1], SinThetaL + SinThetaV - Alpha[1] );
    // a = 1 / n_prime;
    // h = CosHalfPhi * ( 1 + a * ( 0.6 - 0.8 * CosPhi ) );
    // f = Hair_F( CosThetaD * sqrt( saturate( 1 - h*h ) ) );
    // Fp = square(1 - f);
    // Tp = pow(abs(albedo), 0.5 * sqrt(1 - square(h * a)) / CosThetaD);
    // Np = exp( -3.65 * CosPhi - 3.98 );
    // #if defined(_LIGHTPATH_ALL) | defined(_LIGHTPATH_TT)
    //     S += Mp * Np * Fp * Tp * Backlit * TT_intensity;
    // #endif

    // // TRT
    // Mp = Hair_g( B[2], SinThetaL + SinThetaV - Alpha[2] );
    // f = Hair_F( CosThetaD * 0.5 );
    // Fp = square(1 - f) * f;
    // Tp = pow(abs(albedo), 0.8 / CosThetaD );
    // Np = exp( 17 * CosPhi - 16.78 );
    // #if defined(_LIGHTPATH_ALL) | defined(_LIGHTPATH_TRT)
    //     S += Mp * Np * Fp * Tp * TRT_intensity;
    // #endif

    // multi scatter
    #if defined(_LIGHTPATH_ALL) | defined(_LIGHTPATH_SCATTER)
        S += ScatterTerm_Simple(albedo, roughness, scatter_intensity, L, V, T, Shadow, Backlit, Area);
    #endif

    S = -min(-S, 0.0);
    return S;
}

#endif