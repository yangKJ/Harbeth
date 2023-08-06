//
//  CILookupTable.swift
//  Harbeth
//
//  Created by Condy on 2023/8/5.
//

import Foundation
import CoreImage

/// Read cube data and dimension, and then apply to CIImage.
/// A Filter using LUT Image (backed by CIColorCubeWithColorSpace)
/// About LUT Image -> https://en.wikipedia.org/wiki/Lookup_table
public struct CILookupTable: C7FilterProtocol, CoreImageProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: -5.0, max: 5.0, value: 1.0)
    
    public var amount: Float = range.value
    
    public var modifier: Modifier {
        return .coreimage(CIName: "CISourceOverCompositing")
    }
    
    public func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage {
        guard let cubeResource = cubeResource else {
            throw CustomError.cubeResource
        }
        let cubeFilter = CIFilter(name: "CIColorCubeWithColorSpace", parameters: [
            kCIInputImageKey: ciImage,
            "inputCubeData" : cubeResource.data,
            "inputCubeDimension": cubeResource.dimension,
            "inputColorSpace": Device.colorSpace()
        ])
        guard let outputImage = cubeFilter?.outputImage else {
            throw CustomError.outputCIImage("CIColorCubeWithColorSpace")
        }
        let foreground = outputImage.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(amount)),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0),
        ])
        filter.setValue(ciImage, forKey: kCIInputBackgroundImageKey)
        return foreground
    }
    
    private let cubeResource: CIColorCube.Resource?
    
    public init(cubeName: String, amount: Float = range.value) {
        let resource = CIColorCube.Resource.readCubeResource(cubeName)
        self.init(cubeResource: resource, amount: amount)
    }
    
    public init(cubeResource: CIColorCube.Resource?, amount: Float = range.value) {
        self.cubeResource = cubeResource
        self.amount = amount
    }
}
