using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
public class fix : MonoBehaviour {

	// Use this for initialization
	void Start () {
		GetComponent<Camera>().depthTextureMode = DepthTextureMode.None;
	
	}
	
	// Update is called once per frame
	void Update () {
	
	}
}
