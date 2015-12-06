using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
public class ShadowMap : MonoBehaviour
{
	private Camera lightCam = null;

	// Use this for initialization
	void Start ()
	{
    }
	
	// Update is called once per frame
	void Update () 
	{
        if (!lightCam)
        {
            foreach (Camera cam in Camera.allCameras)
            {
                if (cam.name == "LightCamera")
                    lightCam = cam;
            }
        }

        GetComponent<Renderer>().sharedMaterial.SetMatrix("_ProjMatrix", lightCam.projectionMatrix * lightCam.worldToCameraMatrix);
        GetComponent<Renderer>().sharedMaterial.SetMatrix("_LightViewMatrix", lightCam.worldToCameraMatrix);
    }
}
