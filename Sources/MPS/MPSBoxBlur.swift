//
//  MPSBoxBlur.swift
//  Harbeth
//
//  Created by Condy on 2024/3/3.
//

import Foundation
import MetalPerformanceShaders

public struct MPSBoxBlur: C7FilterProtocol, MPSKernelProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0, max: 100, value: 10)
    
    /// The radius determines how many pixels are used to create the blur.
    @Clamping(range.min...range.max) public var radius: Float = range.value {
        didSet {
            let kernelSize = MPSBoxBlur.roundToOdd(radius)
            self.boxBlur = MPSImageBox(device: Device.device(), kernelWidth: kernelSize, kernelHeight: kernelSize)
        }
    }
    
    public var modifier: Modifier {
        return .mps(performance: self.boxBlur)
    }
    
    public func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        let destinationTexture = textures[0]
        let sourceTexture = textures[1]
        self.boxBlur.encode(commandBuffer: commandBuffer, sourceTexture: sourceTexture, destinationTexture: destinationTexture)
        return destinationTexture
    }
    
    private var boxBlur: MPSImageBox
    
    public init(radius: Float = range.value) {
        let kernelSize = MPSBoxBlur.roundToOdd(radius)
        self.boxBlur = MPSImageBox(device: Device.device(), kernelWidth: kernelSize, kernelHeight: kernelSize)
    }
    
    // MPS box blur kernels need to be odd
    static func roundToOdd(_ number: Float) -> Int {
        return 2 * Int(floor(number / 2.0)) + 1
    }
}
