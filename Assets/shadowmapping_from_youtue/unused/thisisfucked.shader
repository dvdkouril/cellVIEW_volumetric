Shader "thisisfucked" {
   Properties {
      _DiffuseColor ("Diffuse Material Color", Color) = (1,1,1,1) 
      _SpecColor ("Specular Material Color", Color) = (1,1,1,1) 
      _Shininess ("Shininess", Float) = 10
      _shadowmap ("_shadowmap", 2D) = "white"
      _cameraPosition ("cameraposition", Vector) = (0,0,0,0)
      _SpherePosition ("Sphere Position", Vector) = (0,0,0,1)
      _SphereRadius ("Sphere Radius", Float) = 1
      _LightSourceRadius ("Light Source Radius", Float) = 0.005
      _shadowFLOAT ("shadowFLOAT",Float) = 0.5
      

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
			float4 posWorld : TEXCOORD1;
			float2 uv : TEXCOORD2;
		    float3 normalDir : TEXCOORD3;
		    float4 texCoordProj : TEXCOORD4;
         };
 
 		 uniform float4 _DiffuseColor; 
         uniform float4 _SpecColor; 
         uniform float _Shininess;
    //     uniform float4 texCoordProj;
         uniform sampler2D _shadowmap;
         uniform float4 _cameraPosition;
         uniform float _shadowFLOAT;
         
		 uniform sampler2D _CameraDepthTexture; 

 		 uniform float4 _SpherePosition; 
            // center of shadow-casting sphere in world coordinates
         uniform float _SphereRadius; 
            // radius of shadow-casting sphere
         uniform float _LightSourceRadius; 
            // in radians for directional light sources'
            
         uniform float4 _LightColor0;
         
         uniform float4x4 _LightViewMatrix;
         uniform float4x4 _LightprojectionMatrix;

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
            float4x4 modelMatrixInverse = _World2Object;
            
            //Find the world position
            float4 worldPosition = mul(modelMatrix,input.vertex);
            output.posWorld = mul(modelMatrix, input.vertex);
              
            //Find the normals in world coordinates
            float3 worldNormal = normalize(mul(float4(input.normal,0),transpose(modelMatrixInverse)).xyz);
            output.normalDir = worldNormal; //normalize(float3(mul(float4(input.normal, 0.0), modelMatrixInverse)));

                        //Calculate the light direction
            float3 lightDirection = normalize((lightPosition - worldPosition).xyz);
            
            //Calculate the diffuse reflection intensity
            float diffuseReflectionIntensity = max(0.0, dot(worldNormal,lightDirection));
            
            //Calculate viewDirection
           // float3 viewDirection = normalize((viewPosition - worldPosition).xyz);
           
            output.pos = mul(UNITY_MATRIX_MVP, input.vertex);
            output.col =  _DiffuseColor * diffuseReflectionIntensity;
           
            
			float4 something = mul(modelMatrix, input.vertex);

			float4x4 constantMatrix  = {0.5,0,0,0.5,
            							0,0.5,0,0.5,
            							0,0,0.5,0.5,
            							0,0,0,  1};
            							
           	float4x4 textureMatrix;
           	
        	textureMatrix = mul(mul(constantMatrix,_LightprojectionMatrix), _LightViewMatrix);
			
			output.texCoordProj = mul(textureMatrix, something);
			
			
            return output;
         }
 
         float4 frag(vertexOutput input) : COLOR
         {
         	float3 normalDirection = normalize(input.normalDir);
 
  			//Calculate viewDirection
            float3 viewDirection = normalize(_WorldSpaceCameraPos - float3(input.posWorld));
            float3 lightDirection;
            float lightDistance;
            float attenuation;
         	
         	if (0.0 == _WorldSpaceLightPos0.w) // is it a directional light?
            {
               attenuation = 1.0; // no attenuation
               lightDirection = normalize(float3(_WorldSpaceLightPos0));
               lightDistance = 1.0;
            } 
            else // else it's a point or spot light.
            {
               lightDirection = float3(_WorldSpaceLightPos0 - input.posWorld);
               lightDistance = length(lightDirection);
               attenuation = 1.0 / lightDistance; // linear attenuation
               lightDirection = lightDirection / lightDistance;
            }
         	
         	float3 sphereDirection = float3(
               _SpherePosition - input.posWorld);// the direction vector from  sphere to plane 
            float sphereDistance = length(sphereDirection); //the length of the vector
            sphereDirection = sphereDirection / sphereDistance; // noralized 
            float d = lightDistance  * (asin(min(1.0, length(cross(lightDirection, sphereDirection))))
            		  - asin(min(1.0, _SphereRadius / sphereDistance)));
            float w = smoothstep(-1.0, 1.0, -d / _LightSourceRadius); // w deternines the smoothness of the penumbra and the area of which. 
            w = w * smoothstep(0.0, 0.2, dot(lightDirection, sphereDirection));
            if (0.0 != _WorldSpaceLightPos0.w) // point light source?
            {
               w = w * smoothstep(0.0, _SphereRadius, 
                  lightDistance - sphereDistance);
            }
         
         
         	float3 ambientLighting = 
         	  float3(UNITY_LIGHTMODEL_AMBIENT) * float3(_DiffuseColor);
 
            float3 diffuseReflection = 
               attenuation * float3(_LightColor0) * float3(_DiffuseColor)
               * max(0.0, dot(normalDirection, lightDirection));
 
            float3 specularReflection;
            if (dot(normalDirection, lightDirection) < 0.0) 
               // light source on the wrong side?
            {
               specularReflection = float3(0.0, 0.0, 0.0); 
                  // no specular reflection
            }
            else // light source on the right side
            {
               specularReflection = attenuation * float3(_LightColor0) 
                  * float3(_SpecColor) * pow(max(0.0, dot(
                  reflect(-lightDirection, normalDirection), 
                  viewDirection)), _Shininess);
            }
 
 			//float4 textureColor = tex2Dproj(_shadowmap, texCoordProj);
 				
 			float4 shadowCoeff;   // 0 means "in shadow",
									// 1 means "not in shadow"
   				
   			shadowCoeff = tex2Dproj(_shadowmap, input.texCoordProj);
   				
   				
   			if (shadowCoeff.r == 1 && shadowCoeff.b == 1 && shadowCoeff.g == 1){
      	    	shadowCoeff = float4(1,1,1,1);
      	    }
      	    else {
      	    	shadowCoeff =  float4(0,0,0,1);
      	    }
 			//shadowCoeff = float4(_shadowFLOAT,_shadowFLOAT,_shadowFLOAT,1);
 				
 			//float4 shadowTest = tex2D(_shadowmap, input.uv.xy);
 			//diffuseReflection = diffuseReflection * shadowCoeff;

            
         //   return float4((ambientLighting  + (1.0) * (diffuseReflection + specularReflection) * shadowCoeff), 1.0);
    //        return float4(((ambientLighting + diffuseReflection + specularReflection) * shadowCoeff), 1.0);
            return input.col * shadowCoeff;
           
//            float4 textureColor = tex2D(_shadowmap, inp.uv.xy);
      	  
			
			//return float4(diffuseReflection*shadowCoeff,1.0);
         
       		//return input.col * shadowCoeff;
         }
         ENDCG
      }
   }
}