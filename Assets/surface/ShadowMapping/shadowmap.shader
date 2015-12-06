Shader "ShadowMap" 
{
	Properties 
	{
    	_ShadowMap ("ShadowMap", 2D) = "red"
		//_FarClip ("Far Plane", Float) = 5.5
		//_NearClip ("Near Plane", Float) = 0.3
	}
	
	SubShader 
	{
        Tags { "RenderType"="Opaque" }

		Pass
		{
			ZWrite On
			ZTest LEqual
			CGPROGRAM
			#pragma vertex 		ShadowMapVS
			#pragma fragment 	ShadowMapPS
			#pragma target 		3.0
            #include "UnityCG.cginc"
			
			// material components
			static float4 g_vecMaterialDiffuse = {1.0, 0.0, 0.0, 1.0};
			static float4 g_vecMaterialAmbient = {1.0, 0.0, 0.0, 1.0};

			// light components
			static float4 g_vecLightDiffuse = {0.2, 0.2, 0.2, 1.0};
			static float4 g_vecLightAmbient = {0.2, 0.2, 0.2, 1.0};

			static float3 g_vecLightPos = {0.0, 5.0, 0.0};
			static float3 g_vecLightDir = {0.0, 1.0, 0.0};

			// shadow map components
			uniform sampler2D_float _ShadowMap;
			static float _TexSize = 2048;
			static float _Bias = 0.012;
			uniform float4x4  _ProjMatrix;
			uniform float4x4  _LightViewMatrix;
			/*static */float _FarClip;/* = 5.5*/;
			/*static */float _NearClip;/* = 0.3*/;
			
			// vertex input structure used by both techniques
			struct VSInput
			{
				float3 pos: POSITION0;
				float3 norm: NORMAL0;
				float2 tex: TEXCOORD0;
			};

			// vertex output structure used by ShadowMap technique
			struct VSOutput
			{
				float4 pos: SV_POSITION;
				float4 col: COLOR0;
				float4 projTex: TEXCOORD1;
				float eyeDepth: FLOAT0;
			};

			VSOutput ShadowMapVS(VSInput a_Input)
			{
				VSOutput Output;

				// calculate vertex position homogenous
				Output.pos = mul(UNITY_MATRIX_MVP, float4(a_Input.pos, 1.0f));

				// calculate vertex normal
				float3 normal = normalize(mul(transpose(_World2Object), float4(a_Input.norm, 0.0f)).xyz);

				// calculate diffuse variable
				float diffComp = max(dot(g_vecLightDir, normal), 0.0f);

				// calculate the two components
				float3 diffuse = diffComp * (g_vecLightDiffuse * g_vecMaterialDiffuse).rgb;
				float3 ambient = g_vecLightAmbient * g_vecMaterialAmbient;

				// combine and output colour
				Output.col = float4(diffuse + ambient, g_vecMaterialAmbient.a);

				float4 posWorld = mul(_Object2World, float4(a_Input.pos, 1.0f));
				float4 temp = mul(_LightViewMatrix, posWorld);
				Output.eyeDepth = abs(temp.z);

				Output.projTex = mul(_ProjMatrix, posWorld);

				return Output;
			}

			// Custom texture lookup functions from http://codeflow.org/entries/2013/feb/15/soft-shadow-mapping/
			float texture2DCompare(sampler2D depths, float2 uv, float compare){
				float depth = tex2D(depths, uv).r;
				//return step(compare, depth + 0.1);
				return clamp(step(compare, depth + 0.1) + 0.5, 0, 1);
			}

			float PCF(sampler2D depths, float2 size, float2 uv, float compare) {
				float result = 0.0;
				for(int x=-8; x<=8; x++){
					for(int y=-8; y<=8; y++){
						float2 off = float2(x,y)/size;
						result += texture2DCompare(depths, uv+off, compare);
					}
				}
				return result/289.0;
			}

			// this function is based on Microsoft's function of the same purpose in their ShadowMapping example
			float4 ShadowMapPS(VSOutput a_Input) : COLOR
			{						
				// transform coordinates into texture coordinates
				a_Input.projTex.xy /= a_Input.projTex.w;            
				a_Input.projTex.x = 0.5 * a_Input.projTex.x + 0.5f; 
				a_Input.projTex.y = 0.5 * a_Input.projTex.y + 0.5f;
				
				float shMapDepth = tex2D(_ShadowMap, a_Input.projTex.xy);

				// Transform to texel space
			    float2 texelpos = _TexSize * a_Input.projTex.xy;
			        
			    // Determine the lerp amounts.           
			    float2 lerps = frac( texelpos );

			    // sample shadow map
			    float dx = 1.0f / _TexSize;
				float s0 = (tex2D(_ShadowMap, a_Input.projTex.xy) + _Bias < a_Input.eyeDepth) ? 0.0f : 1.0f;
				float s1 = (tex2D(_ShadowMap, a_Input.projTex.xy + float2(dx, 0.0f)) + _Bias < a_Input.eyeDepth) ? 0.0f : 1.0f;
				float s2 = (tex2D(_ShadowMap, a_Input.projTex.xy + float2(0.0f, dx)) + _Bias  < a_Input.eyeDepth) ? 0.0f : 1.0f;
				float s3 = (tex2D(_ShadowMap, a_Input.projTex.xy + float2(dx, dx)) + _Bias  < a_Input.eyeDepth) ? 0.0f : 1.0f;
				
				//float shadowCoeff = lerp( lerp( s0, s1, lerps.x ), lerp( s2, s3, lerps.x ), lerps.y );

				float shadowCoeff = PCF(_ShadowMap, _TexSize, a_Input.projTex.xy, a_Input.eyeDepth);
				
				// output colour multipled by shadow value
				return float4(shadowCoeff * a_Input.col.rgb, g_vecMaterialDiffuse.a);
			}
		
		ENDCG
		}
	}
	Fallback "Diffuse"
	//Fallback Off 
}
