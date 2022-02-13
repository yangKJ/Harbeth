//
//  HomeViewModel.swift
//  MetalQueen
//
//  Created by Condy on 2021/8/7.
//

import Foundation
import UIKit
//import ATMetalQueen

typealias maxminTuple = (current: Float, min: Float, max: Float)?
typealias FilterCallback = (_ value: Float) -> C7FilterProtocol
typealias FilterResult = (filter: C7FilterProtocol, maxminValue: maxminTuple, callback: FilterCallback?)

enum ViewControllerType: String {
    case Brightness = "Brightness"
    case Luminance = "Luminance"
    case ColorInvert = "颜色翻转 1-rgb"
    case ColorSwizzle = "rgba -> bgra"
    case Opacity = "透明度修改alpha"
    case Exposure = "曝光"
    case abao = "阿宝色滤镜"
    case ZoomBlur = "中心点缩放模糊"
    
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
        case .Brightness:
            var filter = C7Brightness(brightness: 0.2)
            let cb: FilterCallback = {
                filter.brightness = $0
                return filter
            }
            return (filter, (filter.brightness, filter.minBrightness, filter.maxBrightness), cb)
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
            var filter = C7LookupFilter(image: MTQImage(named: "lut_abao")!)
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
        .Brightness, .Luminance, .Opacity,
        .Exposure, .ZoomBlur,
    ]
    
    let filter: [ViewControllerType] = [
        .ColorInvert, .ColorSwizzle, .abao,
    ]
}
