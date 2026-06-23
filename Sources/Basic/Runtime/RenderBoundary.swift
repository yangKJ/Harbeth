//
//  RenderBoundary.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//
import Foundation
@preconcurrency import Metal

/// 外部框架进入 Harbeth 的边界类型。
enum RenderBoundaryKind: String, Sendable, Equatable {
    case nativeMetal
    case compatibility
    case cpu
    case ai
    case openCV
    case vision
}

/// 外部边界的成本描述，供 RenderGraph 调度和缓存决策使用。
struct RenderBoundaryCost: Sendable, Equatable {
    var usesCPU: Bool
    var breaksFusion: Bool
    var requiresReadback: Bool
    var cacheable: Bool
    var supportsLowLatencyFrameFlow: Bool

    static let nativeMetal = RenderBoundaryCost(
        usesCPU: false,
        breaksFusion: false,
        requiresReadback: false,
        cacheable: true,
        supportsLowLatencyFrameFlow: true
    )

    static let compatibilityBoundary = RenderBoundaryCost(
        usesCPU: true,
        breaksFusion: true,
        requiresReadback: false,
        cacheable: true,
        supportsLowLatencyFrameFlow: false
    )
}

/// Core 只依赖该协议，不直接 import 外部图像或视觉框架。
protocol RenderBoundaryAdapter {
    var kind: RenderBoundaryKind { get }
    var cost: RenderBoundaryCost { get }
    func render(input: RenderedFrame, context: RenderContext) throws -> RenderedFrame
}

protocol ExternalSourceAdapter {
    associatedtype Source
    func makeFrame(from source: Source, context: RenderContext) throws -> RenderedFrame
}

protocol ExternalFilterAdapter {
    associatedtype Recipe
    func makeBoundary(from recipe: Recipe) throws -> RenderBoundaryAdapter
}

struct RenderContext {
    var profile: RenderProfile
    var identifier: String
    var metadata: [String: String]

    init(profile: RenderProfile = .stablePreview, identifier: String = UUID().uuidString, metadata: [String: String] = [:]) {
        self.profile = profile
        self.identifier = identifier
        self.metadata = metadata
    }
}

/// 纹理租约：后续用于把资源归还和 command buffer 生命周期绑定。
public final class TextureLease {
    public let texture: MTLTexture
    public let logicalExtent: C7Size
    private let releaseHandler: (() -> Void)?
    private var released = false
    private let lock = NSLock()

    public init(texture: MTLTexture, logicalExtent: C7Size? = nil, releaseHandler: (() -> Void)? = nil) {
        self.texture = texture
        self.logicalExtent = logicalExtent ?? C7Size(width: texture.width, height: texture.height)
        self.releaseHandler = releaseHandler
    }

    deinit { release() }

    public func release() {
        lock.lock()
        defer { lock.unlock() }
        guard released == false else { return }
        released = true
        releaseHandler?()
    }
}
