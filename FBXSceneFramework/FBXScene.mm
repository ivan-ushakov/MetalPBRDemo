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
    Scene _scene;
}

- (BOOL)load:(NSString *)path error:(NSError * _Nullable * _Nullable)error {    
    try {
        _scene.load(std::string(path.UTF8String));
    } catch (std::exception &e) {
        return NO;
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
    return _scene.mesh_[index]->indices.size();
}

- (simd_float4x4)getTransformation:(size_t)index {
    return _scene.mesh_[index]->position;
}

- (FBXBuffer)getVertexData:(size_t)index {
    FBXBuffer buffer;
    buffer.address = _scene.mesh_[index]->vertices.data();
    buffer.size = _scene.mesh_[index]->vertices.size() * sizeof(Vertex);
    return buffer;
}

- (FBXBuffer)getIndexData:(size_t)index {
    FBXBuffer buffer;
    buffer.address = _scene.mesh_[index]->indices.data();
    buffer.size = _scene.mesh_[index]->indices.size() * sizeof(uint32_t);
    return buffer;
}

- (NSString *)getAlbedoTexturePath:(size_t)index {
    return [NSString stringWithUTF8String:_scene.mesh_[index]->albedoTexture.c_str()];
}

- (simd_float3)maxBounds:(size_t)index {
    return _scene.mesh_[index]->maxBounds;
}

- (simd_float3)minBounds:(size_t)index {
    return _scene.mesh_[index]->minBounds;
}

@end
