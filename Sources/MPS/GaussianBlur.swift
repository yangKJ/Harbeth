//
//  GaussianBlur.swift
//  Harbeth
//
//  Created by Condy on 2026/10/12.
//

import Foundation
import MetalPerformanceShaders

public enum GaussianBlurError: Error, Equatable {
    case invalidSigma
}

/// sigma直接使用像素标准差，不将小数参数取整；边界与halo由同一原子声明。
public struct GaussianBlur: MPSKernelProtocol {
    public let sigma: Float
    public let edgeMode: MPSImageEdgeMode
    private let gaussian: MPSImageGaussianBlur

    public init(sigma: Float = 5, edgeMode: MPSImageEdgeMode = .clamp) throws {
        guard sigma.isFinite, sigma > 0, sigma <= 100 else { throw GaussianBlurError.invalidSigma }
        self.sigma = sigma
        self.edgeMode = edgeMode
        let gaussian = MPSImageGaussianBlur(device: HarbethContext.shared.device, sigma: sigma)
        gaussian.edgeMode = edgeMode
        self.gaussian = gaussian
    }

    public var factors: [Float] { [sigma, Float(edgeMode.rawValue)] }

    public var modifier: ModifierEnum { .mps(performance: gaussian) }

    public var samplingFootprint: SamplingFootprint {
        .neighborhood(radius: Self.conservativeHaloRadius(for: sigma))
    }

    public static func conservativeHaloRadius(for sigma: Float) -> Int {
        guard sigma.isFinite, sigma > 0, sigma <= 100 else { return 0 }
        return Int(ceil(sigma * 4))
    }

    public var kernelPixelContract: KernelPixelContract {
        .init(samplingFootprint: samplingFootprint)
    }

    public func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        let destination = textures[0], source = textures[1]
        gaussian.encode(commandBuffer: commandBuffer, sourceTexture: source, destinationTexture: destination)
        return destination
    }
}
