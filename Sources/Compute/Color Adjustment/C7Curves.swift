//
//  C7Curves.swift
//  Harbeth
//
//  Created by Condy on 2026/3/10.
//

import Foundation

/// 曲线调整滤镜
/// Curves adjustment filter
///
/// 该滤镜通过控制点定义的曲线来调整图像的色彩和对比度，
/// 支持RGB主曲线和红、绿、蓝单独通道曲线的调整。
///
/// 曲线控制点说明：
/// - 每个控制点是一个C7Point2D对象，使用归一化坐标(0.0-1.0)
/// - x坐标代表输入亮度值（从黑到白）
/// - y坐标代表输出亮度值（从黑到白）
/// - 默认的对角线([(0,0), (1,1)])代表无调整
public struct C7Curves: C7FilterProtocol {

    public enum Interpolation: String, Codable, Equatable, Sendable {
        case legacy
        case linear
        /// 保持相邻点范围的Hermite插值；在预乘纹理上还原直色值后求值。
        case shapePreserving
    }

    public enum Extrapolation: Float, Codable, Equatable, Sendable {
        case clampToEndpoints = 0
        case linear = 1
    }

    public enum CompositionOrder: Float, Codable, Equatable, Sendable {
        case rgbThenChannels = 0
        case channelsThenRGB = 1
    }

    /// RGB曲线控制点，使用C7Point2D（归一化坐标）
    /// RGB curve control points, using C7Point2D (normalized coordinates)
    public var rgbPoints: [C7Point2D] = []

    /// 红色通道曲线控制点
    /// Red channel curve control points
    public var redPoints: [C7Point2D] = []

    /// 绿色通道曲线控制点
    /// Green channel curve control points
    public var greenPoints: [C7Point2D] = []

    /// 蓝色通道曲线控制点
    /// Blue channel curve control points
    public var bluePoints: [C7Point2D] = []

    /// 公共默认保留旧插值，避免未版本化的持久化配方静默改变；新编辑应显式选择插值与通道顺序。
    public var interpolation: Interpolation
    public var extrapolation: Extrapolation
    public var compositionOrder: CompositionOrder

    public var modifier: ModifierEnum {
        switch interpolation {
        case .legacy:
            return .compute(kernel: compositionOrder == .rgbThenChannels ? "C7CurvesLegacy" : "C7CurvesLegacyOrdered")
        case .linear:
            return .compute(kernel: "C7Curves")
        case .shapePreserving:
            return .compute(kernel: "C7CurvesCubic")
        }
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public var kernelParameterBindings: [KernelParameterBinding] {
        var bindings = [
            KernelParameterBinding(name: "pointCounts", index: 0, stage: .compute, value: .float4(pointCounts)),
            KernelParameterBinding(name: "rgbPoints", index: 1, stage: .compute, value: .floatArray(flattenedPoints(rgbPoints))),
            KernelParameterBinding(name: "redPoints", index: 2, stage: .compute, value: .floatArray(flattenedPoints(redPoints))),
            KernelParameterBinding(name: "greenPoints", index: 3, stage: .compute, value: .floatArray(flattenedPoints(greenPoints))),
            KernelParameterBinding(name: "bluePoints", index: 4, stage: .compute, value: .floatArray(flattenedPoints(bluePoints)))
        ]
        if interpolation != .legacy {
            bindings.append(KernelParameterBinding(name: "extrapolation", index: 5, stage: .compute,
                                                   value: .float(extrapolation.rawValue)))
        }
        if interpolation != .legacy || compositionOrder != .rgbThenChannels {
            bindings.append(KernelParameterBinding(name: "compositionOrder", index: interpolation == .legacy ? 5 : 6,
                                                   stage: .compute, value: .float(compositionOrder.rawValue)))
        }
        return bindings
    }

    public var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(
            precision: .float16,
            dynamicRangeBehavior: interpolation != .legacy && extrapolation == .linear
                ? .preservesExtendedRange : .unspecified,
            samplingFootprint: .point,
            fusionPolicy: .pointwise
        )
    }

