//
//  HomeViewModel.swift
//  MetalQueen
//
//  Created by Condy on 2021/8/7.
//

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
    case WhiteBalance = "白平衡"
    case Vibrance = "自然饱和度"
    case FalseColor = "伪色彩"
    case Crosshatch = "绘制阴影线"
    case Monochrome = "黑白照片"
    case ChromaKey = "类似绿幕抠图"
    case ReplaceColor = "扣掉红色替换背景"
    case ZoomBlur = "中心点缩放模糊"
    case Pixellated = "马赛克像素化"
    case abao = "阿宝色滤镜"
    case ColorInvert = "颜色反转"
    case Color2Gray = "灰度图滤镜"
    case Color2BGRA = "颜色转BGRA"
    case Color2BRGA = "颜色转BRGA"
    case Color2GBRA = "颜色转GBRA"
    case Color2GRBA = "颜色转GRBA"
    case Color2RBGA = "颜色转RBGA"
    case Bulge = "大胸效果"
    case HueBlend = "色相融合"
    case AlphaBlend = "透明度融合"
    case LuminosityBlend = "亮度融合"
    case Crop = "图形延展补齐"
    case Rotate = "图形旋转"
    case Flip = "图形翻转"
    case Resize = "改变尺寸"
    case MonochromeDilation = "黑白模糊"
    case GlassSphere = "玻璃球效果"
    case Split = "分割滤镜"
    case Sobel = "Sobel算子特征提取"
    case Pinch = "类似波浪效果"
    case PolkaDot = "波点"
    case Posterize = "色调分离"
    case Swirl = "漩涡鸣人"
    case MotionBlur = "移动模糊效果"
    case SoulOut = "灵魂出窍"
    case SplitScreen = "分屏展示"
    case Convolution3x3 = "卷积运算"
    case Sharpen3x3 = "锐化卷积"
}

extension ViewControllerType {
    var image: UIImage {
        switch self {
        case .ColorInvert, .Color2Gray, .Color2BGRA, .Color2BRGA, .Color2GBRA, .Color2GRBA, .Color2RBGA:
            return C7Image(named: "yuan002")!
        case .ZoomBlur, .Crop:
            return C7Image(named: "IMG_1668")!
        case .ChromaKey:
            return C7Image(named: "lvmu")!
        case .ReplaceColor, .Sobel:
            return C7Image(named: "IMG_2606")!
        case .FalseColor, .SoulOut:
            return C7Image(named: "test")!
        default:
            return C7Image(named: "timg-3")!
        }
    }
    
