//
//  C7ColorCube.swift
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

import Foundation
import MetalKit

/// 3D LUT颜色立方体滤镜
/// 使用Metal实现的CUBE文件格式LUT滤镜
public struct C7ColorCube: C7FilterProtocol {
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7ColorCube")
    }
    
    public var factors: [Float] {
        return [intensity]
    }
    
    public var otherInputTextures: C7InputTextures {
        return lutTexture == nil ? [] : [lutTexture!]
    }
    
    private let lutTexture: MTLTexture?
    private let dimension: Int
    
    public init(cubeName: String, bundle: Bundle = .main) {
        let resource = CIColorCube.Resource.readCubeResource(cubeName, bundle: bundle)
        self.init(cubeResource: resource)
    }
    
    public init(cubeResource: CIColorCube.Resource?) {
        if let resource = cubeResource {
            self.dimension = resource.dimension
            self.lutTexture = C7ColorCube.createLUTTexture(from: resource)
        } else {
            self.dimension = 0
            self.lutTexture = nil
        }
    }
    
    private static func createLUTTexture(from resource: CIColorCube.Resource) -> MTLTexture? {
        guard resource.dimension > 0 else {
            return nil
        }
        // Calculate the size of 2D texture.
        let textureSize = resource.dimension * resource.dimension
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba32Float,
            width: textureSize,
            height: resource.dimension,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead]
        
        guard let texture = Device.device().makeTexture(descriptor: textureDescriptor) else {
            return nil
        }
        
        // Calculate byte per row
        let bytesPerPixel = 4 * MemoryLayout<Float>.size
        let bytesPerRow = textureSize * bytesPerPixel
        
        // Copy data to texture
        resource.data.withUnsafeBytes { buffer in
            let floatBuffer = buffer.bindMemory(to: Float.self)
            guard let baseAddress = floatBuffer.baseAddress else {
                return
            }
            texture.replace(region: MTLRegionMake2D(0, 0, textureSize, resource.dimension),
                            mipmapLevel: 0,
                            withBytes: baseAddress,
                            bytesPerRow: bytesPerRow)
        }
        
        return texture
    }
}
