//
//  HomeViewModel.swift
//  MetalQueen
//
//  Created by Condy on 2021/8/7.
//

import Foundation
import UIKit

typealias maxminTuple = (max: Float, min: Float, current: Float)?
typealias FilterCallback = (_ value: Float) -> C7FilterProtocol

enum ViewControllerType: String {
    case Brightness = "Brightness"
    case Luminance = "Luminance"
    case ColorInvert = "颜色翻转 1-rgb"
    case ColorSwizzle = "rgba -> bgra"
    case Opacity = "透明度修改alpha"
    case Exposure = "曝光"
    
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
    
    func filterConfig() -> (filter: C7FilterProtocol, maxminValue: maxminTuple, callback: FilterCallback?) {
        switch self {
        case .Brightness:
            var filter = C7Brightness()
            filter.brightness = 0.2
            let cb: FilterCallback = {
                filter.brightness = $0
                return filter
            }
            return (filter, (filter.maxBrightness, filter.minBrightness, filter.brightness), cb)
        case .Luminance:
            var filter = C7Luminance()
            filter.luminance = 0.5
            let cb: FilterCallback = {
                filter.luminance = $0
                return filter
            }
            return (filter, (filter.maxLuminance, filter.minLuminance, filter.luminance), cb)
        case .ColorInvert:
            let filter = C7ComputeFilter(with: .colorInvert)
            return (filter, nil, nil)
        case .ColorSwizzle:
            let filter = C7ComputeFilter(with: .colorSwizzle)
            return (filter, nil, nil)
        case .Opacity:
            var filter = C7Opacity()
            filter.opacity = 0.8
            let cb: FilterCallback = {
                filter.opacity = $0
                return filter
            }
            return (filter, (filter.maxOpacity, filter.minOpacity, filter.opacity), cb)
        case .Exposure:
            var filter = C7Exposure()
            filter.exposure = 0.8
            let cb: FilterCallback = {
                filter.exposure = $0
                return filter
            }
            return (filter, (2, -2, filter.exposure), cb)
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
        .Exposure,
    ]
    
    let filter: [ViewControllerType] = [
        .ColorInvert, .ColorSwizzle,
    ]
}
