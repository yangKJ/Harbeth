//
//  HomeViewModel.swift
//  MetalQueen
//
//  Created by Condy on 2021/8/7.
//

import Foundation
import UIKit

enum ViewType {
    case image, camera, player
}

struct HomeViewModel {
    var viewType: ViewType
    
    func setupViewController(_ type: ViewControllerType) -> UIViewController {
        switch viewType {
        case .image:
            let vc = ImageViewController()
            let image = type.image
            let tuple = type.setupFilterObject(with: image)
            vc.filter = tuple.filter
            vc.callback = tuple.callback
            if let maxmin = tuple.maxminValue {
                vc.slider.minimumValue = maxmin.min
                vc.slider.maximumValue = maxmin.max
                vc.slider.value = maxmin.current
            } else {
                vc.slider.isHidden = true
            }
            vc.originImage = image
            return vc
        case .camera:
            let vc = CameraViewController()
            vc.tuple = type.setupFilterObject()
            return vc
        case .player:
            let vc = PlayerViewController()
            vc.tuple = type.setupFilterObject()
            return vc
        }
    }
    
    lazy var datas: [String: [ViewControllerType]] = {
        switch viewType {
        case .image, .player:
            return [
                "🖼️ 测试用例": test,
                "📱 相机风格滤镜": cameraStyle,
                "🤡 场景风格滤镜": sceneStyle,
                "🎨 艺术风格滤镜": artStyle,
                "🔍 边缘与细节": edgeDetail,
                "🌫️ 模糊效果": blur,
                "🎭 风格化效果": stylization,
                "🌈 颜色调整": color,
                "🔄 形状变化": shape,
                "🔗 混合模式": blend,
                "📊 矩阵处理": matrix,
                "🔧 实用工具": utility,
                "📋 查找滤镜": lookup,
                "🌅 效果滤镜": effect,
                "🎯 视觉效果": visual,
                "🔬 Blit操作": blit,
                "🔌 CoreImage": coreImage,
            ].filter { $0.value.count > 0 }
        case .camera:
            var filters = color
            filters.insert(.Storyboard, at: 0)
            filters.insert(.Rotate, at: 1)
            filters.insert(.Flip, at: 2)
            return ["📷 相机特效 - 真机测试": filters]
        }
    }()
    
    let test: [ViewControllerType] = [
        .TextHEIC,
    ]
    
    // 相机风格滤镜
    let cameraStyle: [ViewControllerType] = [
        
    ]
    
    // 场景风格滤镜
    let sceneStyle: [ViewControllerType] = [
        .CombinationCinematic, .CombinationModernHDR, .CombinationVintage,
        .CombinationColorGrading, .CombinationCreativeAtmosphere, .CombinationFilmSimulation,
        .CombinationHDRBoost, .CombinationCyberpunk, .CombinationDreamy,
        .CombinationVintageFilm,
    ]
    
    // 艺术风格滤镜
    let artStyle: [ViewControllerType] = [
        .ComicStrip, .OilPainting, .OilPaintingEnhanced, .Sketch, .Crosshatch, .Toon, .Kuwahara
    ]
    
    // 边缘与细节
    let edgeDetail: [ViewControllerType] = [
        .Sharpen3x3, .Sobel, .Canny, .Luminance,
        .DetailEnhancer, .EdgeAwareSharpen, .ThresholdSketch, .EdgeGlow, .Sharpen, .SharpenEnhanced, .StickerOutline
    ]
    
    // 风格化效果
    let stylization: [ViewControllerType] = [
        .ShiftGlitch, .SoulOut, .EdgeGlow, .VoronoiOverlay, .Storyboard,
        .WaterRipple, .Swirl, .SplitScreen, .ColorCGASpace,
        .Fluctuate, .Glitch, .Kuwahara, .Toon, .OilPainting, .OilPaintingEnhanced, .RGBADilation
    ]
    
