//
//  Material.swift
//  MetalPBRDemo
//
//  Created by  Ivan Ushakov on 30/07/2019.
//  Copyright © 2019  Ivan Ushakov. All rights reserved.
//

import MetalKit

enum MaterialError: Error {
    case general
}

protocol Material {
    func setTextures(encoder: MTLRenderCommandEncoder)
}

class PBRMaterial: Material {
    
    private let textures: [PBRTextureType : MTLTexture]
    
    fileprivate init(textures: [PBRTextureType : MTLTexture]) throws {
        self.textures = textures
    }
    
    func setTextures(encoder: MTLRenderCommandEncoder) {
        encoder.setFragmentTexture(textures[.baseColor], index: 0)
        encoder.setFragmentTexture(textures[.metallic], index: 1)
        encoder.setFragmentTexture(textures[.roughness], index: 2)
        encoder.setFragmentTexture(textures[.ambientOcclusion], index: 3)
        encoder.setFragmentTexture(textures[.normal], index: 4)
    }
}

class PBRMaterialLoader {
    
    func load(device: MTLDevice, path: URL) throws -> [String : PBRMaterial] {
        let data = try Data(contentsOf: path)
        
        let decoder = JSONDecoder()
        let descriptor = try decoder.decode(MaterialDescriptor.self, from: data)
        
        let textureLoader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option : Any] = [
            .allocateMipmaps: true,
            .generateMipmaps: true,
            .SRGB: false,
            .origin: MTKTextureLoader.Origin.flippedVertically
        ]
        
        let baseUrl = path.deletingLastPathComponent()
        var result = [String : PBRMaterial]()

        try descriptor.objects.forEach { object in
            var textures = [PBRTextureType : MTLTexture]()
            try object.attributes.forEach { attribute in
                if let type = PBRTextureType(rawValue: attribute.name) {
                    let url = baseUrl.appendingPathComponent(attribute.value)
                    textures[type] = try textureLoader.newTexture(URL: url, options: options)
                }
            }
            result[object.name] = try PBRMaterial(textures: textures)
        }
        
        return result
    }
}

private enum PBRTextureType: String, CaseIterable {
    case baseColor, metallic, roughness, ambientOcclusion, normal
}

private struct MaterialAttribute: Codable {
    var name: String
    var value: String
}

private struct MaterialObject: Codable {
    var name: String
    var attributes: [MaterialAttribute]
}

private struct MaterialDescriptor: Codable {
    var objects: [MaterialObject]
}
