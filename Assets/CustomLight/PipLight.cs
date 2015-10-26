using UnityEngine;

[ExecuteInEditMode()]
public class PipLight : MonoBehaviour
{
	public float range = 16.0f;
	public Color color = Color.white;
	public float intensity = 1.0f;
	public LightShadows shadowType = LightShadows.Hard;
	public ShadowTextureSize shadowResolution = ShadowTextureSize.x1024;
	public ShadowRefreshMode updateMode = ShadowRefreshMode.Manual;
	public float levelOfDetailAggression = 1.0f;
	public float shadowBias = 0.97f;
	public float shadowStrength = 0.0f;
	public int cullingMask = -1;
	public Texture cookie = null;

	[System.NonSerialized]
	public bool
		renderedThisFrame = false;

	[System.NonSerialized]
	public bool
		UpdateNextFrame = true;
	
	RenderTexture renderTexture;
	MaterialPropertyBlock properties = null;
	ShadowTextureSize shadowResolutionCurrent = ShadowTextureSize.x256;
	Camera depthCamera;

	static int prop_Pip_LightPositionRange;
	static int prop_LightPositionRange;	
	static int prop_ShadowMapTexture;
	static int prop_LightColor;
	static int prop_LightPos;
	static int prop_ShadowData;
	static int prop_LightTexture0;
	static int prop_LightMatrix0;
	static int prop_LightAsQuad;

	public MaterialPropertyBlock GetMaterialPropertyBlock ()
	{
		if (properties == null) {
			properties = new MaterialPropertyBlock ();
		} else {
			properties.Clear ();
		}
		if (shadowType != LightShadows.None) {
			properties.SetVector (prop_ShadowData, new Vector4 () {x = shadowStrength});
			properties.SetTexture (prop_ShadowMapTexture, renderTexture);
		}
		if (cookie != null) {
			properties.SetTexture (prop_LightTexture0, cookie);
			properties.SetMatrix (prop_LightMatrix0, transform.worldToLocalMatrix);
		}
		Vector4 _LightPos = transform.position;
		_LightPos.w = 1.0f / range;
		properties.SetVector (prop_LightPositionRange, _LightPos);
		_LightPos.w /= range;
		properties.SetVector (prop_LightPos, _LightPos);
		properties.SetVector (prop_LightColor, color.linear * intensity);
		properties.SetFloat (prop_LightAsQuad, 0f);
		return properties;
	}

	public enum ShadowTextureSize
	{
		x8 = 8,
		x16 = 16,
		x32 = 32,
		x64 = 64,
		x128 = 128,
		x256 = 256,
		x512 = 512,
		x1024 = 1024,
		x2048 = 2048,
		x4096 = 4096,
		x8192 = 8192
	}

	public enum ShadowRefreshMode
	{
		EveryFrame = 1,
		Manual
	}
	
	public void OnEnable ()
	{	
		PipLightSystem.instance.Add (this);
		UpdateNextFrame = true;
	}

	public void OnDisable ()
	{
		PipLightSystem.instance.Remove (this);
		if (renderTexture) {
			DestroyImmediate (renderTexture);
			renderTexture = null;
		}
	}
	
	public void OnDrawGizmosSelected ()
	{
		Gizmos.DrawWireSphere (transform.position, range);
	}
	
	public void OnDrawGizmos ()
	{
		Gizmos.color = color;
		Gizmos.DrawSphere (transform.position, range / 64);
	}

	public static void CheckKeywords ()
	{
		prop_Pip_LightPositionRange = Shader.PropertyToID ("Pip_LightPositionRange");
		prop_LightPositionRange = Shader.PropertyToID ("_LightPositionRange");	
		prop_ShadowMapTexture = Shader.PropertyToID ("_ShadowMapTexture");
		prop_LightColor = Shader.PropertyToID ("_LightColor");
		prop_LightPos = Shader.PropertyToID ("_LightPos");
		prop_ShadowData = Shader.PropertyToID ("_LightShadowData");
		prop_LightTexture0 = Shader.PropertyToID ("_LightTexture0");
		prop_LightMatrix0 = Shader.PropertyToID ("_LightMatrix0");
		prop_LightAsQuad = Shader.PropertyToID ("_LightAsQuad");
	}

	public void UpdateLOD ()
	{
		Camera cam = Camera.main;
		if (!cam) {
			return;
		}
		Vector3 v1 = cam.transform.position;
		Vector3 v2 = transform.position;
		float radius = range;
		float distance = Vector3.Distance (v1, v2) * levelOfDetailAggression;
		float qualityMultiplier;
		if (distance <= radius) {
			qualityMultiplier = 1.0f;
		} else {
			qualityMultiplier = radius / distance;
		}
		int qualityNew = Mathf.ClosestPowerOfTwo ((int)((int)shadowResolution * qualityMultiplier));
		qualityNew = Mathf.Max (64, qualityNew);
		if (qualityNew != (int)shadowResolutionCurrent) {
			shadowResolutionCurrent = (ShadowTextureSize)qualityNew;
			UpdateNextFrame = true;
		}
		CheckTexture ();
	}

	void CheckCamera ()
	{
		if (!depthCamera) {
			depthCamera = GetComponent<Camera> ();
			if (!depthCamera) {
				depthCamera = gameObject.AddComponent<Camera> ();
			}
			depthCamera.hideFlags = HideFlags.NotEditable | HideFlags.HideInInspector | HideFlags.HideInHierarchy;
			depthCamera.clearFlags = CameraClearFlags.SolidColor;
			depthCamera.backgroundColor = Color.white;
			depthCamera.useOcclusionCulling = false;
			depthCamera.hdr = true;
			depthCamera.enabled = false;
			depthCamera.nearClipPlane = 0.01f;
			depthCamera.renderingPath = RenderingPath.VertexLit;
			depthCamera.SetReplacementShader (PipLightRenderer.DepthShader, "");
		}
		depthCamera.cullingMask = cullingMask;
	}

	void CheckTexture ()
	{
		if (!renderTexture) {
			renderTexture = new RenderTexture ((int)shadowResolutionCurrent, (int)shadowResolutionCurrent, 0, RenderTextureFormat.RHalf, RenderTextureReadWrite.Linear);
			renderTexture.hideFlags = HideFlags.DontSave;
			renderTexture.isCubemap = true;
			renderTexture.useMipMap = false;
			renderTexture.generateMips = false;
		} else if (renderTexture.height != (int)shadowResolutionCurrent) {
			renderTexture.Release ();
			renderTexture.width = (int)shadowResolutionCurrent;
			renderTexture.height = (int)shadowResolutionCurrent;
			renderTexture.Create ();
		}
	}

	public void UpdateIfNeeded ()
	{
		if (!renderedThisFrame && shadowType != LightShadows.None) {
			CheckCamera ();
			if (UpdateNextFrame || updateMode == ShadowRefreshMode.EveryFrame) {
				Vector4 positionRange = transform.position;
				positionRange.w = 1.0f / range;
				Shader.SetGlobalVector (prop_Pip_LightPositionRange, positionRange);
				depthCamera.farClipPlane = range;
				depthCamera.RenderToCubemap (renderTexture);
				UpdateNextFrame = false;
				renderedThisFrame = true;
			}
		}
	}
}