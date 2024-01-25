//
//  CISketch.swift
//  Harbeth
//
//  Created by Condy on 2023/8/25.
//

import Foundation
import CoreImage

/// 素描滤镜，包含去色、反色、高斯模糊和混合叠加几种滤镜
public struct CISketch: C7FilterProtocol, CoreImageProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0, max: 100, value: 10.0)
    
    @Clamping(range.min...range.max) public var radius: Float = range.value
    
    public var modifier: Modifier {
        return .coreimage(CIName: "CIColorDodgeBlendMode")
    }
    
    public func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage {
        let monoFilter = CIFilter(name: "CIPhotoEffectMono", parameters: [
            kCIInputImageKey: ciImage
        ])
        guard let monoImage = monoFilter?.outputImage else {
            throw HarbethError.outputCIImage("CIPhotoEffectMono")
        }
        let invertFilter = CIFilter(name: "CIColorInvert", parameters: [
            kCIInputImageKey: monoImage
        ])
        guard let invertImage = invertFilter?.outputImage else {
            throw HarbethError.outputCIImage("CIColorInvert")
        }
        let radius = invertImage.extent.c7.radius(radius, max: Self.range.max)
        let blurFilter = CIFilter(name: "CIGaussianBlur", parameters: [
            kCIInputImageKey: invertImage,
            kCIInputRadiusKey: radius,
        ])
        blurFilter?.setDefaults()
        guard let blurImage = blurFilter?.outputImage else {
            throw HarbethError.outputCIImage("CIGaussianBlur")
        }
        filter.setValue(monoImage, forKey: kCIInputBackgroundImageKey)
        return blurImage
    }
    
    public init(radius: Float = range.value) {
        self.radius = radius
    }
}
