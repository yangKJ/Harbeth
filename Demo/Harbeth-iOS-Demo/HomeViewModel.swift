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

struct HomeSection {
    let title: String
    let items: [ViewControllerType]
}

struct HomeViewModel {
    var viewType: ViewType
    
    func setupViewController(_ type: ViewControllerType) -> UIViewController {
        if type == .PageCurlShowcase {
            return PageCurlShowcaseViewController()
        }
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
    
    lazy var sections: [HomeSection] = {
        switch viewType {
        case .image, .player:
            let showcaseItems = viewType == .image ? showcase : showcase.filter { $0 != .PageCurlShowcase }
            var filters: [HomeSection] = [
                HomeSection(title: "🚀 能力展示", items: showcaseItems),
                HomeSection(title: "🎞️ 帧处理与输出", items: frameProcessing),
                HomeSection(title: "🌈 色彩与色调", items: color),
                HomeSection(title: "🌫️ 模糊与降噪", items: blur),
                HomeSection(title: "🔍 边缘与细节", items: edgeDetail),
                HomeSection(title: "📐 几何与光学", items: geometryOptics),
                HomeSection(title: "🎭 风格化与创意效果", items: stylization),
                HomeSection(title: "🎨 艺术风格", items: artStyle),
                HomeSection(title: "🎲 扭曲与形变", items: distortionWarp),
                HomeSection(title: "🔗 混合与合成", items: blend),
                HomeSection(title: "📋 LUT 与色彩映射", items: lookup),
                HomeSection(title: "📊 矩阵与基础算子", items: matrix),
                HomeSection(title: "🔧 实用工具", items: utility),
                HomeSection(title: "✨ 生成与拷贝", items: generators + blit),
                HomeSection(title: "⚡ Metal Performance Shaders", items: mps),
                HomeSection(title: "🧪 基础验证", items: test),
                HomeSection(title: "🌟 其他效果", items: otherEffects),
            ].filter { !$0.items.isEmpty }
            if viewType == .player {
                filters.insert(HomeSection(title: "🎬 时序动效", items: [
                    .ShiftGlitch, .SoulOut, .WaterRipple, .Swirl,
                    .SplitScreen, .Fluctuate, .Glitch, .Pinch,
                ]), at: 1)
            }
            return filters
        case .camera:
            #if targetEnvironment(simulator)
            return [HomeSection(title: "❌ 模拟器不支持，请用真机测试", items: [])]
            #else
            var filters = sceneStyle + color + blur + mps + artStyle +
            edgeDetail + geometryOptics + lookup + matrix + blend + utility + stylization +
            otherEffects + distortionWarp
            filters.append(contentsOf: [.Storyboard, .Rotate, .Flip])
            return [HomeSection(title: "📷 实时帧处理 - 真机能力展示", items: filters)]
            #endif
        }
    }()
    
    let test: [ViewControllerType] = [
        .TextHEIC,
    ]

    let showcase: [ViewControllerType] = [
        .PageCurlShowcase,
        .CombinationCinematic, .CombinationColorGrading, .CombinationHDRBoost,
        .ColorCube, .NoiseReduction, .UnsharpMask,
        .LensDistortionCorrection, .ChromaticAberrationCorrection,
    ]

    let frameProcessing: [ViewControllerType] = [
        .NoiseReduction, .UnsharpMask, .LanczosResize,
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
        .Clarity, .SharpenDetail, .UnsharpMask,
        .DiffractionCorrection, .SharpnessFalloffCorrection,
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

    let geometryOptics: [ViewControllerType] = [
        .Crop, .Rotate, .Resize, .LanczosResize,
        .Flip, .Transform, .Mirror,
        .LensDistortionCorrection, .ChromaticAberrationCorrection,
        .LensVignetteCorrection, .DefringeCorrection,
        .DiffractionCorrection, .SharpnessFalloffCorrection,
    ]

    let blur: [ViewControllerType] = [
        .MonochromeDilation, .MotionBlur, .MeanBlur,
        .GaussianBlur, .BilateralBlur, .CircleBlur,
        .DetailPreservingBlur, .ZoomBlur, .SurfaceBlur,
        .LocalBlur, .TiltShift, .RedMonochromeBlur,
        .NoiseReduction,
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
