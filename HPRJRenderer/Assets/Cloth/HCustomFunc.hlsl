half3 UnpackNormalRG(half2 packedNormal)
{
    float3 normal;
    normal.xy = packedNormal * 2 - 1; 
    normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));
    return normal;
}

//uv映射，如果uv没有值默认是0的话就是uv1
float2 RedirectUV(float2 uv0, float2 uv1, float2 uv2, float2 uv3, int inputUV)
{
    return uv0 * step(inputUV, 0) * step(0, inputUV) + uv1 * step(inputUV, 1) * step(1, inputUV) 
    + uv2 * step(inputUV, 2) * step(2, inputUV) + uv3 * step(inputUV, 3) * step(3, inputUV);
}
//根据种子seed获取一个0到1之间的随机数half2
inline float2 GetRandomFloat2Between01(float2 seed)
{
    float3 value = frac(float3(seed.xyx) * float3(0.1031, 0.1030, 0.0973));
    value += dot(value, value.yzx + 33.33);
    return frac((value.xx + value.yz) * value.zy);
    //return saturate(frac(sin(dot(seed, half2(0.988, 0.233)))));
    //return frac(sin(dot(seed, half2(12.9898, 78.233))) * half2(43758.5453, 23564.2787));
}

struct SurfaceSharedData
{
    half detailWeight;
    half patternWeight;
    half3 detailDiffuse;
    half3 patternDiffuse;
    float3 patternNormal;
};

// 沿(0.5, 0.5)旋转uv，rotateAngle为角度制
half2 RotateUv(half2 uv, half rotateAngle)
{
    half radAngle = rotateAngle * UNITY_PI_DIV_180;
    uv -= 0.5;
    half2 res = half2(uv.x * cos(radAngle) - uv.y * sin(radAngle), uv.x * sin(radAngle) + uv.y * cos(radAngle));
    res += 0.5;
    return res;
}

//获取必要的表面混合数据
SurfaceSharedData GetSurfaceBlendData(half2 uv2, half2 uv3)
{
	SurfaceSharedData surfaceSharedData = (SurfaceSharedData) 0;

    half4 tex2DValue;
    #if defined(_DETAIL_ON)
        tex2DValue = _DetailDiffuseMap.Sample(sampler_DetailDiffuseMap, uv2 * _DetailDiffuseTiling);
        surfaceSharedData.detailDiffuse = tex2DValue.rgb;
        surfaceSharedData.detailWeight = tex2DValue.a;
    #endif
    #if defined(_PATTERN_ON)
        half2 uv3Tiling = RotateUv((uv3 + half2(_PatternOffsetX,_PatternOffsetY)), _PatternRotateAngle) * _PatternTiling;
        tex2DValue = _PatternDiffuseMap.Sample(sampler_PatternDiffuseMap, uv3Tiling);
        surfaceSharedData.patternDiffuse = tex2DValue.rgb * _PatternColorTint.rgb;
        surfaceSharedData.patternWeight = tex2DValue.a;
        surfaceSharedData.patternNormal = tex2D(_PatternNormalMap, uv3Tiling).rgb;
    #endif

    return surfaceSharedData;
}

//混合多层法线
float3 NormalInTangentSpace(SurfaceSharedData surfaceSharedData, float2 uv0, float2 uv2, float2 uv3)
{
    // 法线叠加顺序 1u 4u 3u 3u的法线权重要从4u剩下的里面分，一般刺绣什么的都是4u的
    float3 normalTangent = UnpackNormal(tex2D(_NormalMap, uv0)); // 1u
 
    half weight = 0;
    #if defined(_PATTERN_ON)
    float3 patternNormalTangent = UnpackNormalRG(surfaceSharedData.patternNormal.rg);
    weight = _PatternNormalWeight * surfaceSharedData.patternWeight;
    normalTangent = lerp(
        normalTangent,
        BlendNormalRNM(normalTangent, patternNormalTangent),
        weight);
    #endif

    #if defined(_DETAIL_ON)
    float3 detailNormalTangent = UnpackNormal(tex2D(_DetailNormalMap, (uv2 * _DetailNormalTiling)));
    half normalWeight = (1 - weight) * _DetailNormalScale * surfaceSharedData.detailWeight;
    normalTangent = lerp(
        normalTangent,
        BlendNormalRNM(normalTangent, detailNormalTangent),
        normalWeight);
    #endif

    return normalTangent;
}

