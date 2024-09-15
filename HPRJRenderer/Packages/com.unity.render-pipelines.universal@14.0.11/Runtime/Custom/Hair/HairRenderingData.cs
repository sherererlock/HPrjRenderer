using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class HairRenderingData
{
    public Renderer hairRenderer;
    public Material hairMaterial;
    public int submeshIndex = 0;
    public int shadowCasterPass = -1;
    public int deepOpacityPass = -1;
    public int opaqueShadowPass = -1;
    public int transparentShadowPass = -1;
    public Vector4 shadowFrustumParams;
    public Vector4 shadowBias;
    public Matrix4x4 worldToShadow;
    public RTHandle hairDepthTexture; 

    public HairRenderingData(Renderer renderer)
    {
        hairRenderer = renderer;
        hairMaterial = renderer.sharedMaterial;

        shadowCasterPass = hairMaterial.FindPass("ShadowCaster");
        deepOpacityPass = hairMaterial.FindPass("DeepOpacityPass");
        opaqueShadowPass = hairMaterial.FindPass("ShadowPassOpaque");
        transparentShadowPass = hairMaterial.FindPass("ShadowPassTransparent");
    }
}
