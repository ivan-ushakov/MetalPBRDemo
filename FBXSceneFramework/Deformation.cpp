//
//  Deformation.cpp
//  FBXSceneFramework
//
//  Created by  Ivan Ushakov on 18/04/2019.
//  Copyright © 2019  Ivan Ushakov. All rights reserved.
//

#include "Deformation.h"

#include <vector>

#include "Matrix.h"

namespace fbx
{
    std::string getTexture(const FbxSurfaceMaterial *material, const char *type) {
        const FbxProperty property = material->FindProperty(type);
        const int textureCount = property.GetSrcObjectCount<FbxFileTexture>();
        if (textureCount == 0) {
            throw new std::runtime_error("");
        }
        
        FbxFileTexture *texture = property.GetSrcObject<FbxFileTexture>();
        if (texture == nullptr) {
            throw new std::runtime_error("");
        }
        
        return std::string(texture->GetFileName());
    }
    
    FbxAMatrix GetGlobalPosition(FbxNode *node, const FbxTime &time) {
        return node->EvaluateGlobalTransform(time);
    }
    
    FbxAMatrix GetGeometry(FbxNode *node) {
        const FbxVector4 t = node->GetGeometricTranslation(FbxNode::eSourcePivot);
        const FbxVector4 r = node->GetGeometricRotation(FbxNode::eSourcePivot);
        const FbxVector4 s = node->GetGeometricScaling(FbxNode::eSourcePivot);
        
        return FbxAMatrix(t, r, s);
    }
    
    // Compute the transform matrix that the cluster will transform the vertex.
    void ComputeClusterDeformation(const FbxAMatrix &globalPosition,
                                   FbxMesh *mesh,
                                   FbxCluster *cluster,
                                   FbxAMatrix &vertexTransformMatrix,
                                   const FbxTime &time) {
        FbxCluster::ELinkMode clusterMode = cluster->GetLinkMode();
        
        FbxAMatrix referenceGlobalInitPosition;
        FbxAMatrix referenceGlobalCurrentPosition;
        FbxAMatrix associateGlobalInitPosition;
        FbxAMatrix associateGlobalCurrentPosition;
        FbxAMatrix clusterGlobalInitPosition;
        FbxAMatrix clusterGlobalCurrentPosition;
        
        FbxAMatrix referenceGeometry;
        FbxAMatrix associateGeometry;
        FbxAMatrix clusterGeometry;
        
        FbxAMatrix clusterRelativeInitPosition;
        FbxAMatrix clusterRelativeCurrentPositionInverse;
        
        if (clusterMode == FbxCluster::eAdditive && cluster->GetAssociateModel()) {
            cluster->GetTransformAssociateModelMatrix(associateGlobalInitPosition);
            // Geometric transform of the model
            associateGeometry = GetGeometry(cluster->GetAssociateModel());
            associateGlobalInitPosition *= associateGeometry;
            associateGlobalCurrentPosition = GetGlobalPosition(cluster->GetAssociateModel(), time);
            
            cluster->GetTransformMatrix(referenceGlobalInitPosition);
            // Multiply referenceGlobalInitPosition by Geometric Transformation
            referenceGeometry = GetGeometry(mesh->GetNode());
            referenceGlobalInitPosition *= referenceGeometry;
            referenceGlobalCurrentPosition = globalPosition;
            
            // Get the link initial global position and the link current global position.
            cluster->GetTransformLinkMatrix(clusterGlobalInitPosition);
            // Multiply clusterGlobalInitPosition by Geometric Transformation
            clusterGeometry = GetGeometry(cluster->GetLink());
            clusterGlobalInitPosition *= clusterGeometry;
            clusterGlobalCurrentPosition = GetGlobalPosition(cluster->GetLink(), time);
            
            // Compute the shift of the link relative to the reference.
            // ModelM-1 * AssoM * AssoGX-1 * LinkGX * LinkM-1 * ModelM
            vertexTransformMatrix = referenceGlobalInitPosition.Inverse() * associateGlobalInitPosition * associateGlobalCurrentPosition.Inverse() *
            clusterGlobalCurrentPosition * clusterGlobalInitPosition.Inverse() * referenceGlobalInitPosition;
        } else {
            cluster->GetTransformMatrix(referenceGlobalInitPosition);
            referenceGlobalCurrentPosition = globalPosition;
            // Multiply referenceGlobalInitPosition by Geometric Transformation
            referenceGeometry = GetGeometry(mesh->GetNode());
            referenceGlobalInitPosition *= referenceGeometry;
            
            // Get the link initial global position and the link current global position.
            cluster->GetTransformLinkMatrix(clusterGlobalInitPosition);
            clusterGlobalCurrentPosition = GetGlobalPosition(cluster->GetLink(), time);
            
            // Compute the initial position of the link relative to the reference.
            clusterRelativeInitPosition = clusterGlobalInitPosition.Inverse() * referenceGlobalInitPosition;
            
            // Compute the current position of the link relative to the reference.
            clusterRelativeCurrentPositionInverse = referenceGlobalCurrentPosition.Inverse() * clusterGlobalCurrentPosition;
            
            // Compute the shift of the link relative to the reference.
            vertexTransformMatrix = clusterRelativeCurrentPositionInverse * clusterRelativeInitPosition;
        }
    }
    
