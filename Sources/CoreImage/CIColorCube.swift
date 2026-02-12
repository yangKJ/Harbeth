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
    
    public var modifier: ModifierEnum {
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
    
    private let cubeResource: C7ColorCube.Resource?
    
    public init(cubeName: String) {
        let cubeResource = C7ColorCube.Resource.readCubeResource(cubeName)
        self.init(cubeResource: cubeResource)
    }
    
    public init(cubeResource: C7ColorCube.Resource?) {
        self.cubeResource = cubeResource
    }
}
