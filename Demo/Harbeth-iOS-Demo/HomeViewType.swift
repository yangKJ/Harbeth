//
//  HomeViewType.swift
//  MetalDemo
//
//  Created by Condy on 2022/3/6.
//

import Harbeth

enum ViewControllerType: String {
    // 颜色调整
    case Luminance = "亮度"
    case Opacity = "透明度"
    case Hue = "色相角度"
    case Exposure = "曝光"
    case Contrast = "对比度"
    case Saturation = "饱和度"
    case WhiteBalance = "白平衡"
    case Vibrance = "自然饱和度"
    case FalseColor = "伪色彩"
    case Monochrome = "黑白照片"
    case Posterize = "色调分离"
    case Sepia = "棕褐色老照片"
    case Brightness = "亮度调整"
    case Gamma = "伽马调整"
    case ColorSpace = "色彩空间"
    case LuminanceAdaptiveContrast = "亮度自适应对比度"
    case Nostalgic = "怀旧效果"
    
    // 颜色转换
    case ColorInvert = "颜色反转"
    case Color2Gray = "灰度图滤镜"
    case Color2BGRA = "颜色转BGRA"
    case Color2BRGA = "颜色转BRGA"
    case Color2GBRA = "颜色转GBRA"
    case Color2GRBA = "颜色转GRBA"
    case Color2RBGA = "颜色转RBGA"
    
    // 模糊效果
    case ZoomBlur = "中心点缩放模糊"
    case MotionBlur = "移动模糊效果"
    case MeanBlur = "均值模糊"
    case GaussianBlur = "高斯模糊"
    case BilateralBlur = "双边模糊"
    case SurfaceBlur = "表面模糊"
    case CircleBlur = "圆形模糊"
    case DetailPreservingBlur = "细节保留模糊"
    case MonochromeDilation = "黑白模糊"
    
    // 边缘和细节
    case Crosshatch = "绘制阴影线"
    case Sobel = "Sobel算子特征提取"
    case Canny = "边缘检测滤镜"
    case Sketch = "素描效果"
    case ComicStrip = "连环画效果"
    case Granularity = "颗粒感"
    case DetailEnhancer = "细节增强"
    case EdgeAwareSharpen = "边缘感知锐化"
    case ThresholdSketch = "阈值素描"
    
    // 扭曲和变形
    case Bulge = "大胸效果"
    case Pinch = "类似波浪效果"
    case Swirl = "漩涡鸣人"
    case WaterRipple = "水波效果"
    case GlassSphere = "玻璃球效果"
    case Pixellated = "马赛克像素化"
    case PolkaDot = "波点"
    case Halftone = "半色调"
    case PolarPixellate = "极坐标像素化"
    case SphereRefraction = "球体折射"
    
    // 几何变换
    case Crop = "图形延展补齐"
    case Rotate = "图形旋转"
    case Flip = "图形翻转"
    case Resize = "改变尺寸"
    case Transform = "透视变形"
    case Mirror = "镜像效果"
    
    // 混合模式
    case HueBlend = "色相融合"
    case AlphaBlend = "透明度融合"
    case LuminanceBlend = "亮度融合"
    case ColorBlend = "颜色融合"
    case SaturationBlend = "饱和度融合"
    case NormalBlend = "正常融合"
    case AddBlend = "添加融合"
    case ColorBurnBlend = "颜色加深融合"
    case ColorDodgeBlend = "颜色减淡融合"
    case DarkenBlend = "变暗融合"
    case DarkerColorBlend = "更暗颜色融合"
    case DifferenceBlend = "差值融合"
    case DissolveBlend = "溶解融合"
    case DivideBlend = "划分融合"
    case ExclusionBlend = "排除融合"
    case HardLightBlend = "强光融合"
    case HardMixBlend = "实色混合融合"
    case LightenBlend = "变亮融合"
    case LighterColorBlend = "更亮颜色融合"
    case LinearBurnBlend = "线性加深融合"
    case LinearLightBlend = "线性光融合"
    case MaskBlend = "蒙版融合"
    case MultiplyBlend = "正片叠底融合"
    case OverlayBlend = "叠加融合"
    case PinLightBlend = "点光融合"
    case ScreenBlend = "滤色融合"
    case SoftLightBlend = "柔光融合"
    case SourceOverBlend = "源覆盖融合"
    case SubtractBlend = "减去融合"
    case VividLightBlend = "艳光融合"
    case ChromaKey = "类似绿幕抠图"
    case ReplaceColor = "扣掉红色替换背景"
    
