//
//  SceneAdapter.m
//  MetalRobot
//
//  Created by  Ivan Ushakov on 03/01/2019.
//  Copyright © 2019  Ivan Ushakov. All rights reserved.
//

#import "FBXScene.h"

#import "Scene.h"

@implementation FBXScene
{
    NSMutableArray<id <MTLBuffer>> *_vertexBuffers;
    NSMutableArray<id <MTLBuffer>> *_indexBuffers;
    Scene _scene;
}

- (BOOL)load:(NSString *)path error:(NSError * _Nullable * _Nullable)error {    
    try {
        _path = path;
        _scene.load(std::string(path.UTF8String));
    } catch (std::exception &e) {
        return NO;
    }
    return YES;
}

- (BOOL)createBuffers:(id <MTLDevice>)device error:(NSError * _Nullable * _Nullable)error {
    _vertexBuffers = [NSMutableArray arrayWithCapacity:_scene.mesh_.size()];
    _indexBuffers = [NSMutableArray arrayWithCapacity:_scene.mesh_.size()];
    
    for (auto &&m : _scene.mesh_) {
        NSUInteger l1 = m->vertexCount * sizeof(Vertex);
        id <MTLBuffer> vertexBuffer = [device newBufferWithLength:l1 options:MTLResourceStorageModeShared];
        if (vertexBuffer == nil) {
            *error = nil;
            return NO;
        }
        
        [_vertexBuffers addObject:vertexBuffer];
        m->vertexArray = (Vertex *)vertexBuffer.contents;
        
        NSUInteger l2 = m->indexCount * sizeof(uint32_t);
        id <MTLBuffer> indexBuffer = [device newBufferWithLength:l2 options:MTLResourceStorageModeShared];
        if (indexBuffer == nil) {
            *error = nil;
            return NO;
        }
        
        [_indexBuffers addObject:indexBuffer];
        m->indexArray = (uint32_t *)indexBuffer.contents;
    }
    
    return YES;
}

- (void)render {
    _scene.onTimerClick();
    _scene.onDisplay();
}

- (size_t)getMeshCount {
    return _scene.mesh_.size();
}

- (size_t)getIndexCount:(size_t)index {
    return _scene.mesh_[index]->indexCount;
}

- (simd_float4x4)getTransformation:(size_t)index {
    return _scene.mesh_[index]->position;
}

- (id <MTLBuffer>)getVertexBuffer:(size_t)index {
    return _vertexBuffers[index];
}

- (id <MTLBuffer>)getIndexBuffer:(size_t)index {
    return _indexBuffers[index];
}

- (NSString *)getName:(size_t)index {
    return [NSString stringWithUTF8String:_scene.mesh_[index]->name.c_str()];
}

- (simd_float3)maxBounds:(size_t)index {
    return _scene.mesh_[index]->maxBounds;
}

- (simd_float3)minBounds:(size_t)index {
    return _scene.mesh_[index]->minBounds;
}

@end
