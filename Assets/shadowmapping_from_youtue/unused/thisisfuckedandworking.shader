Shader "thisisfuckedandworking" {
   Properties {
      _DiffuseColor ("Diffuse Material Color", Color) = (1,0,0,1) 
      _SpecColor ("Specular Material Color", Color) = (1,1,1,1) 
      _Shininess ("Shininess", Float) = 10
      _shadowmap ("_shadowmap", 2D) = "white"
      _cameraPosition ("cameraposition", Vector) = (0,0,0,0)
   }
   SubShader {
      Pass {	
      
      	 Tags { "LightMode" = "ForwardBase" } 
      
         CGPROGRAM

         #pragma vertex vert  
         #pragma fragment frag 
 
 		 #include "UnityCG.cginc"
 
         struct vertexInput {
            float4 vertex : POSITION;
            float3 normal : NORMAL;
            float2 texcoord : TEXCOORD0;
			  };
        
          struct vertexOutput {
			float4 pos : SV_POSITION;
			float4 col : TEXCOORD0;
			float4 projTex : TEXCOORD1;
			float2 uv : TEXCOORD2;
	
         };
 
 		 uniform float4 _DiffuseColor; 
         uniform float4 _SpecColor; 
         uniform float _Shininess;
         uniform float4 texCoordProj;
         uniform float4x4 textureMatrix;
         uniform sampler2D _shadowmap;
         uniform float4 _cameraPosition;
         
		 uniform sampler2D _CameraDepthTexture; 

 
         vertexOutput vert(vertexInput input) 
         {
            vertexOutput output;
            
            float4 lightPosition = float4(unity_4LightPosX0[0], 
                  unity_4LightPosY0[0], 
                  unity_4LightPosZ0[0], 1.0);
                  
            float4 viewPosition = float4(_WorldSpaceCameraPos,1);
 
            float4x4 modelMatrix = _Object2World;
            float4x4 viewMatrix = UNITY_MATRIX_V; 
            float4x4 projectionMatrix = UNITY_MATRIX_P;
            
            //Find the world position
            float4 worldPosition = mul(modelMatrix,input.vertex);
            
            //Find the normals in world coordinates
            float4x4 modelMatrixInverse = _World2Object;
            float3 worldNormal = normalize(mul(float4(input.normal,0),transpose(modelMatrixInverse)).xyz);
            
            //Calculate the light direction
            float3 lightDirection = normalize((lightPosition - worldPosition).xyz);
            
            //Calculate the diffuse reflection intensity
            float diffuseReflectionIntensity = max(0.0, dot(worldNormal,lightDirection)) ;
            
            //Calculate viewDirection
            float3 viewDirection = normalize((viewPosition - worldPosition).xyz);
           
            output.pos = mul(projectionMatrix,mul(viewMatrix,worldPosition));
            output.col =  _DiffuseColor * diffuseReflectionIntensity;
            
            
            float4x4 constantMatrix  = {0.5,0,0,0.5,
            							0,0.5,0,0.5,
            							0,0,0.5,0.5,
            							0,0,0,  1};
            							
           	
        	textureMatrix = constantMatrix * UNITY_MATRIX_MVP;
            
            
            texCoordProj = mul(textureMatrix, input.vertex);
            
			float4 posWorld = mul(_Object2World, float4(input.vertex));

			output.projTex = ComputeScreenPos(output.pos);

			output.uv = input.texcoord;
	
            return output;
         }
 
         float4 frag(vertexOutput inp) : COLOR
         {
            
			float depth = Linear01Depth (tex2Dproj(_shadowmap, UNITY_PROJ_COORD(inp.projTex)).r);
//			float depth = Linear01Depth (tex2Dproj(_CameraDepthTexture, _cameraPosition).r);
		//	float depth Linear01Depth (tex2Dproj(_shadowmap, 
			float shadowCoeff = tex2Dproj(_shadowmap, texCoordProj);
			
			half4 c;
			c.r = depth;
			c.b = depth;
			c.g = depth;
			c.a = 1;
			
		//		if(depth > 0.5){
		//		c.r = 0;
		//		c.b = 0;
		//		c.g = 0;
		//		}
		//		else{
		//		c = inp.col;
		//		}
        //       c.a = 1;
       

      	  float4 textureColor = tex2D(_shadowmap, inp.uv.xy);
      	  
      	      
      	  
      	    if (textureColor.r == 1 && textureColor.b == 1 && textureColor.g == 1){
      	    	textureColor = float4(1,1,1,1);
      	    }
      	    else {
      	    	textureColor =  float4(0,0,0,1);
      	    }
			
			return inp.col * textureColor;
         }
         ENDCG
      }
   }
}