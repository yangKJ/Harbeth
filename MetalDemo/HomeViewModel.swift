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
    case Opacity = "透明度"
    case Hue = "色相角度"
    case Exposure = "曝光"
    case Contrast = "对比度"
    case Saturation = "饱和度"
    case ChannelRGBA = "RGBA通道"
    case HighlightShadow = "高光阴影"
    case Monochrome = "黑白照片"
    case ZoomBlur = "中心点缩放模糊"
    case Pixellated = "马赛克像素化"
    case abao = "阿宝色滤镜"
    case ColorInvert = "颜色反转"
    case Color2Gray = "灰度图滤镜"
    case Color2BGRA = "颜色转BGRA"
    case Bulge = "鼓起效果"
    case Blend = "测试融合"
    case AlphaBlend = "透明度融合"
    case LuminosityBlend = "亮度融合"
}

extension ViewControllerType {
    var image: UIImage {
        switch self {
        case .ColorInvert:
            return UIImage.init(named: "yuan000")!
        case .Color2BGRA:
            return UIImage.init(named: "yuan001")!
        case .Color2Gray:
            return UIImage.init(named: "yuan002")!
        case .ZoomBlur:
            return UIImage.init(named: "IMG_1668")!
        default:
            return UIImage.init(named: "timg-3")!
        }
    }
    
    func setupFilterObject() -> FilterResult {
        switch self {
        case .Blend:
            let filter = C7BlendFilter(with: .hue, image: C7Image(named: "yuan000")!)
            return (filter, nil, nil)
        case .Luminance:
            var filter = C7Luminance()
            let cb: FilterCallback = {
                filter.luminance = $0
                return filter
            }
            return (filter, (filter.luminance, filter.minLuminance, filter.maxLuminance), cb)
        case .ColorInvert:
            let filter = C7ComputeFilter(with: .colorInvert)
            return (filter, nil, nil)
        case .Color2BGRA:
            let filter = C7ComputeFilter(with: .color2BGRA)
            return (filter, nil, nil)
        case .Opacity:
            var filter = C7Opacity()
            let cb: FilterCallback = {
                filter.opacity = $0
                return filter
            }
            return (filter, (filter.opacity, filter.minOpacity, filter.maxOpacity), cb)
        case .Exposure:
            var filter = C7Exposure()
            let cb: FilterCallback = {
                filter.exposure = $0
                return filter
            }
            return (filter, (filter.exposure, -2, 2), cb)
        case .abao:
            var filter = C7LookupFilter(image: C7Image(named: "lut_abao")!)
            filter.intensity = -0.5
            let cb: FilterCallback = {
                filter.intensity = $0
                return filter
            }
            return (filter, (filter.intensity, -2, 2), cb)
        case .ZoomBlur:
            var filter = C7ZoomBlur()
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
        case .AlphaBlend:
            var filter = C7BlendFilter(with: .alpha(mixturePercent: 0.5), image: C7Image(named: "yuan000")!)
            let cb: FilterCallback = {
                filter.updateBlend(.alpha(mixturePercent: $0))
                return filter
            }
            return (filter, (0.5, 0, 1), cb)
        case .LuminosityBlend:
            let filter = C7BlendFilter(with: .luminosity, image: C7Image(named: "yuan000")!)
            return (filter, nil, nil)
        case .Hue:
            var filter = C7Hue()
            let cb: FilterCallback = {
                filter.hue = $0
                return filter
            }
            return (filter, (filter.hue, 0, 45), cb)
        case .Bulge:
            var filter = C7Bulge()
            let cb: FilterCallback = {
                filter.scale = $0
                return filter
            }
            return (filter, (filter.scale, -1, 1), cb)
        case .Color2Gray:
            let filter = C7ComputeFilter(with: .color2Gray)
            return (filter, nil, nil)
        case .Contrast:
            var filter = C7Contrast()
            let cb: FilterCallback = {
                filter.contrast = $0
                return filter
            }
            return (filter, (filter.contrast, 0, 4), cb)
        case .Saturation:
            var filter = C7Saturation()
            let cb: FilterCallback = {
                filter.saturation = $0
                return filter
            }
            return (filter, (filter.saturation, 0, 2), cb)
        case .ChannelRGBA:
            var filter = C7ChannelRGBA()
            filter.color = UIColor.cyan
            let cb: FilterCallback = {
                filter.red = $0
                return filter
            }
            return (filter, (filter.red, 0, 10), cb)
        case .HighlightShadow:
            var filter = C7HighlightShadow()
            filter.highlights = 0.5
            filter.shadows = 0.5
            let cb: FilterCallback = {
                filter.highlights = $0
                filter.shadows = $0
                return filter
            }
            return (filter, (0.5, 0, 1), cb)
        case .Monochrome:
            var filter = C7Monochrome()
            filter.intensity = 0.5
            filter.color = UIColor.red
            let cb: FilterCallback = {
                filter.intensity = $0
                return filter
            }
            return (filter, (filter.intensity, 0, 1), cb)
        }
    }
}

struct HomeViewModel {
    lazy var section: [String] = {
        return ["效果类", "模糊处理", "图片融合类", "滤镜类"]
    }()
    
    lazy var datas: [[ViewControllerType]] = {
        return [effect, blur, blend, filter]
    }()
    
    let effect: [ViewControllerType] = [
        .Opacity, .Exposure, .Luminance,
        .Hue, .Bulge, .Contrast,
        .Saturation, .ChannelRGBA, .HighlightShadow,
        .Monochrome,
    ]
    
    let blur: [ViewControllerType] = [
        .ZoomBlur, .Pixellated,
    ]
    
    let blend: [ViewControllerType] = [
        .Blend, .AlphaBlend, .LuminosityBlend,
    ]
    
    let filter: [ViewControllerType] = [
        .abao, .Color2Gray, .Color2BGRA,
        .ColorInvert,
    ]
}