float3 NormalInTangentSpace_LOD(SurfaceSharedData surfaceSharedData, float2 uv0, float2 uv2, float2 uv3, float depth)
{
    // 法线叠加顺序 1u 4u 3u 3u的法线权重要从4u剩下的里面分，一般刺绣什么的都是4u的
    float3 normalTangent = UnpackNormal(tex2D(_NormalMap, uv0)); // 1u
 
    half weight = 0;
    #if defined(_PATTERN_ON)
    float3 patternNormalTangent = UnpackNormalRG(surfaceSharedData.patternNormal.rg);
    half patternLodValue = clamp(1 - pow(depth, 16), 0.8, 1);
    patternNormalTangent = lerp(patternNormalTangent, float3(0, 0, 1), patternLodValue);
    weight = _PatternNormalWeight * surfaceSharedData.patternWeight;
    normalTangent = lerp(
        normalTangent,
        BlendNormalRNM(normalTangent, patternNormalTangent),
        weight);
    #endif

    #if defined(_DETAIL_ON)
    float3 detailNormalTangent = UnpackNormal(tex2D(_DetailNormalMap, (uv2 * _DetailNormalTiling)));
    half normalWeight = (1 - weight) * _DetailNormalScale * surfaceSharedData.detailWeight;
    normalTangent = lerp(
        normalTangent,
        BlendNormalRNM(normalTangent, detailNormalTangent),
        normalWeight);
    #endif

    return normalTangent;
}

//混合Albedo或Diffuse以及alpha
half3 BlendAlbedoOrDiffuseAndAlpha(SurfaceSharedData surfaceSharedData, half2 uv0, half2 uv2, half2 uv3, out half alpha)
{
    half detailWeight = surfaceSharedData.detailWeight;
    half patternWeight = surfaceSharedData.patternWeight;
    // color 叠加顺序 2u 3u 4u 1u
    alpha = 1;
    half4 mainAlbedo = _MainTex.Sample(sampler_MainTex, uv0); //1u 正片叠底
    half3 outputAlbedo = half3(1, 1, 1); //为了节省采样器，原底色属性AledeboMap用的uv1已经删除。
    #if defined(_DETAIL_ON) //uv3
        half3 detailDiffuse = surfaceSharedData.detailDiffuse;
        //_DetailBlend：0 透明叠加 1 正片叠底
        outputAlbedo = step(1, _DetailBlend) * (outputAlbedo * detailDiffuse * detailWeight) + (1 - step(1, _DetailBlend)) 
        * (outputAlbedo * (1 - detailWeight) + detailDiffuse * detailWeight);
        alpha *= 1 + step(1, _DetailBlend) * (detailWeight - 1); //正片叠底才会乘透明度
    #endif

    outputAlbedo *= lerp(mainAlbedo.rgb, mainAlbedo.rgb * _ColorTint.rgb, _MainColorWeight);
    alpha *= mainAlbedo.a * _ColorTint.a;//主体与布料透明 正片叠底

    #if defined(_PATTERN_ON) //uv4 透明叠加
        half3 patternDiffuse = surfaceSharedData.patternDiffuse;
        outputAlbedo = outputAlbedo * (1 - patternWeight) + patternDiffuse * patternWeight;
        alpha *= surfaceSharedData.patternNormal.b; //花纹法线b通道剔除。
        half isPatternAdd = step(1,_PatternBlend);
        outputAlbedo = (1 - isPatternAdd) * outputAlbedo + isPatternAdd * outputAlbedo * mainAlbedo.rgb * _ColorTint.rgb;
        alpha = (1 - isPatternAdd) * alpha + isPatternAdd * alpha * mainAlbedo.a * _ColorTint.a;
    #endif
    
    return outputAlbedo;
}

