//
//  Scene.h
//  MetalRobot
//
//  Created by  Ivan Ushakov on 07/01/2019.
//  Copyright © 2019  Ivan Ushakov. All rights reserved.
//

#pragma once

#import "Common.h"

#include <fstream>
#include <string>
#include <vector>
#include <functional>

#include <fbxsdk.h>

#include "Deformation.h"

struct SimpleMesh {
    Vertex *vertexArray;
    size_t vertexCount;
    uint32_t *indexArray;
    size_t indexCount;
    std::string name;
    simd_float4x4 position;
    simd_float3 maxBounds;
    simd_float3 minBounds;
};

class Scene {
public:
    std::vector<std::unique_ptr<SimpleMesh>> mesh_;
    
    Scene();
    
    void load(const std::string &);
    
    void prepareIndexBuffers();
    
    void onTimerClick();
    
    void onDisplay();

private:
    void loadCacheRecursive(FbxNode *);
    
    void drawNodeRecursive(FbxNode *, FbxTime &, FbxAMatrix &);
    
    void drawNode(FbxNode *, FbxTime &, FbxAMatrix &, FbxAMatrix &);
    
    void drawMesh(FbxNode *, FbxTime &, FbxAMatrix &);
    
    FbxScene *scene_;
    
    FbxArray<FbxString *> animStackNameArray_;
    
    FbxTime frameTime_;
    FbxTime start_;
    FbxTime stop_;
    FbxTime currentTime_;
    
    bool needDisplay_;
};
