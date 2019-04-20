//
//  Scene.cpp
//  FBXSceneFramework
//
//  Created by  Ivan Ushakov on 18/04/2019.
//  Copyright © 2019  Ivan Ushakov. All rights reserved.
//

#include "Scene.h"

Scene::Scene() : needDisplay_(false) {}

void Scene::load(const std::string &path) {
    FbxManager *manager = FbxManager::Create();
    
    FbxIOSettings *settings = FbxIOSettings::Create(manager, IOSROOT);
    manager->SetIOSettings(settings);
    
    FbxImporter *importer = FbxImporter::Create(manager, "");
    
    if (!importer->Initialize(path.c_str(), -1, manager->GetIOSettings())) {
        throw std::runtime_error("");
    }
    
    scene_ = FbxScene::Create(manager, "Scene");
    if (!importer->Import(scene_)) {
        throw std::runtime_error("");
    }
    
    // Convert Axis System to what is used in this example, if needed
    FbxAxisSystem SceneAxisSystem = scene_->GetGlobalSettings().GetAxisSystem();
    FbxAxisSystem OurAxisSystem(FbxAxisSystem::eYAxis, FbxAxisSystem::eParityOdd, FbxAxisSystem::eRightHanded);
    if (SceneAxisSystem != OurAxisSystem) {
        OurAxisSystem.ConvertScene(scene_);
    }
    
    FbxGeometryConverter converter(manager);
    converter.Triangulate(scene_, true);
    
    loadCacheRecursive(scene_->GetRootNode());
    
    frameTime_.SetTime(0, 0, 0, 1, 0, scene_->GetGlobalSettings().GetTimeMode());
    
    scene_->FillAnimStackNameArray(animStackNameArray_);
    
    // select the base layer from the animation stack
    FbxAnimStack *currentAnimationStack = scene_->FindMember<FbxAnimStack>(animStackNameArray_[0]->Buffer());
    if (currentAnimationStack == NULL) {
        throw std::runtime_error("");
    }
    
    // we assume that the first animation layer connected to the animation stack is the base layer
    // (this is the assumption made in the FBXSDK)
    scene_->SetCurrentAnimationStack(currentAnimationStack);
    
    start_ = 0;
    stop_ = start_ + frameTime_;
    
    currentTime_ = start_;
    
    importer->Destroy();
}

void Scene::onTimerClick() {
    if (currentTime_ < stop_) {
        currentTime_ += frameTime_;
        needDisplay_ = true;
    } else {
        needDisplay_ = false;
    }
}

void Scene::onDisplay() {
    if (!needDisplay_) {
        return;
    }
    
    FbxAMatrix dummyGlobalPosition;
    drawNodeRecursive(scene_->GetRootNode(), currentTime_, dummyGlobalPosition);
}

void Scene::loadCacheRecursive(FbxNode *node) {
    FbxNodeAttribute *nodeAttribute = node->GetNodeAttribute();
    if (nodeAttribute) {
        if (nodeAttribute->GetAttributeType() == FbxNodeAttribute::eMesh) {
            FbxMesh *mesh = node->GetMesh();
            
            mesh_.emplace_back(std::make_unique<SimpleMesh>());
            
            auto &m = mesh_.back();
            
            m->vertexCount = mesh->GetControlPointsCount();
            m->indexCount = 3 * mesh->GetPolygonCount();
            
            FbxLayerElementArrayTemplate<int> *materialIndice = &mesh->GetElementMaterial()->GetIndexArray();
            
            int materialIndex = materialIndice->GetAt(0);
            const FbxSurfaceMaterial *material = node->GetMaterial(materialIndex);
            
            m->albedoTexture = fbx::getTexture(material, FbxSurfaceMaterial::sDiffuse);
            
            mesh->SetUserDataPtr(m.get());
        }
    }
    
    const int childCount = node->GetChildCount();
    for (int childIndex = 0; childIndex < childCount; childIndex++) {
        loadCacheRecursive(node->GetChild(childIndex));
    }
}

void Scene::drawNodeRecursive(FbxNode *node, FbxTime &time, FbxAMatrix &parentGlobalPosition) {
    FbxAMatrix globalPosition = node->EvaluateGlobalTransform(time);
    if (node->GetNodeAttribute()) {
        // Geometry offset. It is not inherited by the children.
        FbxAMatrix geometryOffset = fbx::GetGeometry(node);
        FbxAMatrix globalOffPosition = globalPosition * geometryOffset;
        
        drawNode(node, time, parentGlobalPosition, globalOffPosition);
    }
    
    const int childCount = node->GetChildCount();
    for (int childIndex = 0; childIndex < childCount; childIndex++) {
        drawNodeRecursive(node->GetChild(childIndex), time, globalPosition);
    }
}

void Scene::drawNode(FbxNode *node, FbxTime &time, FbxAMatrix &parentGlobalPosition, FbxAMatrix &globalPosition) {
    const FbxNodeAttribute *nodeAttribute = node->GetNodeAttribute();
    if (nodeAttribute->GetAttributeType() == FbxNodeAttribute::eMesh) {
        drawMesh(node, time, globalPosition);
    }
}

