using System.Collections;
using System.Collections.Generic;
using UnityEditor.Experimental.GraphView;
using UnityEngine;
using UnityEngine.Experimental.Rendering.RenderGraphModule;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace UnityEngine.Rendering.Universal
{
    internal class WriteClothStencilAndPreZPass : ScriptableRenderPass
    {
        FilteringSettings m_FilteringSettings;
        RenderStateBlock m_RenderStateBlock;
        List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>();

        private string m_ProfilerTag;
        ProfilingSampler m_ProfilingSampler;

        bool m_IsOpaque;

        public bool m_IsActiveTargetBackBuffer;

        public bool m_ShouldTransparentReceiveShadows;

        private bool m_UseDepthPriming;

        private static readonly int s_DrawObjectPassDataPropID = Shader.PropertyToID("_DrawObjectPassData");

        public WriteClothStencilAndPreZPass(string profilerTag, ShaderTagId[] shaderTagIds, bool opaque,
            RenderPassEvent evt, RenderQueueRange renderQueueRange, LayerMask layerMask, StencilState stencilState,
            int stencilReference)
        {
            base.profilingSampler = new ProfilingSampler(nameof(WriteClothStencilAndPreZPass));
            m_ProfilerTag = profilerTag;
            m_ProfilingSampler = new ProfilingSampler(profilerTag);
            foreach (var shaderTagId in shaderTagIds)
            {
                m_ShaderTagIdList.Add(shaderTagId);
            }

            renderPassEvent = evt;
            m_FilteringSettings = new FilteringSettings(renderQueueRange, layerMask);
            m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);
            m_IsOpaque = opaque;
            m_ShouldTransparentReceiveShadows = false;
            m_IsActiveTargetBackBuffer = false;

            m_PassData = new PassData();
            
            if (stencilState.enabled)
            {
                m_RenderStateBlock.stencilReference = stencilReference;
                m_RenderStateBlock.mask = RenderStateMask.Stencil;
                m_RenderStateBlock.stencilState = stencilState;
            }
        }

        public WriteClothStencilAndPreZPass(string profilerTag, bool opaque, RenderPassEvent evt,
            RenderQueueRange renderQueueRange, LayerMask layerMask, StencilState stencilState, int stencilReference)
            : this(profilerTag,
                new ShaderTagId[]
                {
                    new ShaderTagId("SRPDefaultUnlit"), new ShaderTagId("UniversalForward"),
                    new ShaderTagId("UniversalForwardOnly")
                },
                opaque, evt, renderQueueRange, layerMask, stencilState, stencilReference)
        {
        }


        // internal WriteClothStencilAndPreZPass(URPProfileId profileId, bool opaque, RenderPassEvent evt, RenderQueueRange renderQueueRange, LayerMask layerMask, StencilState stencilState, int stencilReference)
        //     : this(profileId.GetType().Name, opaque, evt, renderQueueRange, layerMask, stencilState, stencilReference)
        // {
        //     m_ProfilingSampler = ProfilingSampler.Get(profileId);
        // }

        PassData m_PassData;
        // Start is called before the first frame update
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            m_PassData.m_IsOpaque = m_IsOpaque;
            m_PassData.m_RenderingData = renderingData;
            m_PassData.m_RenderStateBlock = m_RenderStateBlock;
            m_PassData.m_FilteringSettings = m_FilteringSettings;
            m_PassData.m_ShaderTagIdList = m_ShaderTagIdList;
            m_PassData.m_ProfilingSampler = m_ProfilingSampler;
            m_PassData.m_IsActiveTargetBackBuffer = m_IsActiveTargetBackBuffer;
            m_PassData.pass = this;

            CameraSetup(renderingData.commandBuffer, m_PassData, ref renderingData);
            ExecutePass(context, m_PassData, ref renderingData, renderingData.cameraData.IsCameraProjectionMatrixFlipped());

        }

        private static void CameraSetup(CommandBuffer cmd, PassData data, ref RenderingData renderingData)
        {
            if (renderingData.cameraData.renderer.useDepthPriming && data.m_IsOpaque &&
                (renderingData.cameraData.renderType == CameraRenderType.Base || renderingData.cameraData.clearDepth))
            {
                data.m_RenderStateBlock.depthState = new DepthState(false, CompareFunction.Equal);
                data.m_RenderStateBlock.mask |= RenderStateMask.Depth;
            }
            else if (data.m_RenderStateBlock.depthState.compareFunction == CompareFunction.Equal)
            {
                data.m_RenderStateBlock.depthState = new DepthState(true, CompareFunction.LessEqual);
                data.m_RenderStateBlock.mask |= RenderStateMask.Depth;
            }
        }

        private static void ExecutePass(ScriptableRenderContext context, PassData data, ref RenderingData renderingData,
            bool flipy)
        {
            var cmd = renderingData.commandBuffer;
            using (new ProfilingScope(cmd, data.m_ProfilingSampler))
            {
                Vector4 drawObjectPassData = new Vector4(0.0f, 0.0f, 0.0f, data.m_IsOpaque ? 1f : 0.0f);
                cmd.SetGlobalVector(s_DrawObjectPassDataPropID, drawObjectPassData);
                if (data.m_RenderingData.cameraData.xrRendering && data.m_IsActiveTargetBackBuffer)
                {
                    cmd.SetViewport(data.m_RenderingData.cameraData.xr.GetViewport());
                }

                float flipSign = flipy ? -1.0f : 1.0f;
                Vector4 scaleBias = (flipSign < 0.0f)
                    ? new Vector4(flipSign, 1.0f, -1.0f, 1.0f)
                    : new Vector4(flipSign, 0.0f, 1.0f, 1.0f);
                
                cmd.SetGlobalVector(ShaderPropertyId.scaleBiasRt, scaleBias);
                
                float alphaToMaskAvailable = ((renderingData.cameraData.cameraTargetDescriptor.msaaSamples > 1) && data.m_IsOpaque) ? 1.0f : 0.0f;
                cmd.SetGlobalFloat(ShaderPropertyId.alphaToMaskAvailable, alphaToMaskAvailable);
                
                data.pass.OnExecute(cmd);
                
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                
                Camera camera = renderingData.cameraData.camera;
                var sortFlags = (data.m_IsOpaque) ? renderingData.cameraData.defaultOpaqueSortFlags : SortingCriteria.CommonTransparent;
                if (renderingData.cameraData.renderer.useDepthPriming && data.m_IsOpaque && (renderingData.cameraData.renderType == CameraRenderType.Base || renderingData.cameraData.clearDepth))
                    sortFlags = SortingCriteria.SortingLayer | SortingCriteria.RenderQueue | SortingCriteria.OptimizeStateChanges | SortingCriteria.CanvasOrder;

                var filterSettings = data.m_FilteringSettings;
                
                DrawingSettings drawSettings = RenderingUtils.CreateDrawingSettings(data.m_ShaderTagIdList, ref renderingData, sortFlags);

                var activeDebugHandler = GetActiveDebugHandler(ref renderingData);
                if (activeDebugHandler != null)
                {
                    activeDebugHandler.DrawWithDebugRenderState(context, cmd, ref renderingData, ref drawSettings, ref filterSettings, ref data.m_RenderStateBlock,
                        (ScriptableRenderContext ctx, ref RenderingData data, ref DrawingSettings ds, ref FilteringSettings fs, ref RenderStateBlock rsb) =>
                        {
                            ctx.DrawRenderers(data.cullResults, ref ds, ref fs, ref rsb);
                        });
                }
                else
                {
                    context.DrawRenderers(renderingData.cullResults, ref drawSettings, ref filterSettings, ref data.m_RenderStateBlock);

                    // Render objects that did not match any shader pass with error shader
                    RenderingUtils.RenderObjectsWithError(context, ref renderingData.cullResults, camera, filterSettings, SortingCriteria.None);
                }

                // Clean up
                CoreUtils.SetKeyword(cmd, ShaderKeywordStrings.WriteRenderingLayers, false);
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
            }
        }

        private class PassData
        {
            internal TextureHandle m_Albedo;
            internal TextureHandle m_Depth;

            internal RenderingData m_RenderingData;
            internal bool m_IsOpaque;
            internal RenderStateBlock m_RenderStateBlock;
            internal FilteringSettings m_FilteringSettings;
            internal List<ShaderTagId> m_ShaderTagIdList;
            internal ProfilingSampler m_ProfilingSampler;

            internal bool m_IsActiveTargetBackBuffer;
            internal WriteClothStencilAndPreZPass pass;
        }

        internal void Render(RenderGraph renderGraph, TextureHandle colorTarget, TextureHandle depthTarget,
            ref RenderingData renderingData)
        {
            using (var builder = renderGraph.AddRenderPass<PassData>("WriteClothStencilAndPreZPass", out PassData data))
            {
                data.m_Albedo = builder.UseColorBuffer(colorTarget, 0);
                data.m_Depth = builder.UseDepthBuffer(depthTarget, DepthAccess.Write);
                
                data.m_RenderingData = renderingData;
                data.m_IsOpaque = m_IsOpaque;
                data.m_RenderStateBlock = m_RenderStateBlock;
                data.m_FilteringSettings = m_FilteringSettings;
                data.m_ShaderTagIdList = m_ShaderTagIdList;
                data.m_ProfilingSampler = m_ProfilingSampler;

                data.m_IsActiveTargetBackBuffer = m_IsActiveTargetBackBuffer;
                data.pass = this;
                
                builder.SetRenderFunc((PassData data, RenderGraphContext context) =>
                {
                    ref var renderingData = ref data.m_RenderingData;
                    bool yflip =
                        renderingData.cameraData.IsRenderTargetProjectionMatrixFlipped(data.m_Albedo, data.m_Depth);
                    CameraSetup(context.cmd, data, ref renderingData);
                    ExecutePass(context.renderContext, data, ref renderingData, yflip);
                });
            }
        }
        
        protected virtual void OnExecute(CommandBuffer cmd) { }
    }
}