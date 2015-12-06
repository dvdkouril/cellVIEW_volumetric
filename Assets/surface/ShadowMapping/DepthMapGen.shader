//Shows the grayscale of the depth from the camera.
 
Shader "DepthMapGen"
{
    SubShader
    {
        Tags { "RenderType"="Opaque" }
 
        Pass
        {
			ztest always
			zwrite On
 
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
 		
            uniform sampler2D _CameraDepthTexture; //the depth texture
 
            struct v2f
            {
                float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
            };
            
			v2f vert(appdata_base v)
            {
                v2f o;
                o.pos = mul(UNITY_MATRIX_MVP, v.vertex); 
				o.uv = v.texcoord ;
                return o;
            }
 
            float frag(v2f i) : COLOR
            {				
                //return tex2D(_CameraDepthTexture, i.uv);

				float depth = tex2D(_CameraDepthTexture, i.uv);
				float eyedepth = abs(LinearEyeDepth(depth));
                return eyedepth;
            }
 
            ENDCG
        }

		//Pass
  //      {
			
 
  //          CGPROGRAM
  //          #pragma target 3.0
  //          #pragma vertex vert
  //          #pragma fragment frag
  //          #include "UnityCG.cginc"
 		
  //          uniform sampler2D _CameraDepthTexture; //the depth texture
 
  //          struct v2f
  //          {
  //              float4 pos : SV_POSITION;
		//		float2 uv : TEXCOORD0;
  //          };
            
		//	v2f vert(appdata_base v)
  //          {
  //              v2f o;
  //              o.pos = mul(UNITY_MATRIX_MVP, v.vertex); 
		//		o.uv = v.texcoord ;
  //              return o;
  //          }
 
  //          float4 frag(v2f i) : Color
  //          {				
  //              float depth = tex2D(_CameraDepthTexture, i.uv);
		//		return float4(depth,0,0,1);
  //          }
 
  //          ENDCG
  //      }
    }
    FallBack "VertexLit"
}