    // 查找表
    case abao = "阿宝色滤镜"
    case Split = "分割滤镜"
    case ColorLookup512x512 = "512颜色查找表"
    case ColorCube = "颜色立方体"
    
    // 矩阵处理
    case Convolution3x3 = "3x3卷积运算"
    case Sharpen3x3 = "锐化卷积"
    case ColorMatrix4x4 = "4x4颜色矩阵"
    case ColorMatrix4x5 = "4x5颜色矩阵"
    case ColorVector4 = "颜色向量4"
    case EdgeGlow = "边缘发光特效"
    
    // 风格化
    case SoulOut = "灵魂出窍"
    case SplitScreen = "分屏展示"
    case Storyboard = "分镜展示"
    case OilPainting = "油画效果"
    case ShiftGlitch = "色彩故障转移特效"
    case VoronoiOverlay = "泰森多边形法叠加效果"
    case ColorCGASpace = "CGA色彩空间"
    case Fluctuate = "波动效果"
    case Glitch = "故障效果"
    case Kuwahara = "桑原效果"
    case Toon = "卡通效果"
    
    // 其他效果
    case Vignette = "渐进效果"
    case VignetteNormal = "暗角-正常混合"
    case VignetteMultiply = "暗角-正片叠底"
    case VignetteOverlay = "暗角-叠加"
    case VignetteSoftLight = "暗角-柔和光"
    case ChannelRGBA = "RGBA通道"
    case HighlightShadow = "高光阴影"
    case Levels = "色阶"
    case Grayed = "灰度图像"
    case Haze = "雾霾效果"
    case Pow = "幂次效果"
    case HighlightShadowTint = "高光阴影色调"
    case Highlights = "高光"
    case Shadows = "阴影"
    
    // 生成器
    case ColorGradient = "颜色渐变"
    case SolidColor = "纯色"
    
    // 组合效果
    case CombinationBeautiful = "美颜组合"
    case CombinationCinematic = "电影级色调"
    case CombinationModernHDR = "现代HDR"
    case CombinationVintage = "复古胶片"
    
    // Blit操作
    case BlitCrop = "裁剪"
    case BlitCopyRegion = "复制区域"
    case BlitGenerateMipmaps = "生成Mipmaps"
    
    // 测试
    case CIHS = "coreImage高光阴影"
    case TextHEIC = "测试HEIC类型图片"
    case MPSGaussian = "MPS高斯模糊"
    case CIGaussian = "CI高斯模糊"
    case ColorMonochrome = "单色滤镜"
}

extension ViewControllerType {
    var image: UIImage {
        switch self {
        case .Bulge:
            return R.image("timg-3")!
        case .TextHEIC:
            return R.image("IMG_3960.HEIC")!
        case .ChromaKey, .ReplaceColor:
            return R.image("IMG_2606")!
        case .SoulOut:
            return R.image("IMG_2623")!
        case .BlitGenerateMipmaps:
            return [R.image("wechat0")!, R.image("wechat1")!].randomElement()!
        default:
            let images = [
                R.image("wechat0")!, R.image("wechat1")!, R.image("P104080")!,
                R.image("yuan000")!, R.image("yuan001")!, R.image("yuan002")!,
                R.image("yuan003")!, R.image("yuan004")!, R.image("yuan005")!,
                R.image("IMG_6781")!,
            ]
            return images.randomElement()!
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