    private var pointCounts: SIMD4<Float> {
        SIMD4<Float>(Float(rgbPoints.count), Float(redPoints.count), Float(greenPoints.count), Float(bluePoints.count))
    }

    private func flattenedPoints(_ points: [C7Point2D]) -> [Float] {
        points.flatMap { [$0.x, $0.y] }
    }

    public init(
        rgbPoints: [C7Point2D]? = nil,
        redPoints: [C7Point2D]? = nil,
        greenPoints: [C7Point2D]? = nil,
        bluePoints: [C7Point2D]? = nil,
        interpolation: Interpolation = .legacy,
        extrapolation: Extrapolation = .clampToEndpoints,
        compositionOrder: CompositionOrder = .rgbThenChannels
    ) {
        self.interpolation = interpolation
        self.extrapolation = extrapolation
        self.compositionOrder = compositionOrder
        if let points = rgbPoints {
            self.rgbPoints = points
        } else {
            self.rgbPoints = [
                C7Point2D(x: 0.0, y: 0.0),
                C7Point2D(x: 1.0, y: 1.0)
            ]
        }
        if let points = redPoints {
            self.redPoints = points
        } else {
            self.redPoints = [
                C7Point2D(x: 0.0, y: 0.0),
                C7Point2D(x: 1.0, y: 1.0)
            ]
        }
        if let points = greenPoints {
            self.greenPoints = points
        } else {
            self.greenPoints = [
                C7Point2D(x: 0.0, y: 0.0),
                C7Point2D(x: 1.0, y: 1.0)
            ]
        }
        if let points = bluePoints {
            self.bluePoints = points
        } else {
            self.bluePoints = [
                C7Point2D(x: 0.0, y: 0.0),
                C7Point2D(x: 1.0, y: 1.0)
            ]
        }
    }

    /// 与平滑GPU算子相同的保持形状Hermite求值，供控制图与数值验证复用。
    /// 平滑模式在每个区间内不越过相邻控制点，域外可选择端点保持或线性外推。
    public static func shapePreservingValue(_ value: Float, points: [C7Point2D],
                                         extrapolation: Extrapolation = .clampToEndpoints) -> Float {
        guard value.isFinite, points.count >= 2,
              points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
              zip(points, points.dropFirst()).allSatisfy({ $0.x < $1.x }) else { return value }
        let index = min(points.count - 2, max(0, points.lastIndex(where: { $0.x <= value }) ?? 0))
        let a = points[index]
        let b = points[index + 1]
        let h = b.x - a.x
        let delta = (b.y - a.y) / h
        if value < points[0].x {
            return extrapolation == .linear ? a.y + (value - a.x) * delta : a.y
        }
        if value > points[points.count - 1].x {
            return extrapolation == .linear ? b.y + (value - b.x) * delta : b.y
        }
        let t = min(1, max(0, (value - a.x) / h))
        func slope(_ i: Int) -> Float {
            let left = max(0, i - 1)
            let right = min(points.count - 2, i)
            let before = (points[left + 1].y - points[left].y) / (points[left + 1].x - points[left].x)
            let after = (points[right + 1].y - points[right].y) / (points[right + 1].x - points[right].x)
            guard before * after > 0 else { return 0 }
            return 2 / (1 / before + 1 / after)
        }
        let t2 = t * t
        let t3 = t2 * t
        let result = (2 * t3 - 3 * t2 + 1) * a.y + (t3 - 2 * t2 + t) * h * slope(index)
            + (-2 * t3 + 3 * t2) * b.y + (t3 - t2) * h * slope(index + 1)
        return min(max(a.y, b.y), max(min(a.y, b.y), result))
    }

    public func updateExtrapolation(_ extrapolation: Extrapolation) -> Self {
        var copy = self
        copy.extrapolation = extrapolation
        return copy
    }
}
