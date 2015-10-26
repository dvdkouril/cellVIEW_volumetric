using UnityEngine;
using System.Collections;

public class EnableRenderTexture : MonoBehaviour {

	public Material mat;

	void Start () {
	
	}
	
	void OnRenderImage(RenderTexture source, RenderTexture destination) {
		Graphics.Blit (source, destination, mat);
	}
}