void Scene::drawMesh(FbxNode *node, FbxTime &time, FbxAMatrix &globalPosition) {
    FbxMesh *mesh = node->GetMesh();
    const int vertexCount = mesh->GetControlPointsCount();
    
    // No vertex to draw.
    if (vertexCount == 0) {
        return;
    }
    
    if (mesh->GetElementUVCount() == 0) {
        return;
    }
    
    if (mesh->GetElementUV(0)->GetMappingMode() != FbxGeometryElement::eByPolygonVertex) {
        return;
    }
    
    if (mesh->GetElementNormalCount() == 0) {
        return;
    }
    
    if (mesh->GetElementNormal(0)->GetMappingMode() != FbxGeometryElement::eByPolygonVertex) {
        return;
    }
    
    // If it has some defomer connection, update the vertices position
    const bool hasVertexCache = mesh->GetDeformerCount(FbxDeformer::eVertexCache) &&
    (static_cast<FbxVertexCacheDeformer *>(mesh->GetDeformer(0, FbxDeformer::eVertexCache)))->Active.Get();
    const bool hasShape = mesh->GetShapeCount() > 0;
    const bool hasSkin = mesh->GetDeformerCount(FbxDeformer::eSkin) > 0;
    const bool hasDeformation = hasVertexCache || hasShape || hasSkin;
    
    std::vector<FbxVector4> vertexArray(vertexCount);
    memcpy(vertexArray.data(), mesh->GetControlPoints(), vertexCount * sizeof(FbxVector4));
    
    if (hasDeformation) {
        // Active vertex cache deformer will overwrite any other deformer
        if (hasVertexCache) {
            throw std::runtime_error("");
        } else {
            if (hasShape) {
                throw std::runtime_error("");
            }
            
            // we need to get the number of clusters
            const int skinCount = mesh->GetDeformerCount(FbxDeformer::eSkin);
            int clusterCount = 0;
            for (int skinIndex = 0; skinIndex < skinCount; skinIndex++) {
                clusterCount += ((FbxSkin *)(mesh->GetDeformer(skinIndex, FbxDeformer::eSkin)))->GetClusterCount();
            }
            if (clusterCount) {
                // Deform the vertex array with the skin deformer.
                fbx::ComputeSkinDeformation(globalPosition, mesh, time, vertexArray.data());
            }
        }
    }
    
    SimpleMesh *m = static_cast<SimpleMesh *>(mesh->GetUserDataPtr());
    
    const auto& gp = globalPosition;
    m->position = simd_float4x4{{
        {static_cast<float>(gp.Get(0, 0)), static_cast<float>(gp.Get(0, 1)), static_cast<float>(gp.Get(0, 2)), static_cast<float>(gp.Get(0, 3))},
        {static_cast<float>(gp.Get(1, 0)), static_cast<float>(gp.Get(1, 1)), static_cast<float>(gp.Get(1, 2)), static_cast<float>(gp.Get(1, 3))},
        {static_cast<float>(gp.Get(2, 0)), static_cast<float>(gp.Get(2, 1)), static_cast<float>(gp.Get(2, 2)), static_cast<float>(gp.Get(2, 3))},
        {static_cast<float>(gp.Get(3, 0)), static_cast<float>(gp.Get(3, 1)), static_cast<float>(gp.Get(3, 3)), static_cast<float>(gp.Get(3, 3))}
    }};
    
    const int polygonCount = mesh->GetPolygonCount();
    size_t indexArrayPosition = 0;
    for (int polygonIndex = 0; polygonIndex < polygonCount; polygonIndex++) {
        for (int verticeIndex = 0; verticeIndex < 3; verticeIndex++) {
            const int controlPointIndex = mesh->GetPolygonVertex(polygonIndex, verticeIndex);
            Vertex &v = m->vertexArray[controlPointIndex];
            
            const FbxVector4 &p = vertexArray[controlPointIndex];
            v.position = simd::float3 {
                static_cast<float>(p[0]),
                static_cast<float>(p[1]),
                static_cast<float>(p[2])
            };
            
            m->maxBounds.x = std::max(m->maxBounds.x, v.position.x);
            m->maxBounds.y = std::max(m->maxBounds.y, v.position.y);
            m->maxBounds.z = std::max(m->maxBounds.z, v.position.z);
            
            m->minBounds.x = std::min(m->minBounds.x, v.position.x);
            m->minBounds.y = std::min(m->minBounds.y, v.position.y);
            m->minBounds.z = std::min(m->minBounds.z, v.position.z);
            
            FbxVector2 uv;
            bool unmapped = false;
            mesh->GetPolygonVertexUV(polygonIndex, verticeIndex, "UVChannel_1", uv, unmapped);
            v.uv = simd::float2 {
                static_cast<float>(uv[0]),
                static_cast<float>(uv[1])
            };
            
            FbxVector4 normal;
            mesh->GetPolygonVertexNormal(polygonIndex, verticeIndex, normal);
            v.normal = simd::float3 {
                static_cast<float>(normal[0]),
                static_cast<float>(normal[1]),
                static_cast<float>(normal[2])
            };
            
            m->indexArray[indexArrayPosition++] = mesh->GetPolygonVertex(polygonIndex, verticeIndex);
        }
    }
}
