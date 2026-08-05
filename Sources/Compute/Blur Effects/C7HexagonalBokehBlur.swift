//
//  C7HexagonalBokehBlur.swift
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

import Foundation
import Metal

/// 六边形孔径散景模糊。
///
/// 滤镜使用两个 GPU 阶段覆盖 0°、60° 和 120° 三个采样方向，形成六边形孔径特征。
/// `cocTexture` 可选；其红色通道的绝对值表示每个像素的模糊系数，0 保持原图，1 使用完整半径。
/// CoC 纹理使用归一化画布坐标对齐，可以使用与输入不同的分辨率。
///
/// 该 primitive 保留输入的 premultiplied alpha。颜色在 straight-alpha 空间完成采样后重新
/// premultiply；不会截断负值或大于 1 的 HDR/EDR 颜色值。
public final class C7HexagonalBokehBlur: C7FilterPipelineProtocol {

    public static let radiusRange: ParameterRange<Float, C7HexagonalBokehBlur> = .init(min: 0, max: 100, value: 12)
    public static let brightnessRange: ParameterRange<Float, C7HexagonalBokehBlur> = .init(min: 0, max: 2, value: 0)

    /// 六边形孔径半径，单位为像素。0 保持原图。
    @Clamping(radiusRange.min...radiusRange.max) public var radius: Float = radiusRange.value

    /// 高亮散景增强量。0 不改变模糊亮度。
    @Clamping(brightnessRange.min...brightnessRange.max) public var brightness: Float = brightnessRange.value

    /// 孔径旋转角度，单位为度。
    public var angle: Float = 0

    /// 可选的逐像素 CoC 纹理。红色通道绝对值控制局部模糊半径与合成量。
    public let cocTexture: MTLTexture?

    public var pipelineFilters: [C7FilterProtocol] {
        if let cocTexture {
            return [
                HexagonalBokehFirstPass(radius: radius, angle: angle, cocTexture: cocTexture),
                HexagonalBokehSecondPass(radius: radius, angle: angle, cocTexture: cocTexture)
            ]
        }
        return [
            HexagonalBokehFirstPass(radius: radius, angle: angle),
            HexagonalBokehSecondPass(radius: radius, angle: angle)
        ]
    }

    public var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(
            inputColorSpace: .preserveInput,
            workingColorSpace: .preserveInput,
            outputColorSpace: .preserveInput,
            inputAlphaExpectation: .premultiplied,
            outputAlpha: .premultiplied,
            precision: .float16,
            dynamicRangeBehavior: .preservesExtendedRange,
            samplingFootprint: .neighborhood(radius: Int(ceil(radius)) * 2),
            coordinateDependency: .local,
            globalDependency: .none,
            fusionPolicy: .disabled
        )
    }

    public init(
        radius: Float = radiusRange.value,
        brightness: Float = brightnessRange.value,
        angle: Float = 0,
        cocTexture: MTLTexture? = nil
    ) {
        self.radius = radius
        self.brightness = brightness
        self.angle = angle.isFinite ? angle : 0
        self.cocTexture = cocTexture
    }

    public func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? {
        guard let blurredTexture = otherInputTextures?.first else {
            return PipelineLeafFilter(
                modifier: .compute(
                    kernel: cocTexture == nil
                        ? "C7HexagonalBokehComposite"
                        : "C7HexagonalBokehCompositeWithCoC"
                ),
                factors: [radius, brightness]
            )
        }
        if let cocTexture {
            return HexagonalBokehComposite(
                radius: radius,
                brightness: brightness,
                blurredTexture: blurredTexture,
                cocTexture: cocTexture
            )
        }
        return HexagonalBokehComposite(radius: radius, brightness: brightness, blurredTexture: blurredTexture)
    }
}

private struct HexagonalBokehFirstPass: C7FilterProtocol {
    let radius: Float
    let angle: Float
    let cocTexture: MTLTexture?

    init(radius: Float, angle: Float, cocTexture: MTLTexture? = nil) {
        self.radius = radius
        self.angle = angle
        self.cocTexture = cocTexture
    }

    var modifier: ModifierEnum {
        .compute(kernel: cocTexture == nil ? "C7HexagonalBokehFirstPass" : "C7HexagonalBokehFirstPassWithCoC")
    }

    var factors: [Float] { [radius, angle] }
    var otherInputTextures: C7InputTextures { cocTexture.map { [$0] } ?? [] }
    var memoryAccessPattern: MemoryAccessPattern { cocTexture == nil ? .neighborhood : .multiTexture }
}

private struct HexagonalBokehSecondPass: C7FilterProtocol {
    let radius: Float
    let angle: Float
    let cocTexture: MTLTexture?

    init(radius: Float, angle: Float, cocTexture: MTLTexture? = nil) {
        self.radius = radius
        self.angle = angle
        self.cocTexture = cocTexture
    }

    var modifier: ModifierEnum {
        .compute(kernel: cocTexture == nil ? "C7HexagonalBokehSecondPass" : "C7HexagonalBokehSecondPassWithCoC")
    }

    var factors: [Float] { [radius, angle] }
    var otherInputTextures: C7InputTextures { cocTexture.map { [$0] } ?? [] }
    var memoryAccessPattern: MemoryAccessPattern { cocTexture == nil ? .neighborhood : .multiTexture }
}

private struct HexagonalBokehComposite: C7FilterProtocol {
    let radius: Float
    let brightness: Float
    let blurredTexture: MTLTexture
    let cocTexture: MTLTexture?

    init(radius: Float, brightness: Float, blurredTexture: MTLTexture, cocTexture: MTLTexture? = nil) {
        self.radius = radius
        self.brightness = brightness
        self.blurredTexture = blurredTexture
        self.cocTexture = cocTexture
    }

    var modifier: ModifierEnum {
        .compute(kernel: cocTexture == nil ? "C7HexagonalBokehComposite" : "C7HexagonalBokehCompositeWithCoC")
    }

    var factors: [Float] { [radius, brightness] }
    var otherInputTextures: C7InputTextures {
        cocTexture.map { [blurredTexture, $0] } ?? [blurredTexture]
    }
    var memoryAccessPattern: MemoryAccessPattern { cocTexture == nil ? .dualTexture : .multiTexture }
}
