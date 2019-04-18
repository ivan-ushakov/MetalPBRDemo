//
//  Deformation.h
//  MetalRobot
//
//  Created by  Ivan Ushakov on 16/01/2019.
//  Copyright © 2019  Ivan Ushakov. All rights reserved.
//

#pragma once

#include <string>

#include <fbxsdk.h>

namespace fbx
{
    std::string getTexture(const FbxSurfaceMaterial *, const char *);
    
    FbxAMatrix GetGlobalPosition(FbxNode *, const FbxTime &);
    
    FbxAMatrix GetGeometry(FbxNode *);
    
    // Compute the transform matrix that the cluster will transform the vertex.
    void ComputeClusterDeformation(const FbxAMatrix &, FbxMesh *, FbxCluster *, FbxAMatrix &, const FbxTime &);
    
    // Deform the vertex array in classic linear way.
    void ComputeLinearDeformation(const FbxAMatrix &, FbxMesh *, const FbxTime &, FbxVector4 *);
    
    // Deform the vertex array according to the links contained in the mesh and the skinning type.
    void ComputeSkinDeformation(const FbxAMatrix &, FbxMesh *, const FbxTime &, FbxVector4 *);
}