    func setupFilterObject() -> FilterResult {
        switch self {
        case .ColorInvert:
            let filter = C7Color2(with: .colorInvert)
            return (filter, nil, nil)
        case .Color2BGRA:
            let filter = C7Color2(with: .color2BGRA)
            return (filter, nil, nil)
        case .Color2BRGA:
            let filter = C7Color2(with: .color2BRGA)
            return (filter, nil, nil)
        case .Color2GBRA:
            let filter = C7Color2(with: .color2GBRA)
            return (filter, nil, nil)
        case .Color2GRBA:
            let filter = C7Color2(with: .color2GRBA)
            return (filter, nil, nil)
        case .Color2RBGA:
            let filter = C7Color2(with: .color2RBGA)
            return (filter, nil, nil)
        case .Luminance:
            var filter = C7Luminance()
            filter.luminance = 0.6
            return (filter, (0.6, 0, 1), {
                filter.luminance = $0
                return filter
            })
        case .Opacity:
            var filter = C7Opacity()
            filter.opacity = 0.8
            return (filter, (0.8, 0, 1), {
                filter.opacity = $0
                return filter
            })
        case .Exposure:
            var filter = C7Exposure()
            filter.exposure = 0.5
            return (filter, (0.5, -2, 2), {
                filter.exposure = $0
                return filter
            })
        case .abao:
            var filter = C7LookupFilter(image: C7Image(named: "lut_abao")!)
            filter.intensity = -0.5
            return (filter, (-0.5, -2, 2), {
                filter.intensity = $0
                return filter
            })
        case .ZoomBlur:
            var filter = C7ZoomBlur()
            filter.blurSize = 10
            return (filter, (10, 5, 15), {
                filter.blurSize = $0
                return filter
            })
        case .Pixellated:
            var filter = C7Pixellated()
            filter.pixelWidth = 0.03
            return (filter, (0.03, 0.01, 0.05), {
                filter.pixelWidth = $0
                return filter
            })
        case .HueBlend:
            let filter = C7BlendFilter(with: .hue, image: C7Image(named: "yuan000")!)
            return (filter, nil, nil)
        case .AlphaBlend:
            var filter = C7BlendFilter(with: .alpha(mixturePercent: 0.5), image: C7Image(named: "yuan000")!)
            return (filter, (0.5, 0, 1), {
                filter.updateBlend(.alpha(mixturePercent: $0))
                return filter
            })
        case .LuminosityBlend:
            let filter = C7BlendFilter(with: .luminosity, image: C7Image(named: "yuan000")!)
            return (filter, nil, nil)
        case .Hue:
            var filter = C7Hue()
            filter.hue = 30
            return (filter, (30, 0, 45), {
                filter.hue = $0
                return filter
            })
        case .Bulge:
            var filter = C7Bulge()
            filter.scale = 0.2
            return (filter, (0.2, -0.5, 0.5), {
                filter.scale = $0
                return filter
            })
        case .Color2Gray:
            let filter = C7Color2(with: .color2Gray)
            return (filter, nil, nil)
        case .Contrast:
            var filter = C7Contrast()
            return (filter, (1, 0, 4), {
                filter.contrast = $0
                return filter
            })
        case .Saturation:
            var filter = C7Saturation()
            return (filter, (1, 0, 2), {
                filter.saturation = $0
                return filter
            })
        case .ChannelRGBA:
            var filter = C7ChannelRGBA()
            filter.color = UIColor.white
            return (filter, (filter.red, 0, 10), {
                filter.red = $0
                return filter
            })
        case .HighlightShadow:
            var filter = C7HighlightShadow()
            filter.highlights = 0.5
            filter.shadows = 0.5
            return (filter, (0.5, 0, 1), {
                filter.highlights = $0
                filter.shadows = $0
                return filter
            })
        case .Monochrome:
            var filter = C7Monochrome()
            filter.intensity = 0.9
            return (filter, (0.9, 0, 1), {
                filter.intensity = $0
                return filter
            })
        case .ChromaKey:
            var filter = C7ChromaKey()
            filter.color = UIColor.green
            filter.smoothing = 0.05
            return (filter, nil, nil)
        case .ReplaceColor:
            var filter = C7ReplaceRGBA()
            filter.chroma = UIColor.red
            filter.replaceColor = UIColor.purple
            filter.smoothing = 0.1
            return (filter, nil, nil)
        case .Crop:
            var filter = C7Crop()
            filter.origin = C7Point2D(x: 0.3, y: 0.3)
            filter.height = 1080
            return (filter, (0.3, 0, 1), {
                filter.origin = C7Point2D(x: $0, y: $0)
                return filter
            })
        case .Rotate:
            var filter = C7Rotate()
            filter.angle = 10
            return (filter, (10, 0, 360), {
                filter.angle = $0
                return filter
            })
        case .Flip:
            var filter = C7Flip()
            filter.vertical = true
            return (filter, nil, nil)
        case .Crosshatch:
            var filter = C7Crosshatch()
            return (filter, (0.03, 0.01, 0.08), {
                filter.crosshatchSpacing = $0
                return filter
            })
        case .WhiteBalance:
            var filter = C7WhiteBalance()
            filter.temperature = 4444
            return (filter, (4444, 4000, 7000), {
                filter.temperature = $0
                return filter
            })
        case .Resize:
            var filter = C7Resize()
            filter.width = 1000
            return (filter, (1000, 50, 2000), {
                filter.width = Int($0)
                return filter
            })
        case .MonochromeDilation:
            var filter = C7MonochromeDilation()
            filter.pixelRadius = 1
            return (filter, (1, 0, 10), {
                filter.pixelRadius = Int($0)
                return filter
            })
        case .Vibrance:
            var filter = C7Vibrance()
            filter.vibrance = 0.6
            return (filter, (0.6, -1.2, 1.2), {
                filter.vibrance = $0
                return filter
            })
        case .GlassSphere:
            var filter = C7GlassSphere()
            return (filter, (0.25, 0, 0.5), {
                filter.radius = $0
                return filter
            })
        case .FalseColor:
            var filter = C7FalseColor()
            filter.fristColor = UIColor.black
            filter.secondColor = UIColor.systemPink
            return (filter, nil, nil)
        case .Split:
            var filter = C7LookupSplitFilter(C7Image(named: "lut_abao")!, lookupImage2: C7Image(named: "ll")!)
            filter.progress = 0.5
            filter.intensity = 0
            return (filter, (0.5, 0, 1), {
                filter.progress = $0
                filter.intensity = $0 * 2 - 2
                return filter
            })
        case .Sobel:
            var filter = C7Sobel()
            filter.edgeStrength = 1.5
            return (filter, (1.5, 0, 5), {
                filter.edgeStrength = $0
                return filter
            })
        case .Pinch:
            var filter = C7Pinch()
            filter.radius = 0.25
            return (filter, (0.25, 0, 0.5), {
                filter.radius = $0
                return filter
            })
        case .PolkaDot:
            var filter = C7PolkaDot()
            filter.fractionalWidth = 0.05
            return (filter, (0.05, 0.01, 0.2), {
                filter.fractionalWidth = $0
                return filter
            })
        case .Posterize:
            var filter = C7Posterize()
            filter.colorLevels = 2
            return (filter, (2, 0.5, 5), {
                filter.colorLevels = $0
                return filter
            })
        case .Swirl:
            var filter = C7Swirl()
            return (filter, (0.25, 0, 0.5), {
                filter.radius = $0
                return filter
            })
        case .MotionBlur:
            var filter = C7MotionBlur()
            filter.blurAngle = 45
            filter.blurSize = 5
            return (filter, (5, 1, 10), {
                filter.blurSize = $0
                return filter
            })
        case .SoulOut:
            var filter = C7SoulOut()
            filter.soul = 0.5
            filter.maxScale = 2.0
            return (filter, (0.5, 0.1, 1.0), {
                filter.soul = $0
                return filter
            })
        case .SplitScreen:
            let filter = C7SplitScreen()
            return (filter, nil, nil)
        case .Convolution3x3:
            let filter = C7Convolution3x3(convolutionType: .default)
            return (filter, nil, nil)
        case .Sharpen3x3:
            var filter = C7Convolution3x3(convolutionType: .sharpen(iterations: 1))
            return (filter, (1, 0, 7), {
                filter.updateMatrix(.sharpen(iterations: $0))
                return filter
            })
        }
    }
}

