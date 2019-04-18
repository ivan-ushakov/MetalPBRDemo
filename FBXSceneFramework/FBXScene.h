//
//  SceneAdapter.h
//  MetalRobot
//
//  Created by  Ivan Ushakov on 03/01/2019.
//  Copyright © 2019  Ivan Ushakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    const void *address;
    size_t size;
} FBXBuffer;

@interface FBXScene : NSObject

- (BOOL)load:(NSString *)path error:(NSError * _Nullable * _Nullable)error;

- (void)render;

- (size_t)getMeshCount;

- (size_t)getIndexCount:(size_t)index;

- (simd_float4x4)getTransformation:(size_t)index;

- (FBXBuffer)getVertexData:(size_t)index;

- (FBXBuffer)getIndexData:(size_t)index;

- (NSString *)getAlbedoTexturePath:(size_t)index;

- (simd_float3)maxBounds:(size_t)index;

- (simd_float3)minBounds:(size_t)index;

@end

NS_ASSUME_NONNULL_END
