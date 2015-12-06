using UnityEngine;
using System.Collections;
using System.Runtime.Remoting.Channels;

[ExecuteInEditMode]
public class EnableDepthBuffer : MonoBehaviour {

    public Material mat;
    public RenderTexture ShadowMap;

    void Start()
    {
        GetComponent<Camera>().depthTextureMode = DepthTextureMode.Depth;
        GetComponent<Camera>().renderingPath = RenderingPath.Forward;
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(null, ShadowMap, mat, 0);
        //Graphics.Blit(null, destination, mat, 1);
        Graphics.Blit(source, destination);
    }
}
