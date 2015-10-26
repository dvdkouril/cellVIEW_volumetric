using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(PipLight))]
public class CustomLightEditor : Editor
{
	string[] cullingLayers = new string[32];

	public override void OnInspectorGUI ()
	{
		for (int i = 0; i < 32; i++) {
			cullingLayers [i] = LayerMask.LayerToName (i);
		}
		PipLight light = target as PipLight;
		light.range = EditorGUILayout.FloatField ("Range", light.range);
		light.color = EditorGUILayout.ColorField ("Color", light.color);
		light.intensity = EditorGUILayout.FloatField ("Intensity", light.intensity);
		light.shadowType = (LightShadows)EditorGUILayout.EnumPopup ("Shadow Type", light.shadowType);
		if (light.shadowType != LightShadows.None) {
			EditorGUI.indentLevel = 1;
			light.shadowStrength = 1.0f - EditorGUILayout.Slider ("Shadow Strength", 1.0f - light.shadowStrength, 0f, 1f);
			light.shadowResolution = (PipLight.ShadowTextureSize)EditorGUILayout.EnumPopup ("Shadow Resolution", light.shadowResolution);
			light.shadowBias = 1.0f - EditorGUILayout.Slider ("Shadow Bias", 1.0f - light.shadowBias, 0f, 1f);
			light.updateMode = (PipLight.ShadowRefreshMode)EditorGUILayout.EnumPopup ("Shadow Refresh Mode", light.updateMode);
			light.levelOfDetailAggression = EditorGUILayout.FloatField ("Level of detail aggressiveness", light.levelOfDetailAggression);
			EditorGUI.indentLevel = 0;
		}
		light.cookie = (Texture)EditorGUILayout.ObjectField ("Cookie", light.cookie, typeof(Cubemap), true); 
		light.cullingMask = EditorGUILayout.MaskField ("Shadow casting layers", light.cullingMask, cullingLayers);
		EditorGUILayout.Space ();
		if (GUILayout.Button ("Refresh all shadows")) {
			PipLightRenderer.RefreshAll ();
		}
		GameObject.FindObjectOfType<PipLightRenderer> ().Refresh ();
	}

	[MenuItem("GameObject/Light/Pip Light")]
	static void CreatePipLight (MenuCommand menuCommand)
	{
		GameObject go = new GameObject ("Pip Light");
		go.AddComponent<PipLight> ();
		GameObjectUtility.SetParentAndAlign (go, menuCommand.context as GameObject);
		Undo.RegisterCreatedObjectUndo (go, "Create " + go.name);
		Selection.activeObject = go;
	}
}