//混合粗糙度/AO/金属度（如果有的话）, 返回值为metallic
half BlendDetail(SurfaceSharedData surfaceSharedData, half2 uv0, half2 uv2, half2 uv3, out half perceptualRoughness, out half occlusion)
{
    // detail 叠加顺序 3u&4u分权重 1u正片叠底
    //采用roughness叠加，最后再进行整体处理,输入均为perceptualRoughness
    half metallic = 1;
    occlusion = 1;

    half roughness = 1; 

    half detailWeight = surfaceSharedData.detailWeight;
    half patternWeight = surfaceSharedData.patternWeight;

    #if defined(_DETAIL_ON) //uv3
        half4 clothDetail = _DetailDetailMap.Sample(sampler_DetailDiffuseMap, uv2 * _DetailDiffuseTiling);
        //detailWeight 纹理层颜色的alpha值
        roughness = saturate(roughness * (1 - detailWeight) + clothDetail.r * _DetailRoughnessScale * detailWeight);
        metallic = metallic * (1 - detailWeight) + clothDetail.b * _DetailMetallicScale * detailWeight;
        occlusion = occlusion * (1 - detailWeight) +  saturate(lerp(1.0, clothDetail.g, _DetailOcclusionScale)) * detailWeight; 
    #endif

    half3 detail = _DetailMap.Sample(sampler_MainTex, uv0).rgb; //1u 正片叠底
    roughness = roughness * (detail.r * _RoughnessScale);
    metallic = metallic * (detail.b * _MetallicScale);
    metallic = saturate(metallic);   
    occlusion = occlusion * lerp(1.0, detail.g, _OcclusionScale);

    #if defined(_PATTERN_ON) //uv4 透明叠加*分权重
        //patternWeight 初始是花纹层颜色的alpha值
        patternWeight = patternWeight * _PatternDetailWeight;
        half2 uv3TilingOffset = RotateUv((uv3 + half2(_PatternOffsetX,_PatternOffsetY)), _PatternRotateAngle) * _PatternTiling;
        half4 patternDetail = _PatternDetailMap.Sample(sampler_PatternDiffuseMap, uv3TilingOffset);
        roughness = saturate(roughness * (1 - patternWeight) + patternDetail.r * _PatternRoughnessScale * patternWeight);
        metallic = metallic * (1 - patternWeight) + patternDetail.b * _PatternMetallicScale * patternWeight;
        occlusion = occlusion * (1 - patternWeight) + saturate(lerp(1.0, patternDetail.g, _PatternOcclusionScale)) * patternWeight;; 
    #endif
    
    perceptualRoughness = saturate(roughness);
    return metallic;
}

