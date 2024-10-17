using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Experimental;
using UnityEngine.Experimental.Rendering.RenderGraphModule;

namespace UnityEngine.Rendering.Universal
{
    public class HairDepthRenderPass : ScriptableRenderPass
    {
        private RTHandle hairDepthTexture;
        private ProfilingSampler m_ProfilingSampler = new ProfilingSampler("Hair Depth");
        internal const string k_HairShdowMap = "_HAIRSHADOW_SHADOWMAP";
        internal const string k_HairShadow_Exp = "_HAIRSHADOW_EXPFALLOFF";
        internal const string k_HairShdow_Deep = "_HAIRSHADOW_DEEPOPACITY";
        internal const string k_HairSoftShadow = "_HAIRSHADOW_SOFT";
        internal const string k_RenderingHairDepth = "_RENDERING_HAIR_DEPTH";
        
        internal const string s_TextureName = "_HairDepthTexture";
        internal const int resolution = 1024;
        const int k_ShadowmapBufferBits = 16;
        public static Renderer hairMeshRenderer = null;
        private Material hairMat;
        private int shaodwCasterPass = -1;
        private int subMeshIndex = 0;
        private HairRenderingData hairRenderingData;

        public bool Setup(ref RenderingData renderingData, HairRenderingData data)
        {
            if (data == null) return false;
            
            Shader.EnableKeyword(k_HairShdowMap);
            Shader.EnableKeyword(k_HairSoftShadow);

            Shader.DisableKeyword(k_HairShadow_Exp);
            Shader.DisableKeyword(k_HairShdow_Deep);

            hairMeshRenderer = data.hairRenderer;
            hairMat = data.hairMaterial;
            shaodwCasterPass = data.shadowCasterPass;

            renderPassEvent = RenderPassEvent.BeforeRenderingShadows;

            hairRenderingData = data;

            return true;
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            ConfigureTarget(hairDepthTexture);
            ConfigureClear(ClearFlag.All, Color.black);
        }

        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in a performant manner.
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            RenderTextureDescriptor descriptor = renderingData.cameraData.cameraTargetDescriptor;

            descriptor.width = resolution;
            descriptor.height = resolution;
            descriptor.graphicsFormat = UnityEngine.Experimental.Rendering.GraphicsFormat.None;
            var format =
                UnityEngine.Experimental.Rendering.GraphicsFormatUtility.GetDepthStencilFormat(
                    k_ShadowmapBufferBits, 0);
            descriptor.depthStencilFormat = format;
            descriptor.mipCount = 1;
            descriptor.useMipMap = false;
            descriptor.msaaSamples = 1;
            descriptor.autoGenerateMips = false;

            RenderingUtils.ReAllocateIfNeeded(ref hairDepthTexture, descriptor, FilterMode.Bilinear,
                TextureWrapMode.Clamp, name: s_TextureName);

            hairRenderingData.hairDepthTexture = hairDepthTexture;
            
            cmd.EnableShaderKeyword(k_RenderingHairDepth);
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            int mainLightIndex = renderingData.lightData.mainLightIndex;
            Light light = renderingData.lightData.visibleLights[mainLightIndex].light;
            Matrix4x4 view, proj;
            Vector4 shadowFrustumParams, shadowBias;
            CalcLightViewProjMatrix(light, hairMeshRenderer.bounds, out view, out proj, out shadowFrustumParams,
                out shadowBias);
            Matrix4x4 worldToShdow = ShadowUtils.GetShadowTransform(proj, view);

            hairRenderingData.worldToShadow = worldToShdow;
            hairRenderingData.shadowFrustumParams = shadowFrustumParams;

            CommandBuffer cmd = renderingData.commandBuffer;
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                cmd.SetViewProjectionMatrices(view, proj);
                cmd.SetGlobalVector("_LightDirection", -light.transform.forward);
                cmd.SetGlobalVector("_ShadowBias", shadowBias);
            
                cmd.DrawRenderer(hairMeshRenderer, hairMat, subMeshIndex, shaodwCasterPass);
                
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
            }
            
        }

        private class PassData
        {
            internal RenderingData renderingData;
            internal HairDepthRenderPass pass;
        }
        
        internal void Render(RenderGraph renderGraph, out TextureHandle destination, ref RenderingData renderingData)
        {
            using (var builder = renderGraph.AddRenderPass<PassData>("HairDepth", out PassData data))
            {
                
            }
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.DisableShaderKeyword(k_RenderingHairDepth);
        }

        public void Dispose()
        {
            hairDepthTexture?.Release();
        }

        private void CalcLightViewProjMatrix(Light shadowLight, Bounds bounds, out Matrix4x4 view,
            out Matrix4x4 proj, out Vector4 shadowFrustumParams, out Vector4 shadowBias)
        {
            Vector3 lightDir = shadowLight.transform.forward;
            Vector3 z = -lightDir;
            Vector3 x = Mathf.Abs(lightDir.y) < 0.99f ? Vector3.Cross(z, Vector3.up) : Vector3.right;
            Vector3 y = Vector3.Cross(x, z);
            Vector3 origin = bounds.center;

            Matrix4x4 view2World = Matrix4x4.identity;
            view2World.SetColumn(0, x);
            view2World.SetColumn(1, y);
            view2World.SetColumn(2, z);
            view2World.SetColumn(3, new Vector4(origin.x, origin.y, origin.z, 1.0f));
            view = view2World.inverse;

            float l = -1.0f;
            for (int i = 0; i < 8; i++)
            {
                Vector3 v = new Vector3(
                    bounds.extents.x * (((i & 4) >> 2) * 2 - 1),
                    bounds.extents.y * (((i & 2) >> 1) * 2 - 1),
                    bounds.extents.z * (((i & 1) >> 0) * 2 - 1)
                );
                l = Mathf.Max(l, Mathf.Max(Vector3.Dot(x, v), Vector3.Dot(y, v)));
            }

            l *= 1.05f;

            proj = Matrix4x4.Ortho(-l, l, -l, l, -l, l);

            shadowFrustumParams = new Vector4(1.0f, l * 2.0f, 0.0f, 0.0f);
            float texelSize = 2.0f * l / resolution;
            texelSize *= 2.5f;
            shadowBias = new Vector4(-1.0f * texelSize, -1.0f * texelSize, 0.0f, 0.0f); // hard-coded shadow bias
        }
    }
}
