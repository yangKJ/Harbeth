//
//  TextureBackedCIImageFrame.swift
//  Harbeth
//
//  Created by Condy on 2026/8/4.
//

import CoreGraphics
import CoreImage
@preconcurrency import Metal
import ObjectiveC

nonisolated(unsafe) private var textureBackedCIImageResourceOwnerKey: UInt8 = 0

private final class TextureBackedCIImageResourceOwner: NSObject, @unchecked Sendable {
    let texture: MTLTexture
    let lease: TextureLease?

    init(frame: RenderedFrame) {
        texture = frame.texture
        lease = frame.lease
    }
}

/// 直接引用 Metal 纹理的 Core Image 单帧输出。
///
/// 该包装与公开的 `image` 都会强持有底层纹理资源。通过 `croppedImage(to:)`
/// 生成的裁剪配方也会继承该所有权，可交给 Core Image 延迟求值的宿主。
/// 调用方不需要也不能提前归还纹理。
public struct TextureBackedCIImageFrame: @unchecked Sendable {
    public let image: CIImage
    private let owner: RenderedFrame
    private let resourceOwner: TextureBackedCIImageResourceOwner

    init(image: CIImage, owner: RenderedFrame) {
        let resourceOwner = TextureBackedCIImageResourceOwner(frame: owner)
        self.image = Self.retainingResources(in: image, owner: resourceOwner)
        self.owner = owner
        self.resourceOwner = resourceOwner
    }

    /// 裁剪后仍由返回的 Core Image 配方持有底层纹理租约，可安全交给延迟求值的宿主。
    public func croppedImage(to extent: CGRect) -> CIImage {
        Self.retainingResources(in: image.cropped(to: extent), owner: resourceOwner)
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

    private static func retainingResources(in image: CIImage, owner: TextureBackedCIImageResourceOwner) -> CIImage {
        objc_setAssociatedObject(
            image,
            &textureBackedCIImageResourceOwnerKey,
            owner,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return image
    }
}
