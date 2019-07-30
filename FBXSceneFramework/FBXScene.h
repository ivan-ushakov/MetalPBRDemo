//
//  SceneAdapter.h
//  MetalRobot
//
//  Created by  Ivan Ushakov on 03/01/2019.
//  Copyright © 2019  Ivan Ushakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Metal/Metal.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

@interface FBXScene : NSObject

@property (readonly, nonatomic) NSString *path;

- (BOOL)load:(NSString *)path error:(NSError * _Nullable * _Nullable)error;

- (BOOL)createBuffers:(id <MTLDevice>)device error:(NSError * _Nullable * _Nullable)error;

- (void)render;

- (size_t)getMeshCount;

- (size_t)getIndexCount:(size_t)index;

- (simd_float4x4)getTransformation:(size_t)index;

- (id <MTLBuffer>)getVertexBuffer:(size_t)index;

- (id <MTLBuffer>)getIndexBuffer:(size_t)index;

- (NSString *)getName:(size_t)index;

- (simd_float3)maxBounds:(size_t)index;

- (simd_float3)minBounds:(size_t)index;

@end

NS_ASSUME_NONNULL_END