    // 实用工具
    let utility: [ViewControllerType] = [
        .Opacity, .Levels, .HighlightShadow, .WhiteBalance, .Vibrance,
        .Granularity, .FalseColor, .ColorInvert, .Grayed, .Haze, .Pow, .Fade,
        .HighlightShadowTint, .Highlights, .Shadows, .LuminanceThreshold, .LuminanceRangeReduction, .DepthLuminance
    ]
    
    let visual: [ViewControllerType] = [
        .ShiftGlitch, .SoulOut, .EdgeGlow,
        .Luminance, .ColorMatrix4x4, .Monochrome,
        .VoronoiOverlay, .Storyboard,
    ]
    
    let effect: [ViewControllerType] = [
        .ZoomBlur, .Vignette, .VignetteNormal, .VignetteMultiply, .VignetteOverlay,
        .VignetteSoftLight, .WaterRipple,
        .Pixellated, .Crosshatch, .GlassSphere,
        .Bulge, .Pinch, .PolkaDot, .Halftone, .PolarPixellate, .SphereRefraction, .Morphology, .ColorPacking,
        .Posterize, .Swirl, .SplitScreen, .Storyboard,
        .Monochrome, .ReplaceColor, .ChromaKey,
        .VoronoiOverlay, .Canny, .CombinationBeautiful,
        .ColorGradient, .SolidColor
    ]
    
    let color: [ViewControllerType] = [
        .Opacity, .Exposure, .Luminance,
        .Hue, .Contrast, .HighlightShadow,
        .Saturation, .WhiteBalance, .Vibrance,
        .Temperature, .HSL, .Curves, .ColorBalanceEnhanced,
        .Warmth, .Clarity, .Granularity, .Levels, .Sobel,
        .ChannelRGBA, .FalseColor, .ColorInvert,
        .Grayed, .Color2Gray, .Color2BGRA, .Color2BRGA,
        .Color2GBRA, .Color2GRBA, .Color2RBGA,
        .ComicStrip, .OilPainting, .Sketch,
        .Brightness, .Gamma, .ColorSpace, .LuminanceAdaptiveContrast,
        .Nostalgic
    ]
    
    let shape: [ViewControllerType] = [
        .Crop, .Rotate, .Resize, .Flip,
        .Transform, .Mirror,
    ]
    
    let blur: [ViewControllerType] = [
        .MonochromeDilation, .MotionBlur, .MeanBlur,
        .GaussianBlur, .BilateralBlur, .MPSGaussian,
        .CircleBlur, .DetailPreservingBlur, .ZoomBlur,
        .SurfaceBlur, .LocalBlur, .TiltShift
    ]
    
    let blend: [ViewControllerType] = [
        .HueBlend, .AlphaBlend, .LuminanceBlend,
        .ColorBlend, .SaturationBlend, .NormalBlend,
        .AddBlend, .ColorBurnBlend, .ColorDodgeBlend,
        .DarkenBlend, .DarkerColorBlend, .DifferenceBlend,
        .DissolveBlend, .DivideBlend, .ExclusionBlend,
        .HardLightBlend, .HardMixBlend, .LightenBlend,
        .LighterColorBlend, .LinearBurnBlend, .LinearLightBlend,
        .MaskBlend, .MultiplyBlend, .OverlayBlend,
        .PinLightBlend, .ScreenBlend, .SoftLightBlend,
        .SourceOverBlend, .SubtractBlend, .VividLightBlend,
        .ColorBurnEnhancedBlend, .BlendChromaKey
    ]
    
    let lookup: [ViewControllerType] = [
        .abao, .ColorCube, .ColorLookup512x512, .LookupTable
    ]
    
    let matrix: [ViewControllerType] = [
        .ColorMatrix4x4, .ColorMatrix4x5, .ColorVector4, .Convolution3x3, .Sharpen3x3,
        .Sepia
    ]
    
    let coreImage: [ViewControllerType] = [
        .CIHS, .CIGaussian, .ColorMonochrome,
    ]
    
    let blit: [ViewControllerType] = [
        .BlitCopyRegion, .BlitGenerateMipmaps, .BlitCrop,
    ]
}
