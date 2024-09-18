using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;


[ExecuteAlways]
public class HairRegister : MonoBehaviour
{
    // Start is called before the first frame update
    public static MeshRenderer hairRender;
    public Texture cubeMap;
    public bool setCubeMap = false;
    void Start()
    {
        HairCollector.AddHairRender(GetComponentInChildren<MeshRenderer>());
    }

    private void Update()
    {
        HairCollector.AddHairRender(GetComponentInChildren<MeshRenderer>());

        if (cubeMap && !setCubeMap)
        {
            Shader.SetGlobalTexture("_charCubeMap", cubeMap);
        }
    }

    private void OnDestroy()
    {
        HairCollector.RemoveHairRender(GetComponentInChildren<MeshRenderer>());
    }
}
