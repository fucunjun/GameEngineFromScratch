////////////////////////////////////////////////////////////////////////////////
// Filename: pbr_ps.glsl
////////////////////////////////////////////////////////////////////////////////

/////////////////////
// INPUT VARIABLES //
/////////////////////
in vec4 normal;
in vec4 normal_world;
in vec4 v; 
in vec4 v_world;
in vec2 uv;

//////////////////////
// OUTPUT VARIABLES //
//////////////////////
out vec4 outputColor;

////////////////////////////////////////////////////////////////////////////////
// Pixel Shader
////////////////////////////////////////////////////////////////////////////////
void main()
{		
    vec3 N = normalize(normal_world.xyz);
    vec3 V = normalize(camPos - v_world.xyz);

    vec3 albedo;
    if (usingDiffuseMap)
    {
        albedo = texture(diffuseMap, uv).rgb; 
    }
    else
    {
        albedo = diffuseColor;
    }

    vec3 F0 = vec3(0.04); 
    F0 = mix(F0, albedo, metallic);
	           
    // reflectance equation
    vec3 Lo = vec3(0.0);
    for (int i = 0; i < numLights; i++)
    {
        Light light = allLights[i];

        // calculate per-light radiance
        vec3 L = normalize(light.lightPosition.xyz - v_world.xyz);
        vec3 H = normalize(V + L);

        float NdotL = max(dot(N, L), 0.0f);

        // shadow test
        float visibility = shadow_test(v_world, light, NdotL);

        float lightToSurfDist = length(L);
        float lightToSurfAngle = acos(dot(-L, light.lightDirection.xyz));

        // angle attenuation
        float atten_params[5];
        atten_params[0] = light.lightAngleAttenCurveParams_0;
        atten_params[1] = light.lightAngleAttenCurveParams_1;
        atten_params[2] = light.lightAngleAttenCurveParams_2;
        atten_params[3] = light.lightAngleAttenCurveParams_3;
        atten_params[4] = light.lightAngleAttenCurveParams_4;
        float atten = apply_atten_curve(lightToSurfAngle, light.lightAngleAttenCurveType, atten_params);

        // distance attenuation
        atten_params[0] = light.lightDistAttenCurveParams_0;
        atten_params[1] = light.lightDistAttenCurveParams_1;
        atten_params[2] = light.lightDistAttenCurveParams_2;
        atten_params[3] = light.lightDistAttenCurveParams_3;
        atten_params[4] = light.lightDistAttenCurveParams_4;
        atten *= apply_atten_curve(lightToSurfDist, light.lightDistAttenCurveType, atten_params);

        vec3 radiance = light.lightIntensity * atten * light.lightColor.rgb;
        
        // cook-torrance brdf
        float NDF = DistributionGGX(N, H, roughness);        
        float G   = GeometrySmith(N, V, L, roughness);      
        vec3 F    = fresnelSchlick(max(dot(H, V), 0.0), F0);       
        
        vec3 kS = F;
        vec3 kD = vec3(1.0) - kS;
        kD *= 1.0 - metallic;	  
        
        vec3 numerator    = NDF * G * F;
        float denominator = 4.0 * max(dot(N, V), 0.0) * NdotL;
        vec3 specular     = numerator / max(denominator, 0.001);  
            
        // add to outgoing radiance Lo
        Lo += (kD * albedo / PI + specular) * radiance * NdotL * visibility; 
    }   
  
    vec3 ambient = ambientColor * albedo * ao;
    vec3 linearColor = ambient + Lo;
	
    // tone mapping
    linearColor = reinhard_tone_mapping(linearColor);
   
    // gamma correction
    linearColor = gamma_correction(linearColor);

    outputColor = vec4(linearColor, 1.0);
}