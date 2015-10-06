Shader "Custom/RayMarchVolume"
{
	Properties
	{
		_MipLevel("Mip Level", Int) = 0
		_GridSize("Grid Size", Int) = 0
		_VolumeTex("Volume Texture", 3D) = "" {}
		_NumRayStepMax("_Num Ray Step Max", Int) = 32
		_Threshold("Intensity Threshold", Range(0, 1)) = 0.5
	}

		CGINCLUDE

#include "UnityCG.cginc"
#pragma target 5.0

	int _GridSize;
	int _MipLevel;
	int _NumRayStepMax;
	float _Threshold;
	sampler3D _VolumeTex;

	matrix Identity =
	{
		{ 1, 0, 0, 0 },
		{ 0, 1, 0, 0 },
		{ 0, 0, 1, 0 },
		{ 0, 0, 0, 1 }
	};

	uniform	StructuredBuffer<int> _CubeIndices;
	uniform	StructuredBuffer<float3> _CubeVertices;
	uniform	StructuredBuffer<float4x4> _CubeMatrices;

	struct v2f
	{		
		int discardInstance : INT0;
		float3 viewDir : C0LOR0;
		float3 objectPos : C0LOR1;
		centroid float4 pos : SV_POSITION;
		float4x4 modelMatrix : world;
	};

	//v2f vert(uint vertexId : SV_VertexID)
	v2f vert(uint id : SV_VertexID, uint instanceId : SV_InstanceID)
	{
		/*uint id = vertexId % 36;
		uint instanceId = vertexId / 36;*/

		float4x4 modelMatrix = _CubeMatrices[instanceId];
		float4x4 modelMatrixInv = transpose(modelMatrix);

		float3 objectPos = _CubeVertices[_CubeIndices[id]] ;
		float4 worldPos = mul(modelMatrix, float4(objectPos,1));
		float4 instancePos = mul(modelMatrix, float4(0,0,0, 1));
		
		v2f output;
		output.discardInstance = 0;
		if(instancePos.x < 0 ) output.discardInstance = 1;
		output.objectPos = objectPos;
		output.viewDir = mul(modelMatrixInv, worldPos - _WorldSpaceCameraPos);
		output.pos = mul(UNITY_MATRIX_VP, worldPos);
		output.modelMatrix = modelMatrix;
		return output;
	}

	/*float2 getDimenstions(Texture2D textureObj)
	{
		uint width;
		uint height;
		textureObj.GetDimensions(width, height);
		return float2(width, height);
	}*/	

	float sampleVolume(float3 p)
	{
		//return tex3Dlod(_VolumeTex, float4(p,0)).r;
		return tex3Dlod(_VolumeTex, float4(p, 0)).a;
	}

	float sampleVolumeMip(float3 p, int mipLevel)
	{
		//return tex3Dlod(_VolumeTex, float4(p,0)).r;
		return tex3Dlod(_VolumeTex, float4(p, mipLevel)).a;
	}

	float getDepth(float3 current_pos)
	{
		float4 pos = mul(UNITY_MATRIX_VP, float4(current_pos, 1));
		return (pos.z / pos.w);
	}

	float3 getNormal(float3 position, float dataStep)
	{
		float dx = sampleVolume(position + float3(dataStep, 0, 0)) - sampleVolume(position + float3(-dataStep, 0, 0));
		float dy = sampleVolume(position + float3(0, dataStep, 0)) - sampleVolume(position + float3(0, -dataStep, 0));
		float dz = sampleVolume(position + float3(0, 0, dataStep)) - sampleVolume(position + float3(0, 0, -dataStep));

		return normalize(float3(dx, dy, dz));
	}
	

	//void frag_surf_opaque(v2f input, out float4 color : COLOR0, out float depth : DEPTH)
	void frag_surf_opaque(v2f input, out float4 color : COLOR0, out float depth : SV_DepthGreaterEqual)
	//void frag_surf_opaque(v2f input, out float4 color : COLOR0, out float depth : SV_DepthLessEqual)
	{
		color = float4(0.25, 0.25, 0.25, 1);
		depth = input.pos.z;
		
		if (input.discardInstance == 1) discard;

		float numSteps = _NumRayStepMax;
		float rayStepLength = 1 / numSteps;

		// Get ray values
		float3 rayDir = normalize(input.viewDir);
		float3 rayStep = rayDir * rayStepLength;
		
		// Find the ray start
		/*float3 rayEnd = input.objectPos;
		float3 t = max((0.5 - rayEnd) / -rayDir, (-0.5 - rayEnd) / -rayDir);
		float3 rayStart = rayEnd + (min(t.x, min(t.y, t.z)) * -rayDir);*/

		// Find the ray end
		float3 rayStart = input.objectPos;
		float3 t = max((0.5 - rayStart) / rayDir, (-0.5 - rayStart) / rayDir);
		float3 rayEnd = rayStart + (min(t.x, min(t.y, t.z)) * rayDir);

		// Add noise
		float rand = frac(sin(dot(input.pos.xy, float2(12.9898, 78.233))) * 43758.5453);
		rayStart += rayDir * rand * 0.01;

		// Offset to texture coordinates
		rayEnd += 0.5;
		rayStart += 0.5;

		float rayLengthMax = distance(rayStart, rayEnd);
		uint rayNumSteps = max(min(rayLengthMax / rayStepLength, _NumRayStepMax), 0);
				
		
		// Init ray values
		float currentIntensity = 0;
		float3 currentRayPos = rayStart;
		float intensityThreshold = _Threshold;

		int currentNumSteps = 0;
				
		//int stepScale = 1;

		//// Mip search
		//for (; currentNumSteps < rayNumSteps; currentNumSteps+= stepScale)
		//{
		//	currentIntensity = sampleVolumeMip(currentRayPos, 1);
		//	if (currentIntensity > 0) break;
		//	currentRayPos += rayStep *stepScale;
		//}

		//if (currentIntensity <= 0) discard;

		//// Restore previous step
		//currentRayPos -= rayStep * stepScale;
		////currentNumSteps -= stepScale * 5;
		
		// Linear search
		for(;currentNumSteps < rayNumSteps; currentNumSteps++)
		{
			currentIntensity = sampleVolumeMip(currentRayPos, _MipLevel);
			if(currentIntensity >= intensityThreshold) break;			
			currentRayPos += rayStep;
		}
		
		// If traversal fail discard pixel
		if (currentIntensity < intensityThreshold) discard;
		
		rayStep *= 0.5;
		currentRayPos -= rayStep;

		// Binary search
		for (uint j = 0; j < 4; j++)
		{
			rayStep *= 0.5;
			currentIntensity = sampleVolumeMip(currentRayPos, _MipLevel);
			currentRayPos += (currentIntensity >= intensityThreshold) ? -rayStep : rayStep;
		}

		float texelSize = 1.0f / _GridSize;
		float3 normal = getNormal(currentRayPos, texelSize);
		float ndotl = pow(max(0.0, dot(rayDir, normal)), 0.4);

		float3 currentWorldPos = mul(input.modelMatrix, float4(currentRayPos - 0.5, 1));
		depth = getDepth(currentWorldPos);
		color = float4(float3(1, 1, 1) * ndotl, 1);
	}

	ENDCG

	Subshader
	{
		ZTest LEqual
		ZWrite On
		Cull Back
		//Cull Front

		Pass
	{
		CGPROGRAM
#pragma vertex vert		
#pragma fragment frag_surf_opaque		
		ENDCG
	}
	}

		Fallback off
}
