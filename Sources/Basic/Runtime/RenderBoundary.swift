//
//  RenderBoundary.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//
import Foundation
@preconcurrency import Metal

/// 外部框架进入 Harbeth 的边界类型。
public enum RenderBoundaryKind: String, Sendable, Equatable {
    case nativeMetal
    case compatibility
    case cpu
    case ai
    case openCV
    case vision
}

/// 外部边界的成本描述，供 RenderGraph 调度和缓存决策使用。
public struct RenderBoundaryCost: Sendable, Equatable {
    public var usesCPU: Bool
    public var breaksFusion: Bool
    public var requiresReadback: Bool
    public var cacheable: Bool
    public var supportsLowLatencyFrameFlow: Bool

    public init(usesCPU: Bool,
                breaksFusion: Bool,
                requiresReadback: Bool,
                cacheable: Bool,
                supportsLowLatencyFrameFlow: Bool) {
        self.usesCPU = usesCPU
        self.breaksFusion = breaksFusion
        self.requiresReadback = requiresReadback
        self.cacheable = cacheable
        self.supportsLowLatencyFrameFlow = supportsLowLatencyFrameFlow
    }

    public static let nativeMetal = RenderBoundaryCost(
        usesCPU: false,
        breaksFusion: false,
        requiresReadback: false,
        cacheable: true,
        supportsLowLatencyFrameFlow: true
    )

    public static let compatibilityBoundary = RenderBoundaryCost(
        usesCPU: true,
        breaksFusion: true,
        requiresReadback: false,
        cacheable: true,
        supportsLowLatencyFrameFlow: false
    )
}

/// Core 只依赖该协议，不直接 import 外部图像或视觉框架。
public protocol RenderBoundaryAdapter {
    var kind: RenderBoundaryKind { get }
    var cost: RenderBoundaryCost { get }
    func render(input: RenderedFrame, context: RenderContext) throws -> RenderedFrame
}

public protocol ExternalSourceAdapter {
    associatedtype Source
    func makeFrame(from source: Source, context: RenderContext) throws -> RenderedFrame
}

public protocol ExternalFilterAdapter {
    associatedtype Recipe
    func makeBoundary(from recipe: Recipe) throws -> RenderBoundaryAdapter
}

public struct RenderContext {
    public var profile: RenderProfile
    public var identifier: String
    public var metadata: [String: String]

    public init(profile: RenderProfile = .stablePreview, identifier: String = UUID().uuidString, metadata: [String: String] = [:]) {
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
