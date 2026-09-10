//
//  ViewSnapshotSource.swift
//  Harbeth
//
//  Created by Condy on 2026/9/7.
//

import Foundation
@preconcurrency import Metal
import CoreGraphics
import QuartzCore

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// 主线程 UI 快照的捕获策略。
///
/// `.hierarchy` 生成当前屏幕可见的 UIKit 层级快照；`.layer` 直接栅格化图层树。
/// 图层树捕获不驱动 Core Animation 动画，离线媒体场景应由宿主先更新到目标时间的 UI 状态。
public enum ViewSnapshotCaptureMode: Sendable, Equatable {
    case hierarchy(afterScreenUpdates: Bool)
    case layer
}

/// 已冻结的 UI 像素内容。
///
/// 每个实例对应一个不可变 revision。首次请求纹理时上传一次，随后 `imageSource()`、
/// `makeRenderLayerComposite(...)` 与 `makeImageLayer(...)` 都复用同一纹理。
public final class ViewSnapshot: @unchecked Sendable {
    public static let one = CGRect(x: 0, y: 0, width: 1, height: 1)
    public let identifier: String
    public let revision: UInt64
    public let captureMode: ViewSnapshotCaptureMode
    public let image: C7Image
    public let pixelSize: C7Size

    private let textureLock = NSLock()
    private var textureStorage: MTLTexture?

    init(identifier: String, revision: UInt64, captureMode: ViewSnapshotCaptureMode, image: C7Image, pixelSize: C7Size) {
        self.identifier = identifier
        self.revision = revision
        self.captureMode = captureMode
        self.image = image
        self.pixelSize = pixelSize
    }

    /// 上传并缓存快照纹理。调用方应把这个快照或由它生成的 `ImageSource` 保留到渲染提交完成。
    public func texture() throws -> MTLTexture {
        textureLock.lock()
        defer { textureLock.unlock() }
        if let textureStorage { return textureStorage }
        let texture = try TextureLoader(with: image).texture
        texture.label = "Harbeth.ViewSnapshot.\(identifier).\(revision)"
        textureStorage = texture
        return texture
    }

    /// 返回复用已上传纹理的统一输入源。
    public func imageSource() throws -> ImageSource {
        .texture(try texture())
    }

    /// 创建适用于单层预乘 alpha source-over 合成的轻量 render primitive。
    public func makeRenderLayerComposite(normalizedFrame: CGRect = ViewSnapshot.one, opacity: Float = 1) throws -> RenderLayerComposite {
        try RenderLayerComposite(layerTexture: texture(), normalizedFrame: normalizedFrame, opacity: opacity)
    }

    /// 创建可放入 `LayerCompositeRecipe` 的图层输入。
    public func makeImageLayer(normalizedFrame: CGRect = ViewSnapshot.one, opacity: Float = 1, blendMode: LayerBlendMode = .sourceOver) throws -> ImageLayer {
        ImageLayer(content: try imageSource(), normalizedFrame: normalizedFrame, opacity: opacity, blendMode: blendMode)
    }
}

/// 把 `C7View` 或 `CALayer` 显式物化为可复用的 Metal 输入。
///
/// 该对象只负责一次 UI 捕获和纹理准备。刷新时调用 `capture()` 获得新 revision；
/// 媒体时间、刷新频率和旧结果的展示权仍由宿主控制。
@MainActor
public final class ViewSnapshotSource {
    private enum Subject {
        case view(C7View)
        case layer(CALayer)
    }

    public let identifier: String
    public var captureMode: ViewSnapshotCaptureMode
    public private(set) var latestSnapshot: ViewSnapshot?

    private let subject: Subject
    private var nextRevision: UInt64 = 0

    public init(view: C7View, captureMode: ViewSnapshotCaptureMode = .layer, identifier: String = UUID().uuidString) {
        self.subject = .view(view)
        self.captureMode = captureMode
        self.identifier = identifier
    }

