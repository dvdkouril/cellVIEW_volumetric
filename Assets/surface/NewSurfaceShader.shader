Shader "Custom/NewSurfaceShader" {
	Properties {
		_VolumeTex("Volume Texture", 3D) = "" {}
		_VolumeSize("Volume Size", Int) = 0
		_Threshold("Intensity Threshold", Range(0, 1)) = 0.5
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
			//Tags { "RenderType" = "Deferred" }
			//Tags{ "LightMode" = "ShadowCaster" }
		LOD 200
		
		CGPROGRAM
		#pragma surface surf Lambert finalcolor:my_frag vertex:my_vertex
		//#pragma surface surf Lambert finalcolor:my_frag
		//#pragma surface surf Lambert

		#pragma target 3.0

#include "UnityCG.cginc"
#include "AutoLight.cginc"

		sampler3D _VolumeTex;
		int _VolumeSize;
		float _Threshold;

		struct Input {
			float4 pos : COLOR0;
			float3 viewRay;
			float3 worldPos;
			float3 localPos;
			//LIGHTING_COORDS(0,1)  // trying to do shadows...
			/*float4 pos : SV_POSITION;
			float3 viewRay : COLOR0;
			float3 worldPos : COLOR1;
			float3 localPos : COLOR2;*/

		};

		float sample_volume(float3 p)
		{
			return tex3Dlod(_VolumeTex, float4(p, 0)).a;
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

		void my_vertex(inout appdata_full v, out Input o) {
			UNITY_INITIALIZE_OUTPUT(Input, o);

			o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
			o.localPos = v.vertex.xyz;
			o.worldPos = mul(_Object2World, v.vertex).xyz;
			//o.viewRay = mul(_World2Object, o.worldPos - _WorldSpaceCameraPos);
			o.viewRay = mul(_World2Object, float4(o.worldPos - _WorldSpaceCameraPos, 0)).xyz;

			//TRANSFER_VERTEX_TO_FRAGMENT(o); // shadows
		}



		void my_frag(Input IN, SurfaceOutput o, inout fixed4 color) {
			// G-Buffer access????!!
			//sampler2D whatever = CameraGBufferTexture0;


			// Get back position from vertex shader
			float3 front_pos = IN.localPos;
			float3 view_dir = normalize(IN.viewRay);
			float3 view_dir_inv = view_dir;

			// Find the front pos
			float3 t = max((0.5 - front_pos) / view_dir_inv, (-0.5 - front_pos) / view_dir_inv);
			float3 back_pos = front_pos + (min(t.x, min(t.y, t.z)) * view_dir_inv);

			// Offset to texture coordinates
			back_pos += 0.5;
			front_pos += 0.5;

			// Add noise
			float rand = frac(sin(dot(IN.pos.xy, float2(12.9898, 78.233))) * 43758.5453);
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

			color = float4(1, 0, 0, 1);
			//depth = get_depth(current_pos);
		}

		void surf (Input IN, inout SurfaceOutput o) 
		{
			// Albedo comes from a texture tinted by color
			//fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			//fixed4 c = fixed4(1,1,1,1);
			o.Albedo = fixed3(1,1,1);
			//o.Albedo = c.rgb;
			// Metallic and smoothness come from slider variables
			//o.Metallic = _Metallic;
			//o.Smoothness = _Glossiness;
			//o.Alpha = c.a;
		}
		ENDCG
	} 
	//Fallback "VertexLit"
	Fallback "Diffuse"
}
