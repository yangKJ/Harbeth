//
//  C7TextureOverlay.swift
//  Harbeth
//
//  Created by Condy on 2026/11/13.
//

import Foundation
import Metal

/// 在纹理归一化矩形内合成预乘alpha叠加；源与叠加必须已经处于相同色彩域。
public struct C7TextureOverlay: C7FilterProtocol {
    public let texture: MTLTexture
    public let rect: CGRect
    public init(texture: MTLTexture, rect: CGRect) throws {
        guard [rect.minX, rect.minY, rect.width, rect.height].allSatisfy(\.isFinite),
              rect.width > 0, rect.height > 0 else {
            throw HarbethError.configurationInvalid("无效的纹理叠加区域。")
        }
        self.texture = texture
        self.rect = rect
    }
    public var kernelPixelContract: KernelPixelContract {
        .init(inputAlphaExpectation: .premultiplied, precision: .float32, dynamicRangeBehavior: .preservesExtendedRange,
              samplingFootprint: .dynamic, coordinateDependency: .fullImage, globalDependency: .imageDimensions)
    }
    public var kernelOutputContract: RenderOutputContract { .premultipliedColorInput }
    public var modifier: ModifierEnum { .compute(kernel: "HarbethTextureOverlay") }
    public var memoryAccessPattern: MemoryAccessPattern { .dualTexture }
    public var otherInputTextures: C7InputTextures { [texture] }
    public var kernelParameterBindings: [KernelParameterBinding] {
        [.init(name: "rect", index: 0, stage: .compute, value: .float4(rect.c7.toSIMD4()))]
    }
}
