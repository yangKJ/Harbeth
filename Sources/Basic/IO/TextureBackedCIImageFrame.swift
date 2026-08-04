//
//  TextureBackedCIImageFrame.swift
//  Harbeth
//
//  Created by Condy on 2026/8/4.
//

import CoreGraphics
import CoreImage
@preconcurrency import Metal

/// 直接引用 Metal 纹理的 Core Image 单帧输出。
///
/// 该包装会强持有底层 `RenderedFrame`，从而把纹理租约的生命周期绑定到
/// 最后一个包装副本。调用方不需要也不能提前归还纹理。
public struct TextureBackedCIImageFrame: @unchecked Sendable {
    public let image: CIImage
    private let owner: RenderedFrame

    init(image: CIImage, owner: RenderedFrame) {
        self.image = image
        self.owner = owner
    }

    public var texture: MTLTexture { owner.texture }
    public var size: CGSize { owner.size }
    public var pixelFormat: MTLPixelFormat { owner.pixelFormat }
    public var colorSpace: CGColorSpace? { owner.colorSpace }
    public var outputColorSpaceContract: ImageColorSpaceContract { owner.outputColorSpaceContract }
    public var outputDynamicRange: ImageDynamicRangeContract { owner.outputDynamicRange }
    public var outputToneMappingPolicy: ImageToneMappingPolicy { owner.outputToneMappingPolicy }
    public var sourceDescriptor: ImageSourceDescriptor { owner.sourceDescriptor }
    public var alphaType: AlphaType { owner.alphaType }
    public var orientation: FrameOrientation { owner.orientation }
    public var profile: RenderProfile { owner.profile }
}
