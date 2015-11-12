Shader "Shadowmapping" {
   Properties {
      _DiffuseColor ("Diffuse Material Color", Color) = (1,1,1,1) 
      _shadowmap ("_shadowmap", 2D) = "white"
   }
   
   SubShader {
      Pass {	
      	 Tags { "LightMode" = "ForwardBase" } 
      
         CGPROGRAM

         #pragma vertex vert  
         #pragma fragment frag 
 	     #pragma target 3.0
 		 #include "UnityCG.cginc"
 
         struct vertexInput {
            float4 vertex : POSITION;
            float3 normal : NORMAL;
            float2 texcoord : TEXCOORD0;   
		 };
        
          struct vertexOutput {
			float4 pos : SV_POSITION;
			float4 col : TEXCOORD0;
		    float4 texCoordProj : TEXCOORD4;
         };
 
 		 uniform float4 _DiffuseColor; 
         uniform float4x4 _LightViewMatrix;
         uniform float4x4 _LightprojectionMatrix;
		 uniform sampler2D _shadowmap; 
		 
		 
         vertexOutput vert(vertexInput input) 
         {   
            vertexOutput output;
            
            float4 lightPosition = float4(unity_4LightPosX0[0], 
                  unity_4LightPosY0[0], 
                  unity_4LightPosZ0[0], 1.0);
                  
            float4x4 modelMatrix = _Object2World;
            float4x4 modelMatrixInverse = _World2Object;
            
            //Find the world position
            float4 worldPosition = mul(modelMatrix,input.vertex);
              
            //Find the normals in world coordinates
            float3 worldNormal = normalize(mul(float4(input.normal,0),transpose(modelMatrixInverse)).xyz);
         
            //Calculate the light direction
            float3 lightDirection = normalize((lightPosition - worldPosition).xyz);
            
            //Calculate the diffuse reflection intensity
            float diffuseReflectionIntensity = max(0.0, dot(worldNormal,lightDirection));
              
			float4 modelForTexture = mul(modelMatrix, input.vertex);

			float4x4 constantMatrix  = {0.5,0,0,0.5,
            							0,0.5,0,0.5,
            							0,0,0.5,0.5,
            							0,0,0,  1};
            							
           	float4x4 textureMatrix;
        	textureMatrix = mul(mul(constantMatrix,_LightprojectionMatrix), _LightViewMatrix);
			
			output.pos = mul(UNITY_MATRIX_MVP, input.vertex);
            output.col =  _DiffuseColor * diffuseReflectionIntensity;
			output.texCoordProj = mul(textureMatrix, modelForTexture);

            return output;
         }
         
 
         float4 frag(vertexOutput input) : COLOR
         {
 			float4 shadowCoeff;   // 0 means "in shadow",
									// 1 means "not in shadow"
   				
   			shadowCoeff = tex2Dproj(_shadowmap, input.texCoordProj);
   			
   			if (shadowCoeff.r == 1 && shadowCoeff.b == 1 && shadowCoeff.g == 1){
      	    	shadowCoeff = float4(1,1,1,1);
      	    }
      	    else {
      	    	shadowCoeff =  float4(0,0,0,1);
      	    }
      	    
            return input.col * shadowCoeff;
          }
         ENDCG
      }
   }
}