//
//  C7Grayed.swift
//  Harbeth
//
//  Created by Condy on 2024/2/28.
//

import Foundation

/// 颜色转灰度图
public struct C7Grayed: C7FilterProtocol {
    /// https://en.wikipedia.org/wiki/Lightness#Lightness_and_human_perception
    /// https://tannerhelland.com/2011/10/01/grayscale-image-algorithm-vb6.html
    public enum GrayedMode {
        /// Weighted average method: The weighted average in rgb is used as gray.
        /// This algorithm is called Luminosity, or brightness algorithm.
        case luminosity
        /// The process of desaturation is to convert RGB to HLS and then set the saturation to 0.
        case desaturation
        /// Average method: rgb average value as gray.
        case average
        /// Maximum method: the maximum value in rgb as gray.
        case maximum
        /// Minimum method: the minimum value in rgb as gray.
        case minimum
        /// Take the value of a channel directly as the gray value. Alpha channel are not supported.
        case singleChannel(Pixel.Channel)
    }
    
    /// Specifies the intensity of the operation.
    @ZeroOneRange public var intensity: Float = R.iRange.value
    
    private let mode: GrayedMode
    
    public var modifier: Modifier {
        return .compute(kernel: mode.kernel)
    }
    
    public var factors: [Float] {
        return mode.factors(with: intensity)
    }
    
    public init(with mode: GrayedMode) {
        self.mode = mode
    }
}

extension C7Grayed.GrayedMode {
    var kernel: String {
        switch self {
        case .luminosity:
            return "C7GrayedLuminosity"
        case .desaturation:
            return "C7GrayedDesaturation"
        case .average:
            return "C7GrayedAverage"
        case .maximum:
            return "C7GrayedMaximum"
        case .minimum:
            return "C7GrayedMinimum"
        case .singleChannel:
            return "C7GrayedSingleChannel"
        }
    }
    
    func factors(with intensity: Float) -> [Float] {
        switch self {
        case .luminosity:
            return [intensity]
        case .desaturation:
            return [intensity]
        case .average:
            return [intensity]
        case .maximum:
            return [intensity]
        case .minimum:
            return [intensity]
        case .singleChannel(let c):
            return [intensity, Float(c.rawValue)]
        }
    }
}