struct HomeViewModel {
    lazy var section: [String] = {
        return ["效果类", "颜色处理", "形状变化", "模糊处理", "图片融合类", "滤镜类", "矩阵卷积"]
    }()
    
    lazy var datas: [[ViewControllerType]] = {
        return [effect, colorProcess, shape, blur, blend, lookup, matrix]
    }()
    
    let effect: [ViewControllerType] = [
        .SoulOut, .ZoomBlur,
        .Pixellated, .Crosshatch, .GlassSphere,
        .Bulge, .Pinch, .PolkaDot,
        .Posterize, .Swirl, .SplitScreen,
        .Monochrome, .ReplaceColor, .ChromaKey,
    ]
    
    let colorProcess: [ViewControllerType] = [
        .Opacity, .Exposure, .Luminance,
        .Hue, .Contrast, .HighlightShadow,
        .Saturation, .WhiteBalance, .Vibrance,
        .Sobel,
        .ChannelRGBA, .FalseColor, .ColorInvert,
        .Color2Gray, .Color2BGRA, .Color2BRGA,
        .Color2GBRA, .Color2GRBA, .Color2RBGA,
    ]
    
    let shape: [ViewControllerType] = [
        .Crop, .Rotate, .Resize, .Flip,
    ]
    
    let blur: [ViewControllerType] = [
        .MonochromeDilation, .MotionBlur,
    ]
    
    let blend: [ViewControllerType] = [
        .HueBlend, .AlphaBlend, .LuminosityBlend,
    ]
    
    let lookup: [ViewControllerType] = [
        .abao, .Split,
    ]
    
    let matrix: [ViewControllerType] = [
        .Convolution3x3, .Sharpen3x3,
    ]
}
