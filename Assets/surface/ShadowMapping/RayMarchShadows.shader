Shader "MoleculesShadows/RayMarchShadows"
{
	Properties
	{
		_VolumeTex("Volume Texture", 3D) = "" {}
		_VolumeSize("Volume Size", Int) = 0
		_Threshold("Intensity Threshold", Range(0, 1)) = 0.5

		// Shadow Mapping
		_ShadowMap("Shadow Map", 2D) = "red" {}
		_ShadowIntensity("Shadow Intensity", Range(0, 1)) = 0.5
		_MoleculeColor("Molecule Color", Color) = (1.0, 1.0, 0.0, 1.0)
		//_FarClip ("Far Plane", Float) = 5.5
		//_NearClip ("Near Plane", Float) = 0.3
	}
	SubShader
	{
		Tags {"RenderType" = "Opaque"/* "Queue" = "Geometry"*/ }
		//Tags { "" }
		//LOD 100

		Pass
		{
			ZWrite On
			ZTest LEqual
			CGPROGRAM
			#pragma enable_d3d11_debug_symbols
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 pos		: SV_POSITION;
				float3 localPos : COLOR0;
				float3 worldPos : COLOR1;
				float3 viewRay	: COLOR2;
				//shadow mapping
				float4 projTex: TEXCOORD0;
			};
			
			sampler3D _VolumeTex;
			int _VolumeSize;
			float _Threshold;

			// shadow map components
			uniform sampler2D_float _ShadowMap;
			static float _TexSize = 2048;
			static float _Bias = 0.1;
			uniform float4x4  _ProjMatrix;
			uniform float4x4  _LightViewMatrix;
			static float _FarClip = 5.5;
			static float _NearClip = 0.3;
			float _ShadowIntensity;
			float4 _MoleculeColor;
			
			float sample_volume(float3 p) 
			{
				return tex3Dlod(_VolumeTex, float4(p, 0)).w;
			}

			float get_depth(float3 current_pos) 
			{
				float4 pos = mul(UNITY_MATRIX_MVP, float4(current_pos - 0.5, 1));
				//float4 pos = float4(current_pos, 1);
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
				
				// shadow mapping
				o.projTex = mul(_ProjMatrix, float4(o.worldPos, 1)); // I think that I need to do this translation in fragment shader after I have the
																	 // exact position of fragment (this one is texture coordinate of point "on cube")
				return o;
			}

			struct fout {
				float4 color : SV_Target;
				float depth : SV_Depth;
			};

			// Custom texture lookup functions from http://codeflow.org/entries/2013/feb/15/soft-shadow-mapping/
			float texture2DCompare(sampler2D depths, float2 uv, float compare){
				float depth = tex2D(depths, uv).r;
				//return step(compare, depth + 0.1);
				return clamp(step(compare, depth + 0.1) + _ShadowIntensity, 0, 1); // clam is used because I want to use _ShadowIntensity as the "low value" of step
			}

			float texture2DShadowLerp(sampler2D depths, float2 size, float2 uv, float compare){
				float2 texelSize = float2(1.0,1.0)/size;
				float2 f = frac(uv*size+0.5);
				float2 centroidUV = floor(uv*size+0.5)/size;

				float lb = texture2DCompare(depths, centroidUV+texelSize*float2(0.0, 0.0), compare);
				float lt = texture2DCompare(depths, centroidUV+texelSize*float2(0.0, 1.0), compare);
				float rb = texture2DCompare(depths, centroidUV+texelSize*float2(1.0, 0.0), compare);
				float rt = texture2DCompare(depths, centroidUV+texelSize*float2(1.0, 1.0), compare);
			    float a = lerp(lb, lt, f.y);
				float b = lerp(rb, rt, f.y);
				float c = lerp(a, b, f.x);
				return c;
			}

			float PCF(sampler2D depths, float2 size, float2 uv, float compare) {
				float result = 0.0;
				int neighbourhood = 4;
				for(int x=-neighbourhood; x<=neighbourhood; x++){
					for(int y=-neighbourhood; y<=neighbourhood; y++){
						float2 off = float2(x,y)/size;
						//result += texture2DCompare(depths, uv+off, compare);
						result += texture2DShadowLerp(depths, size, uv+off, compare);
					}
				}
				return result / ((float)(2*neighbourhood+1)*(2*neighbourhood+1));
				//return result/289.0;
			}
			
			fout frag (in v2f i)
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
				for (uint k = 0; k < _NumSteps; k++)
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
				for (uint j = 0; j < 4; j++)
				{
					delta_dir *= 0.5;
					current_pos += (sample_volume(current_pos) >= _IntensityThreshold) ? -delta_dir : delta_dir;
				}

				float texelSize = 1.0f / _VolumeSize;
				float3 normal = get_normal(current_pos, texelSize);
				float ndotl = max(0.0, dot(view_dir, normal));

				// ------ SHADOW MAPPING ------

				float4 projTex = mul(_ProjMatrix, mul(_Object2World, float4(current_pos - 0.5, 1)));
				float4 temp = mul(_LightViewMatrix, mul(_Object2World, float4(current_pos - 0.5, 1))); 
				float eyeDepth = abs(temp.z);

				projTex.xy /= projTex.w;            
				projTex.x = 0.5 * projTex.x + 0.5f; 
				projTex.y = 0.5 * projTex.y + 0.5f;

				float depthOut = get_depth(current_pos);
				float depth = projTex.z / projTex.w; // depth of a current fragment
				
				//float shMapDepth = tex2D(_ShadowMap, projTex.xy); // sampling depth from the shadow map, not used anymore

				//float shadowCoeff = PCF(_ShadowMap, _TexSize, projTex.xy, eyeDepth);

				// Transform to texel space
			    float2 texelpos = _TexSize * projTex.xy;  
			    // Determine the lerp amounts.           
			    float2 lerps = frac( texelpos );
				float inShadow = 0.0f;

			    // sample shadow map - NOT USED
			    float dx = 1.0f / _TexSize;
				float s0 = (tex2D(_ShadowMap, projTex.xy) + _Bias < eyeDepth) ? inShadow : 1.0f;
				float s1 = (tex2D(_ShadowMap, projTex.xy + float2(dx, 0.0f)) + _Bias < eyeDepth) ? inShadow : 1.0f;
				float s2 = (tex2D(_ShadowMap, projTex.xy + float2(0.0f, dx)) + _Bias  < eyeDepth) ? inShadow : 1.0f;
				float s3 = (tex2D(_ShadowMap, projTex.xy + float2(dx, dx)) + _Bias  < eyeDepth) ? inShadow : 1.0f;

				//float shadowCoeff = lerp( lerp( s0, s1, lerps.x ), lerp( s2, s3, lerps.x ), lerps.y );

				float shadowCoeff = PCF(_ShadowMap, _TexSize, projTex.xy, eyeDepth);

				fout fo; 
				//fo.color = float4(shadowCoeff * float3(1,1,1) * ndotl, 1);
				fo.color = float4(shadowCoeff * _MoleculeColor.rgb * ndotl, 1);
				fo.depth = depthOut;

				return fo;
			
			}
			ENDCG
		}

		// --------------------------------------------------------------------------------------------------------------------------------------
		// ShadowCaster Pass
		// --------------------------------------------------------------------------------------------------------------------------------------
		Pass
		{ // This pass is needed because Camera's depth texture is rendered using the ShadowCaster pass
			Tags {"LightMode" = "ShadowCaster"}
			ZWrite On
			ZTest LEqual
			CGPROGRAM
			#pragma enable_d3d11_debug_symbols
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 pos		: SV_POSITION;
				float3 localPos : COLOR0;
				float3 worldPos : COLOR1;
				float3 viewRay	: COLOR2;
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
				//float4 pos = float4(current_pos, 1);
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

			struct fout {
				float4 color : SV_Target;
				float depth : SV_Depth;
			};
			
			fout frag (in v2f i)
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
				for (uint k = 0; k < _NumSteps; k++)
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
				for (uint j = 0; j < 4; j++)
				{
					delta_dir *= 0.5;
					current_pos += (sample_volume(current_pos) >= _IntensityThreshold) ? -delta_dir : delta_dir;
				}

				float texelSize = 1.0f / _VolumeSize;
				float3 normal = get_normal(current_pos, texelSize);
				float ndotl = max(0.0, dot(view_dir, normal));

				fout fo;
				float depth = get_depth(current_pos);
				fo.color = float4(float3(1,1,1)*ndotl, 1);
				fo.depth = depth;

				return fo;
			
			}
			ENDCG
		}

	}
	//Fallback "Diffuse"
	Fallback Off
}
