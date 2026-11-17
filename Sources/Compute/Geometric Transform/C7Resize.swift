//
//  C7Resize.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

/// Pull and compress the picture, the picture will be distorted
public struct C7Resize: C7FilterProtocol, GeometryParameterValidating {
    
    public var width: Float
    public var height: Float
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7Resize")
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }
    
    public var samplingFootprint: SamplingFootprint { .global }
    public var kernelPixelContract: KernelPixelContract {
        .init(precision: .float32,
              dynamicRangeBehavior: .preservesExtendedRange, samplingFootprint: .global,
              coordinateDependency: .fullImage, globalDependency: .imageDimensions)
    }

    func validateGeometryParameters() throws { try validateResizeDimensions(width, height) }

    public func resize(input size: C7Size) -> C7Size {
        return Placement.fit.resize(width: width, height: height, size: size)
    }
    
    public init(size: CGSize) {
        self.width = Float(size.width)
        self.height = Float(size.height)
    }
    
    public init(width: Float, height: Float) {
        self.width = width
        self.height = height
    }
}
