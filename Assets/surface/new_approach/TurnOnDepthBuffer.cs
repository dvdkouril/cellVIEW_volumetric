using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
public class TurnOnDepthBuffer : MonoBehaviour {

	// Use this for initialization
	void Start () {
	    GetComponent<Camera>().depthTextureMode = DepthTextureMode.Depth;
        GetComponent<Camera>().renderingPath = RenderingPath.Forward;
	    GetComponent<Camera>().backgroundColor = Color.white;
        GetComponent<Camera>().SetReplacementShader(Shader.Find("DepthMapGen"), "RenderType");
	}
	
	// Update is called once per frame
	void Update () {
	
	}
}
