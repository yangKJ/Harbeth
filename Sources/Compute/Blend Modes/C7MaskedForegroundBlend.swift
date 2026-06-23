//
//  C7MaskedForegroundBlend.swift
//  Harbeth
//
//  Created by Condy on 2026/6/23.
//

import Foundation

/// 旧目录体系里的三纹理前景蒙版合成滤镜。
///
/// 这条能力属于通用 blend catalog：
/// - 输入是 background + foreground + mask 三张 texture
/// - 输出是“前景在 mask 覆盖区域内混到背景上”
/// - 不承载 `MaskDescriptor` / `LocalEffectRecipe` / `LayerCompositeRecipe` 这类新 editing 语义
///
/// 如果调用方在做局部调整、mask coverage 组合、layer mask 或 `ImageNode.editing(...)`，
/// 优先使用 `Sources/Basic/Filters/MaskFilters.swift` 里的 primitive。
public struct C7MaskedForegroundBlend: C7FilterProtocol {

    @ZeroOneRange public var intensity: Float = R.intensityRange.value

    public var modifier: ModifierEnum {
        .compute(kernel: "C7MaskedForegroundBlend")
    }

    public var factors: [Float] {
        [intensity]
    }

    public var otherInputTextures: C7InputTextures {
        [foregroundTexture, maskTexture]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .multiTexture
    }

    private let foregroundTexture: MTLTexture
    private let maskTexture: MTLTexture

    public init(foregroundTexture: MTLTexture, maskTexture: MTLTexture, intensity: Float = 1.0) {
        self.foregroundTexture = foregroundTexture
        self.maskTexture = maskTexture
        self.intensity = intensity
    }

    public func updateIntensity(_ intensity: CGFloat) -> Self {
        var copy = self
        copy.intensity = Float(intensity)
        return copy
    }
}