    // Deform the vertex array in classic linear way.
    void ComputeLinearDeformation(const FbxAMatrix &globalPosition,
                                  FbxMesh *mesh,
                                  const FbxTime &time,
                                  FbxVector4 *vertexArray) {
        // All the links must have the same link mode.
        FbxCluster::ELinkMode clusterMode = ((FbxSkin *)mesh->GetDeformer(0, FbxDeformer::eSkin))->GetCluster(0)->GetLinkMode();
        
        const int vertexCount = mesh->GetControlPointsCount();
        
        std::vector<FbxAMatrix> clusterDeformation(vertexCount, MatrixMakeZero());
        std::vector<double> clusterWeight(vertexCount, 0.0);
        
        if (clusterMode == FbxCluster::eAdditive) {
            for (int i = 0; i < vertexCount; i++) {
                clusterDeformation[i].SetIdentity();
            }
        }
        
        // For all skins and all clusters, accumulate their deformation and weight
        // on each vertices and store them in clusterDeformation and clusterWeight.
        const int skinCount = mesh->GetDeformerCount(FbxDeformer::eSkin);
        for (int skinIndex = 0; skinIndex < skinCount; skinIndex++) {
            FbxSkin *skinDeformer = (FbxSkin *)mesh->GetDeformer(skinIndex, FbxDeformer::eSkin);
            const int clusterCount = skinDeformer->GetClusterCount();
            for (int clusterIndex = 0; clusterIndex < clusterCount; clusterIndex++) {
                FbxCluster *cluster = skinDeformer->GetCluster(clusterIndex);
                if (!cluster->GetLink()) {
                    continue;
                }
                
                FbxAMatrix vertexTransformMatrix;
                ComputeClusterDeformation(globalPosition, mesh, cluster, vertexTransformMatrix, time);
                
                const int vertexIndexCount = cluster->GetControlPointIndicesCount();
                for (int k = 0; k < vertexIndexCount; k++) {
                    const int index = cluster->GetControlPointIndices()[k];
                    
                    // Sometimes, the mesh can have less points than at the time of the skinning
                    // because a smooth operator was active when skinning but has been deactivated during export.
                    if (index >= vertexCount) {
                        continue;
                    }
                    
                    const double weight = cluster->GetControlPointWeights()[k];
                    if (weight == 0.0) {
                        continue;
                    }
                    
                    // Compute the influence of the link on the vertex.
                    FbxAMatrix influence = vertexTransformMatrix;
                    MatrixScale(influence, weight);
                    
                    if (clusterMode == FbxCluster::eAdditive) {
                        // Multiply with the product of the deformations on the vertex.
                        MatrixAddToDiagonal(influence, 1.0 - weight);
                        clusterDeformation[index] = influence * clusterDeformation[index];
                        
                        // Set the link to 1.0 just to know this vertex is influenced by a link.
                        clusterWeight[index] = 1.0;
                    } else {
                        // Add to the sum of the deformations on the vertex.
                        MatrixAdd(clusterDeformation[index], influence);
                        
                        // Add to the sum of weights to either normalize or complete the vertex.
                        clusterWeight[index] += weight;
                    }
                }
            }
        }
        
        // Actually deform each vertices here by information stored in lClusterDeformation and lClusterWeight
        for (int i = 0; i < vertexCount; i++) {
            FbxVector4 srcVertex = vertexArray[i];
            FbxVector4 &dstVertex = vertexArray[i];
            const double weight = clusterWeight[i];
            
            // Deform the vertex if there was at least a link with an influence on the vertex,
            if (weight != 0.0) {
                dstVertex = clusterDeformation[i].MultT(srcVertex);
                if (clusterMode == FbxCluster::eNormalize) {
                    // In the normalized link mode, a vertex is always totally influenced by the links.
                    dstVertex /= weight;
                } else if (clusterMode == FbxCluster::eTotalOne) {
                    // In the total 1 link mode, a vertex can be partially influenced by the links.
                    srcVertex *= (1.0 - weight);
                    dstVertex += srcVertex;
                }
            }
        }
    }
    
    // Deform the vertex array according to the links contained in the mesh and the skinning type.
    void ComputeSkinDeformation(const FbxAMatrix &globalPosition,
                                FbxMesh *mesh,
                                const FbxTime &time,
                                FbxVector4 *vertexArray) {
        FbxSkin *skinDeformer = (FbxSkin *)mesh->GetDeformer(0, FbxDeformer::eSkin);
        FbxSkin::EType skinningType = skinDeformer->GetSkinningType();
        
        if (skinningType == FbxSkin::eLinear || skinningType == FbxSkin::eRigid) {
            ComputeLinearDeformation(globalPosition, mesh, time, vertexArray);
        }
    }
}
