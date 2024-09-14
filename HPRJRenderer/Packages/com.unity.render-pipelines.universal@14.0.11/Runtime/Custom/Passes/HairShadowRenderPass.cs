using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Experimental;

namespace UnityEngine.Rendering.Universal
{
    public class HairShaodwRenderPass : ScriptableRenderPass
    {
        private RTHandle hairShadowTexture;
        private RTHandle blurredHairShadowTexture;
        
        private ProfilingSampler m_ProfilingSampler = new ProfilingSampler("Hair Shadow");
        
        internal const string s_TextureName = "_HairShadowTexture";
        internal const string s_BlurredTextureName = "_BlurredHairShadowTexture";

        public static Renderer hairMeshRenderer = null;
        private Material hairMat;
        private int opaqueShadowPass = -1;
        private int deepOpacityPass = -1;
        private int subMeshIndex = 0;

        public bool Setup(ref RenderingData renderingData, HairRenderingData data)
        {
            if (data == null) return false;
            
            hairMeshRenderer = data.hairRenderer;
            hairMat = data.hairMaterial;
            opaqueShadowPass = data.opaqueShadowPass;
            deepOpacityPass = data.deepOpacityPass;
            
            renderPassEvent = RenderPassEvent.BeforeRenderingPrePasses;

            return true;
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            ConfigureTarget(hairShadowTexture, hairShadowTexture);
            ConfigureClear(ClearFlag.All, Color.black);
            ConfigureDepthStoreAction(RenderBufferStoreAction.DontCare);
        }

        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in a performant manner.
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            RenderTextureDescriptor cameraTextureDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            cameraTextureDescriptor.depthBufferBits = 0;
            RenderingUtils.ReAllocateIfNeeded(ref hairShadowTexture, cameraTextureDescriptor, FilterMode.Bilinear, TextureWrapMode.Clamp, name:s_TextureName);
            RenderingUtils.ReAllocateIfNeeded(ref blurredHairShadowTexture, cameraTextureDescriptor, FilterMode.Bilinear, TextureWrapMode.Clamp, name:s_BlurredTextureName);
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = renderingData.commandBuffer;
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                
            }
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }

        public void Dispose()
        {
        }
    }
}
