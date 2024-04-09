//
//  CIColorCube.swift
//  Harbeth
//
//  Created by Condy on 2023/8/5.
//

import Foundation
import CoreImage

/// 读取Cube文件的查找滤镜
public struct CIColorCube: CoreImageProtocol {
    
    public struct Resource {
        let dimension: Int
        let data: Data
        public init(dimension: Int, data: Data) {
            self.dimension = dimension
            self.data = data
        }
    }
    
    public var modifier: Modifier {
        return .coreimage(CIName: "CIColorCubeWithColorSpace")
    }
    
    public func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage {
        guard let cubeResource = cubeResource else {
            throw HarbethError.cubeResource
        }
        filter.setValue(cubeResource.data, forKey: "inputCubeData")
        filter.setValue(cubeResource.dimension, forKey: "inputCubeDimension")
        filter.setValue(Device.colorSpace(), forKey: "inputColorSpace")
        return ciImage
    }
    
    private let cubeResource: Resource?
    
    public init(cubeName: String) {
        let cubeResource = CIColorCube.Resource.readCubeResource(cubeName)
        self.init(cubeResource: cubeResource)
    }
    
    public init(cubeResource: Resource?) {
        self.cubeResource = cubeResource
    }
}

extension CIColorCube.Resource {
    /// Read Cube file resources.
    /// - Parameter name: File name
    /// - Returns: Cube resource
    public static func readCubeResource(_ name: String, bundle: Bundle = .main) -> CIColorCube.Resource? {
        let paths = ["cube", "CUBE"].compactMap {
            bundle.path(forResource: name, ofType: $0)
        }
        guard let path = paths.first,
              let contents = try? String(contentsOfFile: path),
              let dimension = takeDimension(from: contents, pattern: LUT_3D) else {
            return nil
        }
        let data = cubeData(with: contents)
        return CIColorCube.Resource.init(dimension: dimension, data: data)
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
