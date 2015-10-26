Shader "PipLight/Light" {
	SubShader{
		Tags{ "Queue" = "Transparent-1" }
		Pass{
			ZWrite Off
			ZTest Always
			Blend One One
			Cull Front

			CGPROGRAM
				#pragma multi_compile POINT POINT_COOKIE
				#pragma shader_feature SHADOWS_CUBE
				#pragma shader_feature SHADOWS_SOFT
				
				#define PIP_RANGE_DISCARD
				#define PIP_SHADOW_DISCARD
				
				#pragma target 3.0
				#pragma vertex vert_deferred
				#pragma fragment frag
				#pragma exclude_renderers nomrt
	
				#include "UnityPBSLighting.cginc"
				#include "UnityShaderVariables.cginc"
				#include "UnityDeferredLibrary.cginc"

				sampler2D _CameraGBufferTexture0;
				sampler2D _CameraGBufferTexture1;
				sampler2D _CameraGBufferTexture2;

				void DeferredCalculateLightParams (
					unity_v2f_deferred i,
					out float3 outWorldPos,
					out float2 outUV,
					out half3 outLightDir,
					out float outAtten)
				{
					i.ray = i.ray * (_ProjectionParams.z / i.ray.z);
					float2 uv = i.uv.xy / i.uv.w;
					
					// read depth and reconstruct world position
					float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
					depth = Linear01Depth (depth);
					float4 vpos = float4(i.ray * depth,1);
					float3 wpos = mul (_CameraToWorld, vpos).xyz;
					
					// spot light case
					#if defined (SPOT)	
						float3 tolight = _LightPos.xyz - wpos;
						half3 lightDir = normalize (tolight);
						
						float4 uvCookie = mul (_LightMatrix0, float4(wpos,1));
						float atten = tex2Dproj (_LightTexture0, UNITY_PROJ_COORD(uvCookie)).w;
						atten *= uvCookie.w < 0;
						float att = dot(tolight, tolight) * _LightPos.w;
						atten *= tex2D (_LightTextureB0, att.rr).UNITY_ATTEN_CHANNEL;
						
						atten *= UnityDeferredComputeShadow (wpos, fadeDist, uv);
					
					// directional light case		
					#elif defined (DIRECTIONAL) || defined (DIRECTIONAL_COOKIE)
						half3 lightDir = -_LightDir.xyz;
						float atten = 1.0;
						
						atten *= UnityDeferredComputeShadow (wpos, 0, uv);
						
						#if defined (DIRECTIONAL_COOKIE)
						atten *= tex2D (_LightTexture0, mul(_LightMatrix0, half4(wpos,1)).xy).w;
						#endif //DIRECTIONAL_COOKIE
					
					// point light case	
					#elif defined (POINT) || defined (POINT_COOKIE)
						float3 tolight = wpos - _LightPositionRange.xyz;
						#ifdef PIP_RANGE_DISCARD
							float tolightLength = length(tolight);
							if (tolightLength * _LightPositionRange.w > 1.0) {
								discard;
							}
							half3 lightDir = -(tolight / tolightLength);
						#else
							half3 lightDir = -normalize (tolight);
						#endif
						float att = dot(tolight, tolight) * _LightPos.w;
						float atten = tex2D (_LightTextureB0, att.rr).UNITY_ATTEN_CHANNEL;
						
						atten *= UnityDeferredComputeShadow (tolight, 0, uv);
						
						#if defined (POINT_COOKIE)
						atten *= texCUBE(_LightTexture0, mul(_LightMatrix0, half4(wpos,1)).xyz).w;
						#endif //POINT_COOKIE	
					#else
						half3 lightDir = 0;
						float atten = 0;
					#endif

					outWorldPos = wpos;
					outUV = uv;
					outLightDir = lightDir;
					outAtten = atten;
				}

				half4 frag(unity_v2f_deferred i) : SV_Target
				{
					float3 WorldPos;
					float2 UV;
					half3 LightDir;
					float Atten;
					DeferredCalculateLightParams (i, WorldPos, UV, LightDir, Atten);
					#ifdef PIP_SHADOW_DISCARD
						if (Atten <= 0.0f) {
							discard;
						}
					#endif
					
					half4 gbuffer0 = tex2D(_CameraGBufferTexture0, UV);
					half4 gbuffer1 = tex2D(_CameraGBufferTexture1, UV);
					half3 normalWorld = tex2D(_CameraGBufferTexture2, UV).rgb * 2 - 1;

					half3 diffColor = gbuffer0.rgb;
					half3 specColor = gbuffer1.rgb;
					half oneMinusReflectivity = 1 - SpecularStrength (specColor);
					half oneMinusRoughness = gbuffer1.a;
					
					UnityLight light;
					UNITY_INITIALIZE_OUTPUT(UnityLight, light);
					light.dir = LightDir;
					light.color = _LightColor.xyz * Atten;
					light.ndotl = LambertTerm(normalWorld, LightDir);

					UnityIndirect gi;
					UNITY_INITIALIZE_OUTPUT(UnityIndirect, gi);
					gi.diffuse = 0;
					gi.specular = 0;
					
					return UNITY_BRDF_PBS ( diffColor, specColor, oneMinusReflectivity, oneMinusRoughness, 
						normalWorld, normalize(_WorldSpaceCameraPos - WorldPos), light, gi);
				}

			ENDCG
		}
	}
	Fallback Off
}
