using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Experimental.Rendering.RenderGraphModule;

public class HairDepthFeature : ScriptableRendererFeature
{
    class HairDepthRenderPass : ScriptableRenderPass
    {
        private RTHandle hairDepthTexture;
        private ProfilingSampler m_ProfilingSampler =  new ProfilingSampler("Hair Depth");
        internal const string k_HairShdowMap = "_HAIRSHADOW_SHADOWMAP";
        internal const string k_HairShadow_Exp = "_HAIRSHADOW_EXPFALLOFF";
        internal const string k_HairShdow_Deep = "_HAIRSHADOW_DEEPOPACITY";
        internal const string k_HairSoftShadow = "_HAIRSHADOW_SOFT";
        internal const int width = 1024;
        
        public void Setup(ref RenderingData renderingData)
        {
            Shader.EnableKeyword(k_HairShdowMap);
            Shader.EnableKeyword(k_HairSoftShadow);
            
            Shader.DisableKeyword(k_HairShadow_Exp);
            Shader.DisableKeyword(k_HairShdow_Deep);
        }
        
        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in a performant manner.
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            
            RenderTextureDescriptor descriptor = renderingData.cameraData.cameraTargetDescriptor;
            descriptor.width = width;
            descriptor.height = width;
            descriptor.graphicsFormat = Experimental.Rendering.GraphicsFormat.None;
            
            hairDepthTexture = RenderingUtils.ReAllocateIfNeeded(ref hairDepthTexture, width, width)
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    HairDepthRenderPass m_ScriptablePass;

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new HairDepthRenderPass();

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


