//
//  Renderer.swift
//  MetalCube
//
//  Created by  Ivan Ushakov on 13/04/2019.
//  Copyright © 2019  Ivan Ushakov. All rights reserved.
//

import MetalKit
import FBXSceneFramework

class Renderer {
    
    private let layer: CAMetalLayer
    private let scene: FBXScene
    
    private var commandQueue: MTLCommandQueue?
    private var renderPipeline: MTLRenderPipelineState?
    private var depthState: MTLDepthStencilState?
    private var depthTexture: MTLTexture?
    
    private var nodes = [SceneNode]()
    private var projectionMatrix = simd_float4x4()
    private var frameNumber = 0
    
    init(layer: CAMetalLayer, scene: FBXScene) {
        self.layer = layer
        self.scene = scene
        
        setupMetal()
        
        do {
            try createPipeline()
        } catch {
            print("Renderer: can't create pipeline: \(error)")
        }
    }
    
    func setupScene() {
        guard let device = layer.device else { return }
        
        guard let lightBuffer = device.makeBuffer(length: MemoryLayout<LightStore>.size, options: .storageModeShared) else {
            fatalError()
        }
        
        for i in 0..<scene.getMeshCount() {
            let b1 = scene.getVertexData(i)
            guard let vertexBuffer = device.makeBuffer(length: b1.size, options: .storageModeShared) else {
                fatalError()
            }
            
            let b2 = self.scene.getIndexData(i)
            guard let indexBuffer = device.makeBuffer(length: b2.size, options: .storageModeShared) else {
                fatalError()
            }
            
            guard let uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.size, options: .storageModeShared) else {
                fatalError()
            }
            
            do {
                let albedoUrl = URL(fileURLWithPath: scene.getAlbedoTexturePath(i))
                let albedoTexture = try loadTGATexture(device: device, path: albedoUrl.path)
                
                let name = albedoUrl.lastPathComponent
                let path = albedoUrl.deletingLastPathComponent()
                
                let metallicUrl = path.appendingPathComponent(name.replacingOccurrences(of: "BaseColor", with: "Metallic"))
                let metallicTexture = try loadTGATexture(device: device, path: metallicUrl.path)
                
                let roughnessUrl = path.appendingPathComponent(name.replacingOccurrences(of: "BaseColor", with: "Roughness"))
                let roughnessTexture = try loadTGATexture(device: device, path: roughnessUrl.path)
                
                let aoUrl = path.appendingPathComponent(name.replacingOccurrences(of: "BaseColor", with: "AO"))
                let aoTexture = try loadTGATexture(device: device, path: aoUrl.path)
                
                let normalUrl = path.appendingPathComponent(name.replacingOccurrences(of: "BaseColor", with: "Normal"))
                let normalTexture = try loadTGATexture(device: device, path: normalUrl.path)
                
                nodes.append(SceneNode(vertexBuffer: vertexBuffer,
                                       indexCount: scene.getIndexCount(i),
                                       indexBuffer: indexBuffer,
                                       albedoTexture: albedoTexture,
                                       metallicTexture: metallicTexture,
                                       roughnessTexture: roughnessTexture,
                                       aoTexture: aoTexture,
                                       normalTexture: normalTexture,
                                       uniformBuffer: uniformBuffer,
                                       lightBuffer: lightBuffer))
            } catch {
                print("Renderer: \(error)")
            }
        }
    }
    
    func draw() {
        guard let drawable = layer.nextDrawable() else { return }
        
        if depthTexture?.width != Int(layer.drawableSize.width) ||
            depthTexture?.height != Int(layer.drawableSize.height) {
            buildDepthTexture()
        }
        
        let renderPass = createRenderPassWithColorAttachmentTexture(drawable.texture)
        
        guard let commandBuffer = commandQueue?.makeCommandBuffer(),
            let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass),
            let pipelineState = renderPipeline else { return }
        
        commandEncoder.setRenderPipelineState(pipelineState)
        commandEncoder.setDepthStencilState(depthState)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        setupLight(scene: scene, buffer: nodes[0].lightBuffer)
        drawNodesWithCommandEncoder(commandEncoder)
        
        commandEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func setupMetal() {
        layer.device = MTLCreateSystemDefaultDevice()
        layer.pixelFormat = .bgra8Unorm
    }
    
    private func createPipeline() throws {
        guard let device = layer.device else { return }
        
        commandQueue = device.makeCommandQueue()
        
        let vertexDescriptor = MTLVertexDescriptor()
        
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[0].offset = 0
        
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[1].offset = 16
        
        vertexDescriptor.attributes[2].format = .float3
        vertexDescriptor.attributes[2].bufferIndex = 0
        vertexDescriptor.attributes[2].offset = 24
        
        vertexDescriptor.layouts[0].stride = 48
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        guard let library = device.makeDefaultLibrary() else {
            return
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertex_shader")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragment_shader")
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        renderPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.isDepthWriteEnabled = true
        depthDescriptor.depthCompareFunction = .less
        
        depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
    }
    
    private func buildDepthTexture() {
        guard let device = layer.device else { return }
        
        let size = layer.drawableSize
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        
        descriptor.usage = .renderTarget
        descriptor.storageMode = .private
        
        depthTexture = device.makeTexture(descriptor: descriptor)
        
        setProjection(size)
    }
    
    private func setProjection(_ size: CGSize) {
        let aspect = Float(size.width / size.height)
        projectionMatrix = matrix_perspective_projection(aspect: aspect, fovy: 65.0 * (Float.pi / 180.0), near: 1.0, far: 150.0)
    }
    
    private func createRenderPassWithColorAttachmentTexture(_ texture: MTLTexture) -> MTLRenderPassDescriptor {
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = texture
        renderPass.colorAttachments[0].loadAction = .clear
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
        
        renderPass.depthAttachment.texture = depthTexture
        renderPass.depthAttachment.loadAction = .clear
        renderPass.depthAttachment.storeAction = .store
        renderPass.depthAttachment.clearDepth = 1.0
        
        return renderPass
    }
    
    private func drawNodesWithCommandEncoder(_ encoder: MTLRenderCommandEncoder) {
        frameNumber += 1
        
        scene.render()
        
        for i in 0..<scene.getMeshCount() {
            let b1 = scene.getVertexData(i)
            self.nodes[i].vertexBuffer.contents().copyMemory(from: b1.address, byteCount: b1.size)
            
            let b2 = scene.getIndexData(i)
            self.nodes[i].indexBuffer.contents().copyMemory(from: b2.address, byteCount: b2.size)
        }
        
        let eyePosition = simd_float3(0.0, 2.0, 5.0)
        
        let cameraRotationRadians = Float(frameNumber) * 0.0025
        let cameraRotationAxis = simd_float3(0.0, 1.0, 0.0)
        let cameraRotationMatrix = matrix_rotation(axis: cameraRotationAxis, angle: cameraRotationRadians)
        
        let viewMatrix = matrix_look_at_right_hand(eye: eyePosition,
                                                   target: simd_float3(0.0, 2.0, 0.0),
                                                   up: simd_float3(0.0, 1.0, 0.0)) * cameraRotationMatrix
        
        for i in 0..<scene.getMeshCount() {
            let node = nodes[i]
            
            let p = node.uniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: MemoryLayout<Uniforms>.size)
            
            p.pointee.projection_matrix = projectionMatrix
            p.pointee.view_matrix = viewMatrix
            p.pointee.model_matrix = scene.getTransformation(i)
            p.pointee.camera_position = eyePosition
            
            encoder.setVertexBuffer(node.vertexBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(node.uniformBuffer, offset: 0, index: 1)
            
            encoder.setFragmentBuffer(node.lightBuffer, offset: 0, index: 0)
            
            encoder.setFragmentTexture(node.albedoTexture, index: 0)
            encoder.setFragmentTexture(node.metallicTexture, index: 1)
            encoder.setFragmentTexture(node.roughnessTexture, index: 2)
            encoder.setFragmentTexture(node.aoTexture, index: 3)
            encoder.setFragmentTexture(node.normalTexture, index: 4)
            
            encoder.drawIndexedPrimitives(type: .triangle,
                                          indexCount: node.indexCount,
                                          indexType: .uint32,
                                          indexBuffer: node.indexBuffer,
                                          indexBufferOffset: 0)
        }
    }
    
    private func setupLight(scene: FBXScene, buffer: MTLBuffer) {
        var minBounds = simd_float3()
        var maxBounds = simd_float3()
        
        for i in 0..<scene.getMeshCount() {
            let meshMinBounds = scene.minBounds(i)
            minBounds.x = min(minBounds.x, meshMinBounds.x)
            minBounds.y = min(minBounds.y, meshMinBounds.y)
            minBounds.z = min(minBounds.z, meshMinBounds.z)
            
            let meshMaxBounds = scene.maxBounds(i)
            maxBounds.x = max(maxBounds.x, meshMaxBounds.x)
            maxBounds.y = max(maxBounds.y, meshMaxBounds.y)
            maxBounds.z = max(maxBounds.z, meshMaxBounds.z)
        }
        
        let color = simd_float3(50.0, 50.0, 50.0)
        
        let p = buffer.contents().bindMemory(to: LightStore.self, capacity: MemoryLayout<LightStore>.size)
        p.pointee.entry.0.position = simd_float3(minBounds.x, minBounds.y, 10.0)
        p.pointee.entry.0.color = color
        
        p.pointee.entry.1.position = simd_float3(minBounds.x, maxBounds.y, 10.0)
        p.pointee.entry.1.color = color
        
        p.pointee.entry.2.position = simd_float3(maxBounds.x, minBounds.y, 10.0)
        p.pointee.entry.2.color = color
        
        p.pointee.entry.3.position = simd_float3(maxBounds.x, maxBounds.y, 10.0)
        p.pointee.entry.3.color = color
    }
    
    private func loadTGATexture(device: MTLDevice, path: String) throws -> MTLTexture {
        let file = TGAFile()
        try file.load(path)
        
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2D
        descriptor.pixelFormat = .bgra8Unorm
        descriptor.width = file.width
        descriptor.height = file.height
        descriptor.mipmapLevelCount = 1
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            fatalError()
        }
        
        let size = MTLSize(width: file.width, height: file.height, depth: 1)
        let region = MTLRegion(origin: MTLOriginMake(0, 0, 0), size: size)
        texture.replace(region: region, mipmapLevel: 0, withBytes: file.data, bytesPerRow: 4 * file.width)
        
        return texture
    }
}

private struct SceneNode {
    var vertexBuffer: MTLBuffer
    var indexCount: Int
    var indexBuffer: MTLBuffer
    var albedoTexture: MTLTexture
    var metallicTexture: MTLTexture
    var roughnessTexture: MTLTexture
    var aoTexture: MTLTexture
    var normalTexture: MTLTexture
    var uniformBuffer: MTLBuffer
    var lightBuffer: MTLBuffer
}
