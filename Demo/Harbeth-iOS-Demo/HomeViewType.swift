//
//  HomeViewType.swift
//  MetalDemo
//
//  Created by Condy on 2022/3/6.
//

import Harbeth

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
    case TextHEIC = "测试HEIC类型图片"
    case MPSGaussian = "MPS高斯模糊"
    case CIGaussian = "CI高斯模糊"
    case Grayed = "灰度图像"
    case ColorMonochrome = "单色滤镜"
    case Canny = "边缘检测滤镜"
}

extension ViewControllerType {
    var image: UIImage {
        switch self {
        case .ColorInvert, .Color2BGRA, .Color2BRGA, .Color2GBRA, .Color2GRBA, .Color2RBGA,
                .ComicStrip, .OilPainting, .Sketch:
            return R.image("yuan002")!
        case .EdgeGlow, .ShiftGlitch:
            return R.image("yuan003")!
        case .Bulge:
            return R.image("timg-3")!
        case .TextHEIC:
            return R.image("IMG_3960.HEIC")!
        case .ChromaKey, .ReplaceColor, .Sobel:
            return R.image("IMG_2606")!
        case .AlphaBlend, .HueBlend, .LuminosityBlend:
            return R.image("P1040808")!
        default:
            return R.image("P1040808")!
        }
    }

    var overTexture: MTLTexture? {
        let color = UIColor.green.withAlphaComponent(0.5)
        guard let texture = try? TextureLoader.makeTexture(width: 480, height: 270) else {
            return nil
        }
        let filter = C7SolidColor.init(color: color)
        let dest = HarbethIO(element: texture, filter: filter)
        return try? dest.output()
    }
}
