//
//  HomeViewModel.swift
//  MetalQueen
//
//  Created by Condy on 2021/8/7.
//

import Foundation
import UIKit
import ATMetalBand

typealias maxminTuple = (current: Float, min: Float, max: Float)?
typealias FilterCallback = (_ value: Float) -> C7FilterProtocol
typealias FilterResult = (filter: C7FilterProtocol, maxminValue: maxminTuple, callback: FilterCallback?)

enum ViewControllerType: String {
    case Luminance = "亮度"
    case ColorInvert = "颜色翻转"
    case ColorSwizzle = "颜色转换"
    case Opacity = "透明度"
    case Exposure = "曝光"
    case AddBlend = "叠加融合"
    case abao = "阿宝色滤镜"
    case ZoomBlur = "中心点缩放模糊"
    case Pixellated = "马赛克像素化"
    case AlphaBlend = "透明度融合"
    
    var image: UIImage {
        switch self {
        case .ColorInvert:
            return UIImage.init(named: "yuan000")!
        case .ColorSwizzle:
            return UIImage.init(named: "yuan001")!
        default:
            return UIImage.init(named: "timg-3")!
        }
    }
    
    func filterConfig() -> FilterResult {
        switch self {
        case .Luminance:
            var filter = C7Luminance(luminance: 0.5)
            let cb: FilterCallback = {
                filter.luminance = $0
                return filter
            }
            return (filter, (filter.luminance, filter.minLuminance, filter.maxLuminance), cb)
        case .ColorInvert:
            let filter = C7ComputeFilter(with: .colorInvert)
            return (filter, nil, nil)
        case .ColorSwizzle:
            let filter = C7ComputeFilter(with: .colorSwizzle)
            return (filter, nil, nil)
        case .Opacity:
            var filter = C7Opacity(opacity: 0.8)
            let cb: FilterCallback = {
                filter.opacity = $0
                return filter
            }
            return (filter, (filter.opacity, filter.minOpacity, filter.maxOpacity), cb)
        case .Exposure:
            var filter = C7Exposure(exposure: 0.8)
            let cb: FilterCallback = {
                filter.exposure = $0
                return filter
            }
            return (filter, (filter.exposure, -2, 2), cb)
        case .abao:
            var filter = C7LookupFilter(image: C7Image(named: "lut_abao")!)
            filter.intensity = -1
            let cb: FilterCallback = {
                filter.intensity = $0
                return filter
            }
            return (filter, (filter.intensity, -2, 2), cb)
        case .ZoomBlur:
            var filter = C7ZoomBlur(blurSize: 3)
            let cb: FilterCallback = {
                filter.blurSize = $0
                return filter
            }
            return (filter, (filter.blurSize, 0, 20), cb)
        case .Pixellated:
            var filter = C7Pixellated()
            let cb: FilterCallback = {
                filter.pixelWidth = $0
                return filter
            }
            return (filter, (filter.pixelWidth, 0, 0.2), cb)
        case .AddBlend:
            let filter = C7BlendFilter(with: .add, image: C7Image(named: "yuan000")!)
            return (filter, nil, nil)
        case .AlphaBlend:
            var filter = C7BlendFilter(with: .alpha(mixturePercent: 0.5), image: C7Image(named: "yuan000")!)
            let cb: FilterCallback = {
                filter.updateBlend(.alpha(mixturePercent: $0))
                return filter
            }
            return (filter, (0.5, 0, 1), cb)
        }
    }
}

struct HomeViewModel {
    lazy var section: [String] = {
        return ["效果类", "滤镜类"]
    }()
    
    lazy var datas: [[ViewControllerType]] = {
        return [effect, filter]
    }()
    
    let effect: [ViewControllerType] = [
        .Luminance, .Opacity, .Exposure,
        .ZoomBlur, .Pixellated, .AddBlend,
        .AlphaBlend,
    ]
    
    let filter: [ViewControllerType] = [
        .ColorInvert, .ColorSwizzle, .abao,
    ]
}
