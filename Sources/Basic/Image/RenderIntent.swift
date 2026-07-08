//
//  RenderIntent.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//
import Foundation

/// 渲染请求的稳定语义意图。
public enum RenderIntent: String, Sendable, Codable, Hashable {
    /// 高频交互中的低延迟反馈。
    case interactive
    /// 离散参数变更后的快速反馈。
    case responsive
    /// 默认稳定显示路径。
    case stable
    /// 高保真检查路径。
    case inspection
    /// 面向外部展示或交付的派生资源。
    case delivery
    /// 最终导出重放。
    case export
    /// CPU 读回路径。
    case readback
}

/// Source 在资源金字塔中的层级。
public enum ImageSourceTier: String, Sendable, Codable, Hashable {
    /// 原始输入或全尺寸真相源。
    case original
    /// 经过完整处理但仍保留高保真重放价值的资源。
    case fullResolutionReusable
    /// 用于稳定显示和可重复调度的中等分辨率资源。
    case stableReusable
    /// 用于轻量索引或小尺寸显示的缩略图。
    case thumbnail
    /// 面向展示交付但不要求原始分辨率的可复用资源。
    case deliveryReusable

    var rank: Int {
        switch self {
        case .thumbnail:
            return 0
        case .deliveryReusable:
            return 1
        case .stableReusable:
            return 2
        case .fullResolutionReusable:
            return 3
        case .original:
            return 4
        }
    }

    func satisfies(_ requiredTier: ImageSourceTier) -> Bool {
        rank >= requiredTier.rank
    }
}

public extension RenderProfile {
    var defaultRenderIntent: RenderIntent {
        switch self {
        case .interactiveLatency:
            return .interactive
        case .responseLatency:
            return .responsive
        case .stablePreview:
            return .stable
        case .inspectionQuality:
            return .inspection
        case .exportQuality:
            return .export
        case .readbackQuality:
            return .readback
        }
    }
}
