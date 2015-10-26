Shader "PipLight/Depth" {
	SubShader{
		Tags{ "RenderType" = "Opaque" }
		Pass{
			Fog { Mode Off }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			
			float4 Pip_LightPositionRange;
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 vec : TEXCOORD0;
			};
			
			struct appdata {
				float4 vertex : POSITION;
			};

			v2f vert(appdata v) {
				v2f o;
				o.vec = mul(_Object2World, v.vertex).xyz - Pip_LightPositionRange.xyz; 
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				return o;
			}

			float4 frag(v2f i) : SV_Target {
				return length(i.vec) * Pip_LightPositionRange.w;
			}

			ENDCG
		}
	}
}