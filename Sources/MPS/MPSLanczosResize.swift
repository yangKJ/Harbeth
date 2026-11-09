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
/// 默认映射完整源纹理；显式 sourceRect 可把取景区域直接重采样到目标尺寸。
public struct MPSLanczosResize: MPSKernelProtocol {

    public static let maximumDimension = 16_384

    public let width: Int
    public let height: Int
    public let sourceRect: CGRect?
    public let edgeMode: MPSImageEdgeMode

    public var modifier: ModifierEnum {
        .mps(performance: lanczos)
    }

    public var factors: [Float] {
        [Float(width), Float(height), Float(edgeMode.rawValue)] + (sourceRect.map { [Float($0.minX), Float($0.minY), Float($0.width), Float($0.height)] } ?? [])
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

    public init(width: Int, height: Int, edgeMode: MPSImageEdgeMode = .clamp, sourceRect: CGRect? = nil) throws {
        guard (1...Self.maximumDimension).contains(width),
              (1...Self.maximumDimension).contains(height) else {
            throw HarbethError.filterParameterInvalid(
                "MPSLanczosResize width and height must be within 1...\(Self.maximumDimension)."
            )
        }
        if let sourceRect {
            guard [sourceRect.minX, sourceRect.minY, sourceRect.width, sourceRect.height].allSatisfy({ $0.isFinite }),
                  sourceRect.minX >= 0, sourceRect.minY >= 0, sourceRect.width >= 1, sourceRect.height >= 1 else {
                throw HarbethError.filterParameterInvalid("MPSLanczosResize sourceRect must be finite and positive.")
            }
        }
        self.sourceRect = sourceRect
        self.width = width
        self.height = height
        self.edgeMode = edgeMode
        self.lanczos = MPSImageLanczosScale(device: HarbethContext.shared.device)
        self.lanczos.edgeMode = edgeMode
        if let sourceRect {
            let scaleX = Double(width) / Double(sourceRect.width)
            let scaleY = Double(height) / Double(sourceRect.height)
            var transform = MPSScaleTransform(scaleX: scaleX, scaleY: scaleY,
                                              translateX: -Double(sourceRect.minX) * scaleX,
                                              translateY: -Double(sourceRect.minY) * scaleY)
            withUnsafePointer(to: &transform) { self.lanczos.scaleTransform = $0 }
        }
    }

    public func resize(input size: C7Size) -> C7Size {
        C7Size(width: width, height: height)
    }

    public func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        let (destination, source) = try mpsTexturePair(from: textures)
        guard destination.width == width, destination.height == height else {
            throw HarbethError.textureSizeMismatch
        }
        if let sourceRect {
            guard sourceRect.maxX <= CGFloat(source.width), sourceRect.maxY <= CGFloat(source.height) else {
                throw HarbethError.textureCropFailed
            }
        }
        lanczos.encode(commandBuffer: commandBuffer, sourceTexture: source, destinationTexture: destination)
        return destination
    }

    private let lanczos: MPSImageLanczosScale
}
