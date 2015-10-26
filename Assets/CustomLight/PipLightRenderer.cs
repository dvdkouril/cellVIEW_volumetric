using UnityEngine;
using UnityEngine.Rendering;
using System.Collections.Generic;

#if UNITY_EDITOR
using UnityEditor;
#endif

public class PipLightSystem
{ 
	static PipLightSystem m_Instance;

	public static PipLightSystem instance {
		get {
			if (m_Instance == null)
				m_Instance = new PipLightSystem ();
			return m_Instance;
		}
	}

	internal HashSet<PipLight> m_Lights = new HashSet<PipLight> ();

	public void Add (PipLight o)
	{
		Remove (o);
		m_Lights.Add (o);
	}

	public void Remove (PipLight o)
	{
		m_Lights.Remove (o);
	}
}

[ExecuteInEditMode()]
public class PipLightRenderer : MonoBehaviour
{
	public Shader depthShader;
	public Mesh lightSphereMesh;
	
	public Material PointNoShadows;
	public Material PointHardShadows;
	public Material PointSoftShadows;
	public Material PointCookieNoShadows;
	public Material PointCookieHardShadows;
	public Material PointCookieSoftShadows;

#if UNITY_EDITOR
	public static Camera[] SceneViewCameras;
#endif

	public static Shader DepthShader = null;

	static Dictionary<Camera, CommandBuffer> buffers = new Dictionary<Camera, CommandBuffer> ();
	
	public static void RefreshAll ()
	{
		foreach (var light in PipLightSystem.instance.m_Lights) {
			light.UpdateNextFrame = true;
			light.UpdateLOD ();
			light.UpdateIfNeeded ();
		}
	}

	public void Refresh ()
	{
		LateUpdate ();
	}
	
	Material GetMaterial (PipLight light)
	{
		if (light.shadowType == LightShadows.None) {
			return light.cookie == null ? PointNoShadows : PointCookieNoShadows;
		} else if (light.shadowType == LightShadows.Hard) {
			return light.cookie == null ? PointHardShadows : PointCookieHardShadows;
		} else {
			return light.cookie == null ? PointSoftShadows : PointCookieSoftShadows;
		}
	}

	void OnDisable ()
	{
		foreach (var pair in buffers) {
			if (pair.Key != null) {
				pair.Key.RemoveCommandBuffer (CameraEvent.BeforeImageEffectsOpaque, pair.Value);
			}
		}
	}

	void OnEnable ()
	{
		CommandBuffer buffer;
		Camera camera = GetComponent<Camera> ();
		if (buffers.TryGetValue (camera, out buffer)) {
			camera.AddCommandBuffer (CameraEvent.BeforeImageEffectsOpaque, buffer);
		}

#if UNITY_EDITOR
		if (SceneViewCameras != null) {
			for (int i = 0; i < SceneViewCameras.Length; i++) {
				if (buffers.TryGetValue (SceneViewCameras [i], out buffer)) {
					SceneViewCameras [i].AddCommandBuffer (CameraEvent.BeforeImageEffectsOpaque, buffer);
				}
			}
		}
#endif

		PipLight.CheckKeywords ();
		DepthShader = depthShader;
	}

	void ReconstructLightBuffers (Camera camera, bool toCull)
	{
		CommandBuffer cameraBuffer = null;
		buffers.TryGetValue (camera, out cameraBuffer);
		if (cameraBuffer != null) {
			cameraBuffer.Clear ();
		} else {
			cameraBuffer = new CommandBuffer ();
			cameraBuffer.name = "Deferred custom lights";
			camera.AddCommandBuffer (CameraEvent.BeforeImageEffectsOpaque, cameraBuffer);
			buffers.Add (camera, cameraBuffer);
		}
		var system = PipLightSystem.instance;
		Bounds bounds = new Bounds ();
		Plane[] frustrumPlanes = null;

		if (toCull) {
			frustrumPlanes = GeometryUtility.CalculateFrustumPlanes (camera);
		}
		foreach (var light in system.m_Lights) {
			bool toRenderThisLight = true;
			light.UpdateLOD ();
			if (toCull) {
				bounds.center = light.transform.position;
				bounds.extents = Vector3.one * light.range;
				toRenderThisLight = GeometryUtility.TestPlanesAABB (frustrumPlanes, bounds);
			}
			if (toRenderThisLight) {
				light.UpdateIfNeeded ();
				cameraBuffer.DrawMesh (
					lightSphereMesh, 
					Matrix4x4.TRS (light.transform.position, Quaternion.identity, Vector3.one * light.range * 2f), 
					GetMaterial (light),
					0, 
					0,
					light.GetMaterialPropertyBlock ()
				);
			}
		}
	}

	void LateUpdate ()
	{
		foreach (var light in PipLightSystem.instance.m_Lights) {
			light.renderedThisFrame = false;
		}
		if (GetComponent<Camera> () != null) {
			ReconstructLightBuffers (GetComponent<Camera> (), true);
		}

		#if UNITY_EDITOR
		SceneViewCameras = SceneView.GetAllSceneCameras ();
		for (int i = 0; i < SceneViewCameras.Length; i++) {
			ReconstructLightBuffers (SceneViewCameras [i], false);
		}
		#endif
	}
}
