
using UnityEditor;
using UnityEngine;

[ExecuteInEditMode]
public class RenderScene : MonoBehaviour
{
    [Range(0.1f, 1)]
    public float Threshold = 0.1f;

    [Range(10, 200)]
    public int NumRayStepMax = 10;

    [Range(0, 4)]
    public int MipLevel;

    public Mesh CubeMesh;
    public Material DistanceFieldMaterial;

    /*****/

    private ComputeBuffer cubeIndices;
    private ComputeBuffer cubeVertices;
    private ComputeBuffer cubeMatrices;

    /*****/

    public Texture3D _volumeTexture;

    /*****/

    public int _numInstances = 2500;

    /*****/

    private void CreateDistanceField()
    {
        var size = 128;
        var pdbName = "MA_matrix_G1";
        string path = "Assets/Resources/3D Textures/" + pdbName + ".asset";

        Texture3D tmp = (Texture3D)AssetDatabase.LoadAssetAtPath(path, typeof(Texture3D));

        if (tmp)
        {
            _volumeTexture = tmp;
        }
        else
        {
            RenderTexture _distanceFieldRT;

            _distanceFieldRT = new RenderTexture(size, size, 0, RenderTextureFormat.R8);
            _distanceFieldRT.volumeDepth = size;
            _distanceFieldRT.isVolume = true;
            _distanceFieldRT.isPowerOfTwo = true;
            _distanceFieldRT.enableRandomWrite = true;
            _distanceFieldRT.filterMode = FilterMode.Trilinear;
            _distanceFieldRT.name = pdbName;
            _distanceFieldRT.hideFlags = HideFlags.HideAndDontSave;
            _distanceFieldRT.generateMips = true;
            _distanceFieldRT.useMipMap = true;
            _distanceFieldRT.Create();

            var atomSpheres = PdbLoader.LoadAtomSpheres(pdbName);
            var atomSphereGPUBuffer = new ComputeBuffer(atomSpheres.Count, sizeof(float) * 4, ComputeBufferType.Default);
            atomSphereGPUBuffer.SetData(atomSpheres.ToArray());

            Graphics.SetRenderTarget(_distanceFieldRT);
            GL.Clear(true, true, new Color(0, 0, 0));

            var createDistanceFieldCS = Resources.Load("Compute Shaders/CreateDistanceField") as ComputeShader;
            createDistanceFieldCS.SetInt("_GridSize", size);
            createDistanceFieldCS.SetInt("_NumAtoms", atomSpheres.Count);
            createDistanceFieldCS.SetBuffer(0, "_SpherePositions", atomSphereGPUBuffer);
            createDistanceFieldCS.SetTexture(0, "_VolumeTexture", _distanceFieldRT);
            createDistanceFieldCS.Dispatch(0, Mathf.CeilToInt(size / 10.0f), Mathf.CeilToInt(size / 10.0f), Mathf.CeilToInt(size / 10.0f));
                       
            atomSphereGPUBuffer.Release();
            
            //****
            
            var flatSize = size * size * size;
            var voxelGPUBuffer = new ComputeBuffer(flatSize, sizeof(float));

            var readVoxelsCS = Resources.Load("Compute Shaders/ReadVoxels") as ComputeShader;
            readVoxelsCS.SetInt("_VolumeSize", size);
            readVoxelsCS.SetBuffer(0, "_VoxelBuffer", voxelGPUBuffer);
            readVoxelsCS.SetTexture(0, "_VolumeTexture", _distanceFieldRT);
            readVoxelsCS.Dispatch(0, size, size, size);

            var voxelCPUBuffer = new float[flatSize];
            voxelGPUBuffer.GetData(voxelCPUBuffer);
                        
            var volumeColors = new Color[flatSize];
            for (int i = 0; i < flatSize; i++)
            {
                volumeColors[i] = new Color(0, 0, 0, voxelCPUBuffer[i]);
            }

            var texture3D = new Texture3D(size, size, size, TextureFormat.Alpha8, true);
            texture3D.SetPixels(volumeColors);
            texture3D.wrapMode = TextureWrapMode.Clamp;
            texture3D.anisoLevel = 0;
            texture3D.Apply();

            AssetDatabase.CreateAsset(texture3D, path);
            AssetDatabase.SaveAssets();

            // Print the path of the created asset
            Debug.Log(AssetDatabase.GetAssetPath(texture3D));

            voxelGPUBuffer.Release();

            _distanceFieldRT.Release();
            DestroyImmediate(_distanceFieldRT);

            _volumeTexture = texture3D;
        }
    }

    void OnEnable()
    {
        var vertices = CubeMesh.vertices;
        var indices = CubeMesh.triangles;
        var matrices = new Matrix4x4[_numInstances];

        for (int i = 0; i < _numInstances; i++)
        {
            float scale = 0.8f;
            Vector3 pos = Random.insideUnitSphere * 10;
            matrices[i] = Matrix4x4.TRS(pos, Random.rotationUniform, new Vector3(scale, scale, scale));
        }

        cubeIndices = new ComputeBuffer(indices.Length, sizeof(int));
        cubeVertices = new ComputeBuffer(vertices.Length, 3 * sizeof(float));
        cubeMatrices = new ComputeBuffer(_numInstances, 16 * sizeof(float));

        cubeIndices.SetData(indices);
        cubeVertices.SetData(vertices);
        cubeMatrices.SetData(matrices);
    }
    
    private void OnDisable()
    {
        if (cubeIndices != null) cubeIndices.Release();
        if (cubeVertices != null) cubeVertices.Release();
        if (cubeMatrices != null) cubeMatrices.Release();
    }

    [ImageEffectOpaque]
    private void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        if (_volumeTexture == null)
        {
            CreateDistanceField();
        } 

        var colorBuffer = RenderTexture.GetTemporary(src.width, src.height, 0, RenderTextureFormat.ARGB32);
        var depthBuffer = RenderTexture.GetTemporary(src.width, dst.height, 24, RenderTextureFormat.Depth);

        Graphics.SetRenderTarget(colorBuffer.colorBuffer, depthBuffer.depthBuffer);
        GL.Clear(true, true, new Color(0, 0, 0, 0));

        Graphics.Blit(src, colorBuffer);
        
        // Render volume
        Graphics.SetRenderTarget(colorBuffer.colorBuffer, depthBuffer.depthBuffer);
                
        DistanceFieldMaterial.SetFloat("_Threshold", Threshold);
        DistanceFieldMaterial.SetFloat("_NumRayStepMax", NumRayStepMax);
        DistanceFieldMaterial.SetInt("_GridSize", _volumeTexture.width);
        DistanceFieldMaterial.SetInt("_MipLevel", MipLevel);
        DistanceFieldMaterial.SetTexture("_VolumeTex", _volumeTexture);

        DistanceFieldMaterial.SetBuffer("_CubeIndices", cubeIndices);
        DistanceFieldMaterial.SetBuffer("_CubeVertices", cubeVertices);
        DistanceFieldMaterial.SetBuffer("_CubeMatrices", cubeMatrices);

        DistanceFieldMaterial.SetPass(0);
        
        Graphics.DrawProcedural(MeshTopology.Triangles, cubeIndices.count, _numInstances);

        Graphics.Blit(colorBuffer, dst);
        Shader.SetGlobalTexture("_CameraDepthTexture", depthBuffer);

        RenderTexture.ReleaseTemporary(colorBuffer);
        RenderTexture.ReleaseTemporary(depthBuffer);
    }

}