//
//  HomeViewType.swift
//  MetalDemo
//
//  Created by Condy on 2022/3/6.
//

import Harbeth

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
    case Granularity = "颗粒感"
    case Vignette = "渐进效果"
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
    case Convolution3x3 = "3x3卷积运算"
    case Sharpen3x3 = "锐化卷积"
    case WaterRipple = "水波效果"
    case ColorMatrix4x4 = "4x4颜色矩阵"
    case Levels = "色阶"
    case Transform = "透视变形"
    case ShiftGlitch = "色彩故障转移特效"
    case EdgeGlow = "边缘发光特效"
    case VoronoiOverlay = "泰森多边形法叠加效果"
    case MeanBlur = "均值模糊"
    case GaussianBlur = "高斯模糊"
    case Storyboard = "分镜展示"
    case BilateralBlur = "双边模糊"
    case Sepia = "棕褐色老照片"
    case ComicStrip = "连环画效果"
    case OilPainting = "油画效果"
    case Sketch = "素描效果"
    case CIHS = "coreImage高光阴影"
}

extension ViewControllerType {
    var image: UIImage {
        switch self {
        case .ColorInvert, .Color2Gray, .Color2BGRA, .Color2BRGA, .Color2GBRA, .Color2GRBA, .Color2RBGA,
                .ComicStrip, .OilPainting, .Sketch:
            return C7Image(named: "yuan002")!
        case .EdgeGlow, .ShiftGlitch:
            return C7Image(named: "yuan003")!
        case .Crop:
            return C7Image(named: "IMG_1668")!
        case .ChromaKey, .ReplaceColor, .Sobel:
            return C7Image(named: "IMG_2606")!
        default:
            return C7Image(named: "timg-3")!
        }
    }
    
    func setupFilterObject() -> FilterResult {
        switch self {
        case .ColorInvert:
            let filter = C7ColorConvert(with: .colorInvert)
            return (filter, nil, nil)
        case .Color2BGRA:
            let filter = C7ColorConvert(with: .color2BGRA)
            return (filter, nil, nil)
        case .Color2BRGA:
            let filter = C7ColorConvert(with: .color2BRGA)
            return (filter, nil, nil)
        case .Color2GBRA:
            let filter = C7ColorConvert(with: .color2GBRA)
            return (filter, nil, nil)
        case .Color2GRBA:
            let filter = C7ColorConvert(with: .color2GRBA)
            return (filter, nil, nil)
        case .Color2RBGA:
            let filter = C7ColorConvert(with: .color2RBGA)
            return (filter, nil, nil)
        case .Color2Gray:
            let filter = C7ColorConvert(with: .color2Gray)
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
            var filter = C7ColorRGBA()
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
            filter.color = UIColor.red
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
            return (filter, (1, 0, 5), {
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
            filter.maxScale = 1.5
            return (filter, (0.5, 0.1, 0.8), {
                filter.soul = $0
                return filter
            })
        case .SplitScreen:
            let filter = C7SplitScreen()
            return (filter, nil, nil)
        case .Sharpen3x3:
            var filter = C7Convolution3x3(convolutionType: .sharpen(iterations: 1))
            return (filter, (1, 0, 7), {
                filter.updateMatrix(.sharpen(iterations: $0))
                return filter
            })
        case .Granularity:
            var filter = C7Granularity()
            return (filter, (0.3, 0, 0.5), {
                filter.grain = $0
                return filter
            })
        case .Vignette:
            var filter = C7Vignette()
            filter.color = UIColor.systemPink
            return (filter, (0.3, 0.1, filter.end), {
                filter.start = $0
                return filter
            })
        case .WaterRipple:
            var filter = C7WaterRipple()
            return (filter, (0, 0.1, 0.8), {
                filter.ripple = $0
                return filter
            })
        case .Levels:
            var filter = C7Levels()
            filter.minimum = UIColor.purple
            return (filter, nil, nil)
        case .Transform:
            let transform = CGAffineTransform(scaleX: 0.8, y: 1).rotated(by: .pi / 6)
            let filter = C7Transform(transform: transform)
            return (filter, nil, nil)
        case .ShiftGlitch:
            var filter = C7ShiftGlitch()
            return (filter, (0.5, 0.1, 0.5), {
                filter.time = $0
                return filter
            })
        case .EdgeGlow:
            var filter = C7EdgeGlow()
            return (filter, (0.5, 0.1, 0.6), {
                filter.time = $0
                return filter
            })
        case .VoronoiOverlay:
            var filter = C7VoronoiOverlay()
            return (filter, (0.5, 0.1, 0.6), {
                filter.time = $0
                return filter
            })
        case .MeanBlur:
            var filter = C7MeanBlur()
            return (filter, (1, 0, 2), {
                filter.blurRadius = $0
                return filter
            })
        case .GaussianBlur:
            var filter = C7GaussianBlur()
            return (filter, (1, 0, 2), {
                filter.blurRadius = $0
                return filter
            })
        case .Storyboard:
            var filter = C7Storyboard()
            return (filter, (2, 1, 10), {
                filter.N = Int(ceil($0))
                return filter
            })
        case .BilateralBlur:
            var filter = C7BilateralBlur()
            return (filter, (1, 0, 1), {
                filter.blurRadius = $0
                return filter
            })
        case .Sepia:
            let filter = C7Sepia()
            return (filter, nil, nil)
        case .ComicStrip:
            let filter = C7ComicStrip()
            return (filter, nil, nil)
        case .OilPainting:
            let filter = C7OilPainting()
            return (filter, nil, nil)
        case .Sketch:
            var filter = C7Sketch()
            filter.edgeStrength = 0.3
            return (filter, nil, nil)
        case .ColorMatrix4x4:
            var filter = C7ColorMatrix4x4(matrix: Harbeth.Matrix4x4.replaced_red_green)
            filter.offset = C7ColorOffset(0, 0, 1, 0)
            filter.intensity = 0.3
            return (filter, (0.3, 0.1, 1.0), {
                filter.intensity = $0
                return filter
            })
        case .Convolution3x3:
            let filter = C7Convolution3x3(convolutionType: .custom(Matrix3x3.embossment))
            return (filter, nil, nil)
        case .CIHS:
            var filter = CIHighlightShadow()
            return (filter, (1, 0, 1), {
                filter.value = $0
                return filter
            })
        }
    }
}
