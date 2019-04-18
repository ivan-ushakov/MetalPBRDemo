//
//  Library.metal
//  MetalRobot
//
//  Created by  Ivan Ushakov on 03/01/2019.
//  Copyright © 2019  Ivan Ushakov. All rights reserved.
//

#include <metal_stdlib>

#include "Rendering/Common.h"

using namespace metal;

constexpr sampler sampler_2d(mip_filter::linear, mag_filter::linear, min_filter::linear);

typedef struct
{
    float4 position [[position]];
    float3 world_position;
    float2 uv;
    float3 normal;
    float3 camera_position;
} VertexShaderOutput;

typedef struct
{
    float3 position [[attribute(0)]];
    float2 uv [[attribute(1)]];
    float3 normal [[attribute(2)]];
} InputVertex;

vertex VertexShaderOutput vertex_shader(InputVertex v [[stage_in]],
                                        constant Uniforms &uniforms [[buffer(1)]])
{
    VertexShaderOutput output;
    
    float4 world_position = uniforms.model_matrix * float4(v.position, 1.0);
    output.position = uniforms.projection_matrix * uniforms.view_matrix * world_position;
    
    output.world_position = world_position.xyz;
    output.normal = (uniforms.model_matrix * float4(v.normal, 1.0)).xyz;

    output.camera_position = uniforms.camera_position;
    
    output.uv = v.uv;
    
    return output;
}

// ----------------------------------------------------------------------------
// Easy trick to get tangent-normals to world-space to keep PBR code simplified.
// Don't worry if you don't get what's going on; you generally want to do normal
// mapping the usual way for performance anways; I do plan make a note of this
// technique somewhere later in the normal mapping tutorial.
static float3 get_normal_from_map(float3 world_position, float3 normal, float2 uv, texture2d<float> normal_map)
{
    float3 tangent_normal = normal_map.sample(sampler_2d, uv).xyz * 2.0 - 1.0;
    
    float3 Q1 = dfdx(world_position);
    float3 Q2 = dfdy(world_position);
    float2 st1 = dfdx(uv);
    float2 st2 = dfdy(uv);
    
    float3 N = normalize(normal);
    float3 T = normalize(Q1 * st2.y - Q2 * st1.y);
    float3 B = -normalize(cross(N, T));
    float3x3 TBN = float3x3(T, B, N);
    
    return normalize(TBN * tangent_normal);
}

static float3 fresnel_schlick(float cos_theta, float3 F0)
{
    return F0 + (1.0 - F0) * pow(1.0 - cos_theta, 5.0);
}

static float distribution_ggx(float3 N, float3 H, float roughness)
{
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;
    
    float num = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = M_PI_F * denom * denom;
    
    return num / denom;
}

static float geometry_schlick_ggx(float NdotV, float roughness)
{
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;
    
    float num = NdotV;
    float denom = NdotV * (1.0 - k) + k;
    
    return num / denom;
}

static float geometry_smith(float3 N, float3 V, float3 L, float roughness)
{
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = geometry_schlick_ggx(NdotV, roughness);
    float ggx1 = geometry_schlick_ggx(NdotL, roughness);
    
    return ggx1 * ggx2;
}

fragment half4 fragment_shader(VertexShaderOutput in [[stage_in]],
                               constant LightStore &lights [[buffer(0)]],
                               texture2d<float> albedo_map [[texture(0)]],
                               texture2d<float> metallic_map [[texture(1)]],
                               texture2d<float> roughness_map [[texture(2)]],
                               texture2d<float> ao_map [[texture(3)]],
                               texture2d<float> normal_map [[texture(4)]])
{
    float3 albedo = pow(albedo_map.sample(sampler_2d, in.uv).rgb, 2.2);
    float metallic = metallic_map.sample(sampler_2d, in.uv).r;
    float roughness = roughness_map.sample(sampler_2d, in.uv).r;
    float ao = ao_map.sample(sampler_2d, in.uv).r;
    
    float3 N = get_normal_from_map(in.world_position, in.normal, in.uv, normal_map);
    float3 V = normalize(in.camera_position - in.world_position);
    
    // calculate reflectance at normal incidence; if dia-electric (like plastic) use F0
    // of 0.04 and if it's a metal, use the albedo color as F0 (metallic workflow)
    float3 F0 = float3(0.04);
    F0 = mix(F0, albedo, metallic);
    
    // reflectance equation
    float3 Lo = float3(0.0);
    for (int i = 0; i < 4; i++)
    {
        // calculate per-light radiance
        float3 L = normalize(lights.entry[i].position - in.world_position);
        float3 H = normalize(V + L);
        float d = length(lights.entry[i].position - in.world_position);
        float attenuation = 1.0 / (d * d);
        float3 radiance = lights.entry[i].color * attenuation;
        
        // Cook-Torrance BRDF
        float NDF = distribution_ggx(N, H, roughness);
        float G = geometry_smith(N, V, L, roughness);
        float3 F = fresnel_schlick(max(dot(H, V), 0.0), F0);
        
        float3 numerator = NDF * G * F;
        float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.001; // 0.001 to prevent divide by zero.
        float3 specular = numerator / denominator;
        
        // kS is equal to Fresnel
        float3 kS = F;
        // for energy conservation, the diffuse and specular light can't
        // be above 1.0 (unless the surface emits light); to preserve this
        // relationship the diffuse component (kD) should equal 1.0 - kS.
        float3 kD = float3(1.0) - kS;
        // multiply kD by the inverse metalness such that only non-metals
        // have diffuse lighting, or a linear blend if partly metal (pure metals
        // have no diffuse light).
        kD *= 1.0 - metallic;
        
        // scale light by NdotL
        float NdotL = max(dot(N, L), 0.0);
        
        // add to outgoing radiance Lo
        Lo += (kD * albedo / M_PI_F + specular) * radiance * NdotL; // note that we already multiplied the BRDF by the Fresnel (kS) so we won't multiply by kS again
    }
    
    // ambient lighting (note that the next IBL tutorial will replace
    // this ambient lighting with environment lighting).
    float3 ambient = float3(0.03) * albedo * ao;
    
    float3 color = ambient + Lo;
    
    // HDR tonemapping
    color = color / (color + float3(1.0));
    // gamma correct
    color = pow(color, float3(1.0 / 2.2));
    
    return half4(float4(color, 1.0));
}
