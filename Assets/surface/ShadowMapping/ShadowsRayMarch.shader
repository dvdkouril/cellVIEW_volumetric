Shader "Custom/ShadowsRayMarch"
{
	Properties
	{
		_ShadowMapTexture ("Shadow Map Texture", 2D) = "white" {}
		_VolumeTex ("Volume Texture", 3D) = "white" {}
		_VolumeSize("Volume Size", Int) = 0
		_Threshold("Intensity Threshold", Range(0, 1)) = 0.5
	}
	SubShader
	{

		Pass // First Pass that writes depth values from light POV into shadow map
		{
			CGPROGRAM
// Upgrade NOTE: excluded shader from DX11 and Xbox360; has structs without semantics (struct v2f members localPos,worldPos,viewRay)
#pragma exclude_renderers d3d11 xbox360
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float3 localPos;
				float3 worldPos;
				float3 viewRay;
			};
			
			sampler3D _VolumeTex;
			int _VolumeSize;
			float _Threshold;
			
			float sample_volume(float3 p) 
			{
				return tex3Dlod(_VolumeTex, float4(p, 0)).w;
			}

			float get_depth(float3 current_pos) 
			{
				float4 pos = mul(UNITY_MATRIX_MVP, float4(current_pos - 0.5, 1));
				return (pos.z / pos.w);
			}

			float3 get_normal(float3 position, float dataStep)
			{
				float dx = sample_volume(position + float3(dataStep, 0, 0)) - sample_volume(position + float3(-dataStep, 0, 0));
				float dy = sample_volume(position + float3(0, dataStep, 0)) - sample_volume(position + float3(0, -dataStep, 0));
				float dz = sample_volume(position + float3(0, 0, dataStep)) - sample_volume(position + float3(0, 0, -dataStep));

				return normalize(float3(dx, dy, dz));
			}
			
			v2f vert (appdata v)
			{
				v2f o;
				
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				o.localPos = v.vertex.xyz;
				o.worldPos = mul(_Object2World, v.vertex).xyz;
				o.viewRay = mul(_World2Object, float4(o.worldPos - _WorldSpaceCameraPos, 0)).xyz;
				
				//o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				// Get back position from vertex shader
				float3 front_pos = i.localPos;
				float3 view_dir = normalize(i.viewRay);
				float3 view_dir_inv = view_dir;

				// Find the front pos
				float3 t = max((0.5 - front_pos) / view_dir_inv, (-0.5 - front_pos) / view_dir_inv);
				float3 back_pos = front_pos + (min(t.x, min(t.y, t.z)) * view_dir_inv);

				// Offset to texture coordinates
				back_pos += 0.5;
				front_pos += 0.5;

				// Add noise
				float rand = frac(sin(dot(i.pos.xy, float2(12.9898, 78.233))) * 43758.5453);
				front_pos += view_dir * rand * 0.001;

				float3 last_pos;
				float3 current_pos = front_pos;

				float _NumSteps = 128;
				float delta_dir_length = 1 / _NumSteps;
				float3 delta_dir = view_dir * delta_dir_length;

				float length_acc = 0;
				float current_intensity = 0;
				float max_length = length(front_pos - back_pos);

				float _IntensityThreshold = _Threshold;

				// Linear search
				for (uint i = 0; i < _NumSteps; i++)
				{
					current_intensity = sample_volume(current_pos);
					if (current_intensity >= _IntensityThreshold) break;
					if (length_acc += delta_dir_length >= max_length) break;

					last_pos = current_pos;
					current_pos += delta_dir;
				}

				// If traversal fail discard pixel
				if (current_intensity < _IntensityThreshold) discard;

				delta_dir *= 0.5;
				current_pos = last_pos + delta_dir;

				// Binary search
				for (uint i = 0; i < 4; i++)
				{
					delta_dir *= 0.5;
					current_pos += (sample_volume(current_pos) >= _IntensityThreshold) ? -delta_dir : delta_dir;
				}

				float texelSize = 1.0f / _VolumeSize;
				float3 normal = get_normal(current_pos, texelSize);
				float ndotl = max(0.0, dot(view_dir, normal));

				float4 color = float4(0.9, 0, 0.5, 1) * ndotl;
				return color;
			
			}
			ENDCG
		}
		
		Pass // Second Pass that takes shadow maps values into account and renders shadows
		{
			CGPROGRAM
// Upgrade NOTE: excluded shader from DX11 and Xbox360; has structs without semantics (struct v2f members localPos,worldPos,viewRay)
#pragma exclude_renderers d3d11 xbox360
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float3 localPos;
				float3 worldPos;
				float3 viewRay;
			};
			
			sampler3D _VolumeTex;
			int _VolumeSize;
			float _Threshold;
			
			float sample_volume(float3 p) 
			{
				return tex3Dlod(_VolumeTex, float4(p, 0)).w;
			}

			float get_depth(float3 current_pos) 
			{
				float4 pos = mul(UNITY_MATRIX_MVP, float4(current_pos - 0.5, 1));
				return (pos.z / pos.w);
			}

			float3 get_normal(float3 position, float dataStep)
			{
				float dx = sample_volume(position + float3(dataStep, 0, 0)) - sample_volume(position + float3(-dataStep, 0, 0));
				float dy = sample_volume(position + float3(0, dataStep, 0)) - sample_volume(position + float3(0, -dataStep, 0));
				float dz = sample_volume(position + float3(0, 0, dataStep)) - sample_volume(position + float3(0, 0, -dataStep));

				return normalize(float3(dx, dy, dz));
			}
			
			v2f vert (appdata v)
			{
				v2f o;
				
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				o.localPos = v.vertex.xyz;
				o.worldPos = mul(_Object2World, v.vertex).xyz;
				o.viewRay = mul(_World2Object, float4(o.worldPos - _WorldSpaceCameraPos, 0)).xyz;
				
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				// Get back position from vertex shader
				float3 front_pos = i.localPos;
				float3 view_dir = normalize(i.viewRay);
				float3 view_dir_inv = view_dir;

				// Find the front pos
				float3 t = max((0.5 - front_pos) / view_dir_inv, (-0.5 - front_pos) / view_dir_inv);
				float3 back_pos = front_pos + (min(t.x, min(t.y, t.z)) * view_dir_inv);

				// Offset to texture coordinates
				back_pos += 0.5;
				front_pos += 0.5;

				// Add noise
				float rand = frac(sin(dot(i.pos.xy, float2(12.9898, 78.233))) * 43758.5453);
				front_pos += view_dir * rand * 0.001;

				float3 last_pos;
				float3 current_pos = front_pos;

				float _NumSteps = 128;
				float delta_dir_length = 1 / _NumSteps;
				float3 delta_dir = view_dir * delta_dir_length;

				float length_acc = 0;
				float current_intensity = 0;
				float max_length = length(front_pos - back_pos);

				float _IntensityThreshold = _Threshold;

				// Linear search
				for (uint i = 0; i < _NumSteps; i++)
				{
					current_intensity = sample_volume(current_pos);
					if (current_intensity >= _IntensityThreshold) break;
					if (length_acc += delta_dir_length >= max_length) break;

					last_pos = current_pos;
					current_pos += delta_dir;
				}

				// If traversal fail discard pixel
				if (current_intensity < _IntensityThreshold) discard;

				delta_dir *= 0.5;
				current_pos = last_pos + delta_dir;

				// Binary search
				for (uint i = 0; i < 4; i++)
				{
					delta_dir *= 0.5;
					current_pos += (sample_volume(current_pos) >= _IntensityThreshold) ? -delta_dir : delta_dir;
				}

				float texelSize = 1.0f / _VolumeSize;
				float3 normal = get_normal(current_pos, texelSize);
				float ndotl = max(0.0, dot(view_dir, normal));

				float4 color = float4(0.9, 0, 0.5, 1) * ndotl;
				return color;
			
				//fixed4 col = fixed4(0.321, 0.123, 0.321, 1);
				//return col;
			}
			ENDCG
		}
	}
}
