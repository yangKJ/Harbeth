//
//  C7LanczosResize.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation

public struct C7LanczosResize: C7FilterProtocol, GeometryParameterValidating, TemporaryTextureRequirementProviding {

    public var width: Float
    public var height: Float

    public var modifier: ModifierEnum {
        .compute(kernel: "C7LanczosResize")
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }

    public var samplingFootprint: SamplingFootprint { .global }
    public var kernelPixelContract: KernelPixelContract {
        .init(inputAlphaExpectation: .premultiplied, precision: .float32,
              dynamicRangeBehavior: .preservesExtendedRange, samplingFootprint: .global,
              coordinateDependency: .fullImage, globalDependency: .imageDimensions)
    }
    public var kernelOutputContract: RenderOutputContract { .premultipliedColorInput }

    func validateGeometryParameters() throws { try validateResizeDimensions(width, height) }

    public func resize(input size: C7Size) -> C7Size {
        Placement.fit.resize(width: width, height: height, size: size)
    }

    func temporaryTextureRequirement(inputSize: C7Size) -> (bytes: Int, count: Int) {
        guard let scratch = LanczosResampling.scratch(input: inputSize, output: resize(input: inputSize), limit: LanczosResampling.byteLimit) else { return (0, 0) }
        return (scratch.bytes, 1)
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
