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
    
    public struct Resource {
        let dimension: Int
        let data: Data
        public init(dimension: Int, data: Data) {
            self.dimension = dimension
            self.data = data
        }
    }
    
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
    
    public init(cubeName: String, bundle: Bundle = .main, intensity: Float = 1.0) {
        let resource = C7ColorCube.Resource.readCubeResource(cubeName, bundle: bundle)
        self.init(cubeResource: resource, intensity: intensity)
    }
    
    public init(cubeURL: URL, intensity: Float = 1.0) {
        let resource = C7ColorCube.Resource.readCubeResource(from: cubeURL)
        self.init(cubeResource: resource, intensity: intensity)
    }
    
    public init(cubeData: Data, dimension: Int, intensity: Float = 1.0) {
        let resource = C7ColorCube.Resource(dimension: dimension, data: cubeData)
        self.init(cubeResource: resource, intensity: intensity)
    }
    
    public init(cubeResource: C7ColorCube.Resource?, intensity: Float = 1.0) {
        self.intensity = intensity
        if let resource = cubeResource {
            self.dimension = resource.dimension
            self.lutTexture = C7ColorCube.Resource.createLUTTexture(from: resource)
        } else {
            self.dimension = 0
            self.lutTexture = nil
        }
    }
}

extension C7ColorCube.Resource {
    static func readCubeResource(from url: URL) -> C7ColorCube.Resource? {
        guard let contents = try? String(contentsOf: url),
              let dimension = C7ColorCube.Resource.takeDimension(from: contents, pattern: C7ColorCube.Resource.LUT_3D) else {
            return nil
        }
        let data = C7ColorCube.Resource.cubeData(with: contents)
        return C7ColorCube.Resource(dimension: dimension, data: data)
    }
    
    static func createLUTTexture(from resource: C7ColorCube.Resource) -> MTLTexture? {
        guard resource.dimension > 0 else {
            return nil
        }
        
        // Calculate the size of 2D texture
        let textureSize = resource.dimension * resource.dimension
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba32Float,
            width: textureSize,
            height: resource.dimension,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead]
        textureDescriptor.storageMode = .shared
        textureDescriptor.cpuCacheMode = .writeCombined
        
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
    
    /// Read Cube file resources.
    /// - Parameter name: File name
    /// - Returns: Cube resource
    public static func readCubeResource(_ name: String, bundle: Bundle = .main) -> C7ColorCube.Resource? {
        let paths = ["cube", "CUBE"].compactMap {
            bundle.path(forResource: name, ofType: $0)
        }
        guard let path = paths.first,
              let contents = try? String(contentsOfFile: path),
              let dimension = takeDimension(from: contents, pattern: LUT_3D) else {
            return nil
        }
        let data = cubeData(with: contents)
        return C7ColorCube.Resource.init(dimension: dimension, data: data)
    }
    
    /// Should be a line like `LUT_3D_SIZE 32`, get the `32`.
    public static let LUT_3D = "LUT_([0-9A-Z]+)_.* ([0-9]+)"
    
    /// The number of corresponding color data per line.
    public enum Line: Int { case rgb = 3, rgba = 4 }
    
    /// Read in data content with cube file.
    /// - Parameter contents: Cube text content.
    /// - Returns: A cube data.
    public static func cubeData(with contents: String, line: Line = .rgb) -> Data {
        let fileContents = contents.replacingOccurrences(of: "\r", with: "\n")
        let rows = fileContents.components(separatedBy: "\n")
        var data = [Float]()
        for row in rows {
            let dataStrings = row.split(separator: " ")
            guard dataStrings.count == line.rawValue else {
                continue
            }
            let floats = dataStrings.compactMap { Float($0) }
            guard floats.count == line.rawValue else {
                continue
            }
            data += floats
            switch line {
            case .rgb:
                data.append(1.0)
            case .rgba:
                break
            }
        }
        let resultData = data.withUnsafeBufferPointer { Data(buffer: $0) }
        return resultData
    }
    
    /// Regular match detect LUT Size.
    /// - Parameters:
    ///   - string: Data to be matched.
    ///   - pattern: Detect the regex of LUT size.
    /// - Returns: LUT size.
    public static func takeDimension(from string: String, pattern: String) -> Int? {
        guard string.isEmpty == false,
              let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let range = NSRange(location: 0, length: string.count)
        guard let matched = regex.firstMatch(in: string, options: [], range: range) else {
            return nil
        }
        let index = max(0, matched.numberOfRanges - 1)
        let numberString = (string as NSString).substring(with: matched.range(at: index))
        guard let dimension = Int(numberString), dimension > 0, dimension <= 65 else {
            return nil
        }
        return dimension
    }
}
