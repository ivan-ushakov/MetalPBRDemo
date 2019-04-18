//
//  Common.h
//  MetalCube
//
//  Created by  Ivan Ushakov on 13/04/2019.
//  Copyright © 2019  Ivan Ushakov. All rights reserved.
//

#ifndef Common_h
#define Common_h

#import <simd/simd.h>

typedef struct
{
    vector_float3 position;
    vector_float2 uv;
    vector_float3 normal;
} Vertex;

typedef struct
{
    matrix_float4x4 projection_matrix;
    matrix_float4x4 view_matrix;
    matrix_float4x4 model_matrix;
    vector_float3 camera_position;
} Uniforms;

typedef struct
{
    vector_float3 position;
    vector_float3 color;
} Light;

typedef struct
{
    Light entry[4];
} LightStore;

#endif /* Common_h */
