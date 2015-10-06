using UnityEngine;
public class Utility
{
    //public static ComputeShader GetComputeShader(string resourcePath)
    //{
        

    //    //string myPath = "Assets/Resources/Compute Shaders";
    //    //DirectoryInfo dir = new DirectoryInfo(myPath);
    //    //FileInfo[] info = dir.GetFiles("*.*");
    //    //foreach (FileInfo f in info)
    //    //{
    //    //    if (f.Extension == ".compute")
    //    //    {
    //    //        string name = Path.GetFileNameWithoutExtension(f.Name);

    //    //        if (shaderName == name)
    //    //        {
    //    //            var computeShader = Resources.Load("Compute Shaders/" + f.Name) as ComputeShader;
    //    //            Debug.Log(computeShader.name);
    //    //            return computeShader;
    //    //        }
    //    //    }
    //    //}

    //    //throw new Exception("Compute Shader file not found");
    //}

    public static void CreateDistanceField(ref RenderTexture distanceFieldRT, string pdbName, int gridSize)
    {
       
    }

    public static void SaveRenderTextureToTexture(RenderTexture volumeTexture)
    {
        //var width = volumeTexture.width;
        //var size = width * width * width;
        //var voxelGPUBuffer = new ComputeBuffer(size, sizeof(float), ComputeBufferType.Default);

        //var readVoxelsCS = Resources.Load("Compute Shaders/ReadVoxels") as ComputeShader;
        //readVoxelsCS.SetInt("_VolumeSize", width);
        //readVoxelsCS.SetBuffer(0, "_VoxelBuffer", voxelGPUBuffer);
        //readVoxelsCS.SetTexture(0, "_VolumeTexture", volumeTexture);
        //readVoxelsCS.Dispatch(0, volumeTexture.width, volumeTexture.height, volumeTexture.volumeDepth);

        //var voxelCPUBuffer = new float[volumeTexture.width * volumeTexture.width * volumeTexture.width];
        //voxelGPUBuffer.GetData(voxelCPUBuffer);

        //var volumeColors = new Color[size];
        //for (int i = 0; i < size; i++)
        //{
        //    volumeColors[i] = new Color(voxelCPUBuffer[i], 0,0,0);
        //}

        //var texture3D = new Texture3D(volumeTexture.width, volumeTexture.width, volumeTexture.width, TextureFormat.Alpha8, true);
        //texture3D.SetPixels(volumeColors);
        //texture3D.wrapMode = TextureWrapMode.Clamp;
        //texture3D.anisoLevel = 0;
        //texture3D.Apply();

        //string path = "Assets/"+volumeTexture.name+".asset";

        //Texture3D tmp = (Texture3D)AssetDatabase.LoadAssetAtPath(path, typeof(Texture3D));
        //if (tmp)
        //{
        //    AssetDatabase.DeleteAsset(path);
        //    tmp = null;
        //}

        //AssetDatabase.CreateAsset(texture3D, path);
        //AssetDatabase.SaveAssets();

        //// Print the path of the created asset
        //Debug.Log(AssetDatabase.GetAssetPath(texture3D));

        //voxelGPUBuffer.Release();
    }
}