#if defined(_SPARKLE_ON)
    void InitializeSparkleSurfaceData(half2 uv, out half4 sparkleColor, out float2 sparkleNoHPhase, out half sparkleScale, out half sparkleDependency, out half sparklePerceptualRoughness)
    {
         //控制每个棋盘格大小
        float2 megaUV = uv * _SparkleSize;
        //计算中心棋盘格index
        float2 sparkleSelfIdx = floor(megaUV);
        //计算当前像素所在象限，由于控制偏移，闪点中心不出棋盘格
        //所以在某一象限的像素只可能属于当前棋盘格闪点，所在象限相邻对角棋盘格闪点和该对角棋盘格相邻的两个棋盘格闪点
        //其他邻居棋盘格不可能影响该象限，所以总共是4次计算
        float2 quadrant = sign(megaUV - sparkleSelfIdx - 0.5);

        //中心棋盘格和对角棋盘格index,利用向量合并运算
        float4 sparkleIdxVec4 = float4(sparkleSelfIdx, sparkleSelfIdx + quadrant);
        //获取0到1随机种子
        float4 randomVec4 = float4(GetRandomFloat2Between01(sparkleIdxVec4.xy), GetRandomFloat2Between01(sparkleIdxVec4.zw));
        //获取随机缩放
        float2 sparkleSizeVec2 = half2(lerp(_SparkleScaleMin, 1, randomVec4.x), lerp(_SparkleScaleMin, 1, randomVec4.z));
        //计算最终的采样UV,randomVec4 - 0.5作为随机偏移，范围-0.5到0.5保证闪点中心不出棋盘格
        float4 finalUVVec4 = (megaUV.xyxy - sparkleIdxVec4 + randomVec4 - 0.5) / sparkleSizeVec2.xxyy;
        //控制闪点亮度
        half scale = tex2D(_SparkleScaleMap, sparkleIdxVec4.xy / _SparkleSize).r;

        half isSparkleSelf = step(0.95, tex2D(_SparkleShapeMap, finalUVVec4.xy).r * step(randomVec4.y, _SparkleCutoff));
        half isSparkleCorner = step(0.95, tex2D(_SparkleShapeMap, finalUVVec4.zw).r * step(randomVec4.w, _SparkleCutoff));
        //调整NoH相位来影响闪烁
        float NoHPhaseMax = -0.1;
        float2 randomColorUV = half2(0.5, 0.5);

        //一个像素同时属于多个闪点的时候，随机颜色按照NoHPhaseMax值最大的随机情况去采样
        half isGreater = isSparkleSelf;
        NoHPhaseMax = lerp(NoHPhaseMax, randomVec4.y, isGreater);
        scale = lerp(scale, tex2D(_SparkleScaleMap, sparkleIdxVec4.zw / _SparkleSize).r, isGreater);
        randomColorUV = lerp(randomColorUV, finalUVVec4.xy, isGreater);

        isGreater = isSparkleCorner;
        NoHPhaseMax = lerp(NoHPhaseMax, randomVec4.w, isGreater);
        randomColorUV = lerp(randomColorUV, finalUVVec4.zw, isGreater);

        //对角相邻的水平和垂直邻居棋盘格
        sparkleIdxVec4 = half4(sparkleSelfIdx + half2(quadrant.x, 0), sparkleSelfIdx + half2(0, quadrant.y));
        randomVec4 = half4(GetRandomFloat2Between01(sparkleIdxVec4.xy), GetRandomFloat2Between01(sparkleIdxVec4.zw));
        sparkleSizeVec2 = half2(lerp(_SparkleScaleMin, 1, randomVec4.x), lerp(_SparkleScaleMin, 1, randomVec4.z));
        finalUVVec4 = (megaUV.xyxy - sparkleIdxVec4 + randomVec4 - 0.5) / sparkleSizeVec2.xxyy;

        half isSparkleHorizon = step(0.95, tex2D(_SparkleShapeMap, finalUVVec4.xy).r * step(randomVec4.y, _SparkleCutoff));
        half isSparkleVertical = step(0.95, tex2D(_SparkleShapeMap, finalUVVec4.zw).r * step(randomVec4.w, _SparkleCutoff));

        isGreater = isSparkleHorizon;
        NoHPhaseMax = lerp(NoHPhaseMax, randomVec4.y, isGreater);
        scale = lerp(scale, tex2D(_SparkleScaleMap, sparkleIdxVec4.xy / _SparkleSize).r, isGreater);
        randomColorUV = lerp(randomColorUV, finalUVVec4.xy, isGreater);
       
        isGreater = isSparkleVertical;
        NoHPhaseMax = lerp(NoHPhaseMax, randomVec4.w, isGreater);
        scale = lerp(scale, tex2D(_SparkleScaleMap, sparkleIdxVec4.zw / _SparkleSize).r, isGreater);
        randomColorUV = lerp(randomColorUV, finalUVVec4.zw, isGreater);
        //用已有的随机值作为矩形范围，节省计算
        float leftBorder = saturate(max(randomVec4.x - NoHPhaseMax / 2, 0));
        float rightBorder = saturate(min(randomVec4.x + NoHPhaseMax / 2, 1));
        float bottomBorder = saturate(max(randomVec4.y - NoHPhaseMax / 2, 0));
        float upBorder = saturate(min(randomVec4.y + NoHPhaseMax / 2, 1));
        //最终的随机颜色采样UV 
        float2 finalRandomColorUV = half2(lerp(leftBorder, rightBorder, randomColorUV.x ), lerp(bottomBorder, upBorder, randomColorUV.y));

        half isSparkle = step(0, NoHPhaseMax); 

        sparkleColor.rgb = tex2D(_SparkleColorMap, finalRandomColorUV).rgb * _SparkleColor.rgb * isSparkle;
        sparkleColor.a = isSparkleSelf;
        sparkleNoHPhase = NoHPhaseMax;
        sparkleScale = scale;
        sparkleDependency = _SparkleDependency;
        sparklePerceptualRoughness = _SparkleRoughness;
    }
#endif