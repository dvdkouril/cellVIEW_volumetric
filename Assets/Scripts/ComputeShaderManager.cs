//using System;
//using System.Collections.Generic;
//using System.IO;
//using System.Linq;
//using UnityEngine;

//[ExecuteInEditMode]
//public class ComputeShaderManager : MonoBehaviour
//{
//    private List<ComputeShader> _computeShaders = new List<ComputeShader>();

//    // Declare the shader manager as a singleton
//    private static ComputeShaderManager _instance = null;
//    public static ComputeShaderManager Instance
//    {
//        get
//        {
//            if (_instance == null)
//            {
//                _instance = FindObjectOfType<ComputeShaderManager>();
//                if (_instance == null)
//                {
//                    var go = GameObject.Find("_ComputeShaderManager");
//                    if (go != null)
//                        DestroyImmediate(go);

//                    go = new GameObject("_ComputeShaderManager"); // { hideFlags = HideFlags.HideInInspector };
//                    _instance = go.AddComponent<ComputeShaderManager>();
//                }
//            }

//            return _instance;
//        }
//    }

//    void OnEnable()
//    {
//        LoadShaders();
//    }

//    void LoadShaders()
//    {
//        _computeShaders.Clear();

//        string myPath = "Assets/Resources/Compute Shaders";
//        DirectoryInfo dir = new DirectoryInfo(myPath);
//        FileInfo[] info = dir.GetFiles("*.*");
//        foreach (FileInfo f in info)
//        {
//            if (f.Extension == ".compute")
//            {
//                string name = Path.GetFileNameWithoutExtension(f.Name);
//                var computeShader = Resources.Load("Compute Shaders/" + name) as ComputeShader;
//                _computeShaders.Add(computeShader);
//            }
//        }
//    }

//    public ComputeShader GetComputeShader(string shaderName)
//    {
//        foreach (var shader in _computeShaders.Where(shader => shader.name == shaderName))
//        {
//            return shader;
//        }

//        LoadShaders();

//        foreach (var shader in _computeShaders.Where(shader => shader.name == shaderName))
//        {
//            return shader;
//        }

//        throw new Exception("Compute shader not found in the resources folder");
//    }
//}