    public init(layer: CALayer, captureMode: ViewSnapshotCaptureMode = .layer, identifier: String = UUID().uuidString) {
        self.subject = .layer(layer)
        self.captureMode = captureMode
        self.identifier = identifier
    }

    /// 在主线程冻结当前 UI 内容，并发布一个新的不可变 revision。
    @discardableResult
    public func capture() throws -> ViewSnapshot {
        let image = try makeImage()
        guard let cgImage = image.c7.toCGImage() else {
            throw HarbethError.image2CGImage
        }
        nextRevision &+= 1
        let snapshot = ViewSnapshot(
            identifier: identifier,
            revision: nextRevision,
            captureMode: captureMode,
            image: image,
            pixelSize: C7Size(cgImage: cgImage)
        )
        latestSnapshot = snapshot
        return snapshot
    }

    private func makeImage() throws -> C7Image {
        switch subject {
        case .view(let view):
            return try capture(view: view)
        case .layer(let layer):
            guard captureMode == .layer else {
                throw HarbethError.viewSnapshotCaptureFailed("CALayer supports only layer capture mode")
            }
            return try capture(layer: layer)
        }
    }
}

#if os(iOS) || os(tvOS)
private extension ViewSnapshotSource {
    func capture(view: UIView) throws -> UIImage {
        switch captureMode {
        case .hierarchy(let afterScreenUpdates):
            guard view.bounds.width > 0, view.bounds.height > 0 else {
                throw HarbethError.viewSnapshotCaptureFailed("View bounds must be non-empty")
            }
            let format = UIGraphicsImageRendererFormat.preferred()
            format.scale = max(view.traitCollection.displayScale, 1)
            format.opaque = false
            var completed = true
            let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { _ in
                if let scrollView = view as? UIScrollView {
                    let rect = scrollView.bounds.offsetBy(dx: -scrollView.contentOffset.x, dy: -scrollView.contentOffset.y)
                    completed = scrollView.drawHierarchy(in: rect, afterScreenUpdates: afterScreenUpdates)
                } else {
                    completed = view.drawHierarchy(in: view.bounds, afterScreenUpdates: afterScreenUpdates)
                }
            }
            guard completed else {
                throw HarbethError.viewSnapshotCaptureFailed("View hierarchy capture was incomplete")
            }
            return image
        case .layer:
            return try capture(layer: view.layer)
        }
    }

    func capture(layer: CALayer) throws -> UIImage {
        guard layer.bounds.width > 0, layer.bounds.height > 0 else {
            throw HarbethError.viewSnapshotCaptureFailed("Layer bounds must be non-empty")
        }
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = max(layer.contentsScale, 1)
        format.opaque = false
        return UIGraphicsImageRenderer(size: layer.bounds.size, format: format).image { context in
            context.cgContext.translateBy(x: -layer.bounds.origin.x, y: -layer.bounds.origin.y)
            layer.render(in: context.cgContext)
        }
    }
}
#elseif os(macOS)
private extension ViewSnapshotSource {
    func capture(view: NSView) throws -> NSImage {
        guard captureMode == .layer else {
            throw HarbethError.viewSnapshotCaptureFailed("NSView supports only layer capture mode")
        }
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0,
              let representation = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            throw HarbethError.viewSnapshotCaptureFailed("View bounds must be non-empty")
        }
        view.cacheDisplay(in: bounds, to: representation)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(representation)
        return image
    }

    func capture(layer: CALayer) throws -> NSImage {
        let bounds = layer.bounds
        let scale = max(layer.contentsScale, 1)
        let width = Int((bounds.width * scale).rounded(.up))
        let height = Int((bounds.height * scale).rounded(.up))
        guard width > 0, height > 0 else {
            throw HarbethError.viewSnapshotCaptureFailed("Layer bounds must be non-empty")
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw HarbethError.contextCreationFailed
        }
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.origin.x, y: -bounds.origin.y)
        layer.render(in: context)
        guard let cgImage = context.makeImage() else {
            throw HarbethError.image2CGImage
        }
        return NSImage(cgImage: cgImage, size: bounds.size)
    }
}
#endif
