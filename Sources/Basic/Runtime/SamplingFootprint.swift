//
//  SamplingFootprint.swift
//  Harbeth
//

import Foundation

/// 描述滤镜为了生成一个输出像素需要读取的输入范围。
///
/// 该合同只描述执行安全边界，不携带任何产品语义。
public enum SamplingFootprint: Sendable, Equatable, Hashable {
    /// 输出像素只读取同坐标输入。
    case point
    /// 输出像素读取固定半径的邻域。
    case neighborhood(radius: Int)
    /// 读取范围只能在运行时解析，执行器不得猜测 halo。
    case dynamic
    /// 依赖全局坐标或整张图，不能自动按普通 tile 拆分。
    case global

    public var haloRadius: Int? {
        guard case .neighborhood(let radius) = self, radius >= 0 else { return nil }
        return radius
    }

    public var isValid: Bool {
        switch self {
        case .point, .dynamic, .global:
            return true
        case .neighborhood(let radius):
            return radius >= 0
        }
    }

    public var canAutoTile: Bool {
        switch self {
        case .point, .neighborhood:
            return isValid
        case .dynamic, .global:
            return false
        }
    }
}

public extension C7FilterProtocol {
    /// 旧滤镜可以继续只声明 `memoryAccessPattern`。
    ///
    /// `.neighborhood` 默认解析为 `.dynamic`，避免在不知道真实采样半径时
    /// 错误地把滤镜标记为可安全分块。
    var samplingFootprint: SamplingFootprint {
        switch memoryAccessPattern {
        case .point:
            return .point
        case .neighborhood:
            return .dynamic
        case .dualTexture, .multiTexture, .auto:
            return .dynamic
        }
    }
}
