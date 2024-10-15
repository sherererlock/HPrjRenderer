using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;

namespace UnityEngine.Rendering.Universal
{
    public class FurShellRenderFeature : ScriptableRendererFeature
    {
        [System.Serializable]
        public class FilterSettings
        {
            // TODO: expose opaque, transparent, all ranges as drop down

            /// <summary>
            /// The queue type for the objects to render.
            /// </summary>
            public RenderQueueType RenderQueueType;

            /// <summary>
            /// The layer mask to use.
            /// </summary>
            public LayerMask LayerMask;

            /// <summary>
            /// The passes to render.
            /// </summary>
            public string[] PassNames;

            /// <summary>
            /// The constructor for the filter settings.
            /// </summary>
            public FilterSettings()
            {
                RenderQueueType = RenderQueueType.Opaque;
                LayerMask = 0;
            }
        }

        [System.Serializable]
        public class FurRenderSettings
        {
            public string passTag = "FurRenderFeature";
            public RenderPassEvent renderPassEvent;
            public FilterSettings filterSettings = new FilterSettings();
        }

        public FurRenderSettings settings = new FurRenderSettings();

        private FurShellRenderPass m_FurShellRenderPass;
        public override void Create()
        {
            FilterSettings filterSettings = settings.filterSettings;
            if (settings.renderPassEvent < RenderPassEvent.BeforeRenderingPrePasses)
                settings.renderPassEvent = RenderPassEvent.BeforeRenderingPrePasses;

            m_FurShellRenderPass = new FurShellRenderPass(settings.passTag, settings.renderPassEvent,
                settings.filterSettings.PassNames,
                settings.filterSettings.RenderQueueType, settings.filterSettings.LayerMask);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (renderingData.cameraData.cameraType == CameraType.Preview ||
                UniversalRenderer.IsOffscreenDepthTexture(in renderingData.cameraData))
                return;
            
            renderer.EnqueuePass(m_FurShellRenderPass);
        }
    }

    public class FurShellRenderPass : ScriptableRenderPass
    {
        RenderQueueType renderQueueType;
        FilteringSettings m_FilteringSettings;
        private string m_ProfilerTag;
        private ProfilingSampler m_ProfilingSampler;
        
        private List<ShaderTagId> m_ShaderTagList = new List<ShaderTagId>();
        RenderStateBlock m_RenderStateBlock;

        public FurShellRenderPass(string profilerTag, RenderPassEvent renderPassEvent, string[] shaderTags,
            RenderQueueType renderQueueType, int layerMask)
        {
            base.profilingSampler = new ProfilingSampler(nameof(FurShellRenderPass));
            m_ProfilerTag = profilerTag;
            m_ProfilingSampler = new ProfilingSampler(profilerTag);
            this.renderPassEvent = renderPassEvent;
            this.renderQueueType = renderQueueType;

            foreach (var shaderTag in shaderTags)
            {
                m_ShaderTagList.Add(new ShaderTagId(shaderTag));
            }

            m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);
        }
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            SortingCriteria sortingCriteria = (renderQueueType == RenderQueueType.Transparent)
                ? SortingCriteria.CommonTransparent
                : renderingData.cameraData.defaultOpaqueSortFlags;

            DrawingSettings drawingSettings =
                CreateDrawingSettings(m_ShaderTagList, ref renderingData, sortingCriteria);

            ref CameraData cameraData = ref renderingData.cameraData;
            Camera camera = cameraData.camera;

            Rect pixelRect = renderingData.cameraData.pixelRect;
            float cameraAspect = (float)pixelRect.width / (float)pixelRect.height;

            var cmd = renderingData.commandBuffer;
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref m_FilteringSettings, ref m_RenderStateBlock);
            }
        }
    }
}