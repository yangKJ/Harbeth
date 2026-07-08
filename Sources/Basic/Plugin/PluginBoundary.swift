//
//  PluginBoundary.swift
//  Harbeth
//
//  Created by Condy on 2026/7/2.
//

import Foundation

/// 插件进入 Harbeth 的能力边界类型。
public enum PluginBoundaryKind: String, Sendable, Codable, Equatable, Hashable {
    case nativeMetal
    case compatibility
    case cpu
    case ai
    case vision
}

/// 插件执行成本描述，供 Runtime 内部调度、诊断和缓存决策使用。
public struct PluginCapability: Sendable, Codable, Equatable, Hashable {
    public let kind: PluginBoundaryKind
    public let usesCPU: Bool
    public let breaksFusion: Bool
    public let requiresReadback: Bool
    public let cacheable: Bool
    public let supportsLowLatencyFrameFlow: Bool

    public init(kind: PluginBoundaryKind,
                usesCPU: Bool,
                breaksFusion: Bool,
                requiresReadback: Bool,
                cacheable: Bool,
                supportsLowLatencyFrameFlow: Bool) {
        self.kind = kind
        self.usesCPU = usesCPU
        self.breaksFusion = breaksFusion
        self.requiresReadback = requiresReadback
        self.cacheable = cacheable
        self.supportsLowLatencyFrameFlow = supportsLowLatencyFrameFlow
    }

    public static let nativeMetal = PluginCapability(
        kind: .nativeMetal,
        usesCPU: false,
        breaksFusion: false,
        requiresReadback: false,
        cacheable: true,
        supportsLowLatencyFrameFlow: true
    )

    public static let compatibility = PluginCapability(
        kind: .compatibility,
        usesCPU: true,
        breaksFusion: true,
        requiresReadback: false,
        cacheable: true,
        supportsLowLatencyFrameFlow: false
    )

    public static let cpu = PluginCapability(
        kind: .cpu,
        usesCPU: true,
        breaksFusion: true,
        requiresReadback: true,
        cacheable: true,
        supportsLowLatencyFrameFlow: false
    )

    public static let ai = PluginCapability(
        kind: .ai,
        usesCPU: true,
        breaksFusion: true,
        requiresReadback: true,
        cacheable: false,
        supportsLowLatencyFrameFlow: false
    )

    public static let vision = PluginCapability(
        kind: .vision,
        usesCPU: true,
        breaksFusion: true,
        requiresReadback: true,
        cacheable: true,
        supportsLowLatencyFrameFlow: false
    )
}

/// 插件执行时由 Harbeth 传入的轻量上下文。
public struct PluginContext: Sendable, Equatable {
    public let profile: RenderProfile
    public let identifier: String
    public let metadata: [String: String]

    public init(profile: RenderProfile = .stablePreview, identifier: String = UUID().uuidString, metadata: [String: String] = [:]) {
        self.profile = profile
        self.identifier = identifier
        self.metadata = metadata
    }
}
