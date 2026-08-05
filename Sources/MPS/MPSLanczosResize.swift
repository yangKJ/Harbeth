//
//  MPSLanczosResize.swift
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

import Foundation
import MetalPerformanceShaders

/// 使用 MPS Lanczos 重采样的精确尺寸缩放原子。
///
/// 没有设置 `scaleTransform`，因此 MPS 会把整个源纹理精确映射到
/// `resize(input:)` 声明的目标纹理尺寸。
public struct MPSLanczosResize: MPSKernelProtocol {

    public static let maximumDimension = 16_384

    public let width: Int
    public let height: Int
    public let edgeMode: MPSImageEdgeMode

    public var modifier: ModifierEnum {
        .mps(performance: lanczos)
    }

    public var factors: [Float] {
        [Float(width), Float(height), Float(edgeMode.rawValue)]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }

    public var samplingFootprint: SamplingFootprint {
        .global
    }

    public var kernelPixelContract: KernelPixelContract {
        .init(
            samplingFootprint: .global,
            coordinateDependency: .fullImage,
            globalDependency: .imageDimensions
        )
    }

    public init(width: Int, height: Int, edgeMode: MPSImageEdgeMode = .clamp) throws {
        guard (1...Self.maximumDimension).contains(width),
              (1...Self.maximumDimension).contains(height) else {
            throw HarbethError.filterParameterInvalid(
                "MPSLanczosResize width and height must be within 1...\(Self.maximumDimension)."
            )
        }
        self.width = width
        self.height = height
        self.edgeMode = edgeMode
        self.lanczos = MPSImageLanczosScale(device: HarbethContext.shared.device)
        self.lanczos.edgeMode = edgeMode
    }

    public func resize(input size: C7Size) -> C7Size {
        C7Size(width: width, height: height)
    }

    public func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        let (destination, source) = try mpsTexturePair(from: textures)
        guard destination.width == width, destination.height == height else {
            throw HarbethError.textureSizeMismatch
        }
        lanczos.encode(commandBuffer: commandBuffer, sourceTexture: source, destinationTexture: destination)
        return destination
    }

    private let lanczos: MPSImageLanczosScale
}
