using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public static class HairCollector
{
    private static List<HairRenderingData> _hairRenderingDatas = new List<HairRenderingData>();
    private static List<MeshRenderer> _hairRenderer = new List<MeshRenderer>();
    
    public static void AddHairRender(MeshRenderer meshRenderer)
    {
        if (_hairRenderer.Contains(meshRenderer)) return;
        _hairRenderer.Add(meshRenderer);
        _hairRenderingDatas.Add(new HairRenderingData(meshRenderer));
    }

    public static HairRenderingData GetHairRenderingData()
    {
        return _hairRenderingDatas.Count > 0 ? _hairRenderingDatas[0] : null;
    }
    
}
