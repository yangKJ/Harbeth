//
//  HomeViewType+Ext.swift
//  MetalDemo
//
//  Created by Condy on 2022/10/17.
//

import Harbeth

typealias maxminTuple = (current: Float, min: Float, max: Float)?
typealias FilterCallback = (_ value: Float) -> C7FilterProtocol
typealias FilterResult = (filter: C7FilterProtocol, maxminValue: maxminTuple, callback: FilterCallback?)

extension ViewControllerType {
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
                filter.radius = $0
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
            filter.offset = C7RGBAColor(red: 0, green: 0, blue: 1, alpha: 0)
            filter.intensity = 0.3
            return (filter, (0.3, 0.1, 1.0), {
                filter.intensity = $0
                return filter
            })
        case .Convolution3x3:
            let filter = C7Convolution3x3(convolutionType: .custom(Matrix3x3.embossment))
            return (filter, nil, nil)
        case .CIHS:
            var filter = CIHighlight()
            return (filter, (1, 0, 1), {
                filter.value = $0
                return filter
            })
        case .CIGaussian:
            var filter = CIGaussianBlur()
            filter.radius = 10
            return (filter, (10, 0, 30), {
                filter.radius = $0
                return filter
            })
        case .TextHEIC:
            var filter = C7Granularity()
            filter.grain = 0.8
            return (filter, nil, nil)
        case .MPSGaussian:
            var filter = MPSGaussianBlur()
            filter.radius = 10
            return (filter, (10, 0, 30), {
                filter.radius = $0
                return filter
            })
        }
    }
}
