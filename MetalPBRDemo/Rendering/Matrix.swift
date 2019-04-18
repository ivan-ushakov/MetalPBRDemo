//
//  Matrix.swift
//  MetalCube
//
//  Created by  Ivan Ushakov on 13/04/2019.
//  Copyright © 2019  Ivan Ushakov. All rights reserved.
//

import Foundation

func matrix_identity() -> matrix_float4x4 {
    let X = vector_float4(1, 0, 0, 0)
    let Y = vector_float4(0, 1, 0, 0)
    let Z = vector_float4(0, 0, 1, 0)
    let W = vector_float4(0, 0, 0, 1)
    return matrix_float4x4(X, Y, Z, W)
}

func matrix_rotation(axis: vector_float3, angle: Float) -> matrix_float4x4 {
    let c = cos(angle)
    let s = sin(angle)
    
    var X = vector_float4()
    X.x = axis.x * axis.x + (1 - axis.x * axis.x) * c
    X.y = axis.x * axis.y * (1 - c) - axis.z * s
    X.z = axis.x * axis.z * (1 - c) + axis.y * s
    X.w = 0.0
    
    var Y = vector_float4()
    Y.x = axis.x * axis.y * (1 - c) + axis.z * s
    Y.y = axis.y * axis.y + (1 - axis.y * axis.y) * c
    Y.z = axis.y * axis.z * (1 - c) - axis.x * s
    Y.w = 0.0
    
    var Z = vector_float4()
    Z.x = axis.x * axis.z * (1 - c) - axis.y * s
    Z.y = axis.y * axis.z * (1 - c) + axis.x * s
    Z.z = axis.z * axis.z + (1 - axis.z * axis.z) * c
    Z.w = 0.0
    
    var W = vector_float4()
    W.x = 0.0
    W.y = 0.0
    W.z = 0.0
    W.w = 1.0
    
    return matrix_float4x4(X, Y, Z, W)
}

func matrix_translation(_ t: vector_float3) -> matrix_float4x4 {
    let X = vector_float4(1, 0, 0, 0)
    let Y = vector_float4(0, 1, 0, 0)
    let Z = vector_float4(0, 0, 1, 0)
    let W = vector_float4(t.x, t.y, t.z, 1)
    return matrix_float4x4(X, Y, Z, W)
}

func matrix_perspective_projection(aspect: Float, fovy: Float, near: Float, far: Float) -> matrix_float4x4 {
    let yScale = 1 / tan(fovy * 0.5)
    let xScale = yScale / aspect
    let zRange = far - near
    let zScale = -(far + near) / zRange
    let wzScale = -2 * far * near / zRange
    
    let P = vector_float4(xScale, 0, 0, 0)
    let Q = vector_float4(0, yScale, 0, 0)
    let R = vector_float4(0, 0, zScale, -1)
    let S = vector_float4(0, 0, wzScale, 0)
    
    return matrix_float4x4(P, Q, R, S)
}

func matrix_uniform_scale(_ s: Float) -> matrix_float4x4 {
    let X = vector_float4(s, 0, 0, 0)
    let Y = vector_float4(0, s, 0, 0)
    let Z = vector_float4(0, 0, s, 0)
    let W = vector_float4(0, 0, 0, 1)
    return matrix_float4x4(X, Y, Z, W)
}

func matrix_look_at_right_hand(eye: vector_float3, target: vector_float3, up: vector_float3) -> simd_float4x4 {
    let z = simd_normalize(eye - target)
    let x = simd_normalize(simd_cross(up, z))
    let y = simd_cross(z, x)
    let t = simd_float3(-simd_dot(x, eye), -simd_dot(y, eye), -simd_dot(z, eye));
    
    return simd_float4x4([simd_float4(x.x, y.x, z.x, 0.0),
                          simd_float4(x.y, y.y, z.y, 0.0),
                          simd_float4(x.z, y.z, z.z, 0.0),
                          simd_float4(t.x, t.y, t.z, 1.0)])
}
