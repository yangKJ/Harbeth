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
            var filters = [
                "🖼️ 基础测试用例": test,
                "🤡 组合效果滤镜": sceneStyle,
                "🎨 艺术风格滤镜": artStyle,
                "🔍 边缘与细节": edgeDetail,
                "🌫️ 模糊效果": blur,
                "🎭 风格化效果": stylization,
                "🌈 颜色调整": color,
                "🔄 几何变换": shape,
                "🔗 混合模式": blend,
                "📊 矩阵处理": matrix,
                "🔧 实用工具": utility,
                "📋 查找滤镜": lookup,
                "🔬 Blit操作": blit,
                "🔌 CoreImage": coreImage,
                "⚡ MPS": mps,
                "🎲 扭曲与变形": distortionWarp,
                "✨ 生成器": generators,
                "🌟 其他效果": otherEffects,
            ].filter { $0.value.count > 0 }
            if viewType == .player {
                filters["😈 动效滤镜"] = [
                    .ShiftGlitch, .SoulOut, .WaterRipple, .Swirl,
                    .SplitScreen, .Fluctuate, .Glitch, .Pinch,
                ]
            }
            return filters
        case .camera:
            #if targetEnvironment(simulator)
            return ["❌ 模拟器不支持，请用真机测试": []]
            #else
            var filters = sceneStyle + color + blur + mps + artStyle +
            edgeDetail + lookup + matrix + blend + utility + stylization +
            otherEffects + distortionWarp
            filters.append(contentsOf: [.Storyboard, .Rotate, .Flip])
            return ["📷 相机特效 - 真机测试": filters]
            #endif
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
        .ComicStrip, .OilPainting, .OilPaintingEnhanced,
        .Sketch, .Crosshatch, .Toon, .Kuwahara,
    ]
    
    // 边缘与细节
    let edgeDetail: [ViewControllerType] = [
        .Sharpen3x3, .Sobel, .Canny, .Luminance,
        .DetailEnhancer, .EdgeAwareSharpen, .ThresholdSketch,
        .EdgeGlow, .Sharpen, .SharpenEnhanced, .StickerOutline,
        .Clarity, .SharpenDetail,
    ]
    
    // 风格化效果
    let stylization: [ViewControllerType] = [
        .ShiftGlitch, .SoulOut, .VoronoiOverlay,
        .Storyboard, .SplitScreen, .ColorCGASpace,
        .Fluctuate, .Glitch, .RGBADilation,
    ]
    
    // 实用工具
    let utility: [ViewControllerType] = [
        .HighlightShadowTint, .Highlights, .Shadows,
        .LuminanceThreshold, .LuminanceRangeReduction, .DepthLuminance,
        .ChromaKey, .ReplaceColor,
    ]
    
    let color: [ViewControllerType] = [
        .Opacity, .Exposure, .Luminance,
        .Hue, .Contrast, .HighlightShadow,
        .Saturation, .WhiteBalance, .Vibrance,
        .Temperature, .HSL, .Curves, .ColorBalanceEnhanced,
        .Warmth, .Clarity, .Granularity, .Levels,
        .ChannelRGBA, .FalseColor, .ColorInvert,
        .Color2Gray, .Color2BGRA, .Color2BRGA,
        .Color2GBRA, .Color2GRBA, .Color2RBGA,
        .Brightness, .Gamma, .ColorSpace, .LuminanceAdaptiveContrast,
        .Nostalgic,
    ]
    
    let shape: [ViewControllerType] = [
        .Crop, .Rotate, .Resize, .Flip,
        .Transform, .Mirror,
    ]
    
    let blur: [ViewControllerType] = [
        .MonochromeDilation, .MotionBlur, .MeanBlur,
        .GaussianBlur, .BilateralBlur, .CircleBlur,
        .DetailPreservingBlur, .ZoomBlur, .SurfaceBlur,
        .LocalBlur, .TiltShift, .RedMonochromeBlur,
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
        .abao, .ColorCube, .ColorLookup512x512, .LookupTable,
    ]
    
    let matrix: [ViewControllerType] = [
        .ColorMatrix4x4, .ColorMatrix4x5, .ColorVector4,
        .Convolution3x3, .Sharpen3x3, .Sepia,
    ]
    
    let coreImage: [ViewControllerType] = [
        .CIHS, .CIGaussianCase, .CIVignetteCase,
        .CIColorMonochromeCase,
    ]
    
    // MPS测试用例
    let mps: [ViewControllerType] = [
        .MPSBoxBlurCase, .MPSMedianBlurCase, .MPSGaussianBlurCase,
    ]
    
    let blit: [ViewControllerType] = [
        .BlitCopyRegion, .BlitGenerateMipmaps, .BlitCrop,
    ]
    
    // 扭曲与变形
    let distortionWarp: [ViewControllerType] = [
        .Bulge, .ColorPacking, .GlassSphere, .Halftone,
        .Morphology, .Pinch, .Pixellated,
        .PolarPixellate, .PolkaDot, .SphereRefraction,
        .Swirl, .WaterRipple,
    ]
    
    // 生成器
    let generators: [ViewControllerType] = [
        .ColorGradient, .SolidColor,
    ]
    
    // 其他效果
    let otherEffects: [ViewControllerType] = [
        .Fade, .Grayed, .Haze, .Pow,
        .Vignette, .VignetteNormal, .VignetteMultiply,
        .VignetteOverlay, .VignetteSoftLight,
    ]
}
