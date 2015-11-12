using UnityEngine;
using System.Collections;

public class shadowobject : MonoBehaviour {

	public GameObject cameraforDepth;

	// Update is called once per frame
	void Update () {
		GetComponent<Renderer>().material.SetMatrix("_LightViewMatrix",cameraforDepth.GetComponent<Camera>().worldToCameraMatrix);
		GetComponent<Renderer>().material.SetMatrix("_LightprojectionMatrix",cameraforDepth.GetComponent<Camera>().projectionMatrix);

	
	}
}
