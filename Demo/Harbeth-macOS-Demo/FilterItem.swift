import Foundation
import Harbeth

struct FilterItem {
    let name: String
    let filter: C7FilterProtocol
    let hasSlider: Bool
    let sliderRange: (min: Float, max: Float, current: Float)?
    let callback: ((Float) -> C7FilterProtocol)?
}

class FilterGroup {
    let name: String
    var items: [FilterItem]
    
    init(name: String, items: [FilterItem]) {
        self.name = name
        self.items = items
    }
    
    static let datas = [
        FilterGroup(name: "🎨 Combination Filters", items: [
            FilterItem(name: "Cinematic", filter: C7CombinationCinematic(intensity: 0.8), hasSlider: true, sliderRange: (0.1, 1.0, 0.8), callback: { value in
                let filter = C7CombinationCinematic(intensity: value)
                return filter
            }),
            FilterItem(name: "Modern HDR", filter: C7CombinationModernHDR(intensity: 0.8), hasSlider: true, sliderRange: (0.1, 1.0, 0.8), callback: { value in
                let filter = C7CombinationModernHDR(intensity: value)
                return filter
            }),
            FilterItem(name: "Vintage", filter: C7CombinationVintage(intensity: 0.8), hasSlider: true, sliderRange: (0.1, 1.0, 0.8), callback: { value in
                let filter = C7CombinationVintage(intensity: value)
                return filter
            }),
            FilterItem(name: "Cyberpunk", filter: C7CombinationCyberpunk(intensity: 0.8), hasSlider: true, sliderRange: (0.1, 1.0, 0.8), callback: { value in
                let filter = C7CombinationCyberpunk(intensity: value)
                return filter
            }),
            FilterItem(name: "Dreamy", filter: C7CombinationDreamy(intensity: 0.8), hasSlider: true, sliderRange: (0.1, 1.0, 0.8), callback: { value in
                let filter = C7CombinationDreamy(intensity: value)
                return filter
            }),
            FilterItem(name: "Vintage Film", filter: C7CombinationVintageFilm(intensity: 0.8), hasSlider: true, sliderRange: (0.1, 1.0, 0.8), callback: { value in
                let filter = C7CombinationVintageFilm(intensity: value)
                return filter
            }),
            FilterItem(name: "Color Grading", filter: C7CombinationColorGrading(intensity: 0.8), hasSlider: true, sliderRange: (0.1, 1.0, 0.8), callback: { value in
                let filter = C7CombinationColorGrading(intensity: value)
                return filter
            }),
            FilterItem(name: "Creative Atmosphere", filter: C7CombinationCreativeAtmosphere(intensity: 0.8), hasSlider: true, sliderRange: (0.1, 1.0, 0.8), callback: { value in
                let filter = C7CombinationCreativeAtmosphere(intensity: value)
                return filter
            }),
            FilterItem(name: "Film Simulation", filter: C7CombinationFilmSimulation(intensity: 0.8), hasSlider: true, sliderRange: (0.1, 1.0, 0.8), callback: { value in
                let filter = C7CombinationFilmSimulation(intensity: value)
                return filter
            }),
            FilterItem(name: "HDR Boost", filter: C7CombinationHDRBoost(intensity: 0.8), hasSlider: true, sliderRange: (0.1, 1.0, 0.8), callback: { value in
                let filter = C7CombinationHDRBoost(intensity: value)
                return filter
            }),
            FilterItem(name: "Beautiful", filter: C7CombinationBeautiful(intensity: 0.8), hasSlider: true, sliderRange: (0.1, 1.0, 0.8), callback: { value in
                let filter = C7CombinationBeautiful(intensity: value)
                return filter
            }),
        ]),
        
        FilterGroup(name: "🎨 Color Adjustment", items: [
            FilterItem(name: "Brightness", filter: C7Brightness(brightness: 0.25), hasSlider: true, sliderRange: (-1, 1, 0.25), callback: { value in
                var filter = C7Brightness()
                filter.brightness = value
                return filter
            }),
            FilterItem(name: "Contrast", filter: C7Contrast(contrast: 1.5), hasSlider: true, sliderRange: (0, 4, 1.5), callback: { value in
                var filter = C7Contrast()
                filter.contrast = value
                return filter
            }),
            FilterItem(name: "Saturation", filter: C7Saturation(saturation: 1.2), hasSlider: true, sliderRange: (0, 2, 1.2), callback: { value in
                var filter = C7Saturation()
                filter.saturation = value
                return filter
            }),
            FilterItem(name: "Hue", filter: C7Hue(hue: 45), hasSlider: true, sliderRange: (0, 180, 45), callback: { value in
                var filter = C7Hue()
                filter.hue = value
                return filter
            }),
            FilterItem(name: "Gamma", filter: C7Gamma(gamma: 1.5), hasSlider: true, sliderRange: (0.1, 3, 1.5), callback: { value in
                var filter = C7Gamma()
                filter.gamma = value
                return filter
            }),
            FilterItem(name: "Exposure", filter: C7Exposure(exposure: 0.5), hasSlider: true, sliderRange: (-2, 2, 0.5), callback: { value in
                var filter = C7Exposure()
                filter.exposure = value
                return filter
            }),
            FilterItem(name: "Vibrance", filter: C7Vibrance(vibrance: 0.6), hasSlider: true, sliderRange: (-1.2, 1.2, 0.6), callback: { value in
                var filter = C7Vibrance()
                filter.vibrance = value
                return filter
            }),
            FilterItem(name: "Color Correction", filter: C7ColorCorrection(levels: 0.5), hasSlider: true, sliderRange: (-1, 1, 0.5), callback: { value in
                var filter = C7ColorCorrection()
                filter.levels = value
                return filter
            }),
            FilterItem(name: "Nostalgic", filter: C7Nostalgic(intensity: 0.6), hasSlider: true, sliderRange: (0, 1, 0.6), callback: { value in
                var filter = C7Nostalgic()
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Opacity", filter: C7Opacity(opacity: 0.8), hasSlider: true, sliderRange: (0, 1, 0.8), callback: { value in
                var filter = C7Opacity()
                filter.opacity = value
                return filter
            }),
            FilterItem(name: "Luminance", filter: C7Luminance(luminance: 0.6), hasSlider: true, sliderRange: (0, 1, 0.6), callback: { value in
                var filter = C7Luminance()
                filter.luminance = value
                return filter
            }),
            FilterItem(name: "Highlight Shadow", filter: C7HighlightShadow(highlights: 0.5, shadows: 0.5), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7HighlightShadow()
                filter.highlights = value
                filter.shadows = value
                return filter
            }),
            FilterItem(name: "White Balance", filter: C7WhiteBalance(temperature: 4444), hasSlider: true, sliderRange: (4000, 7000, 4444), callback: { value in
                var filter = C7WhiteBalance()
                filter.temperature = value
                return filter
            }),
            FilterItem(name: "Temperature", filter: C7Temperature(), hasSlider: true, sliderRange: (-1.0, 1.0, 0.0), callback: { value in
                var filter = C7Temperature()
                filter.temperature = value
                filter.tint = value
                filter.colorShift = value
                return filter
            }),
            FilterItem(name: "HSL", filter: C7HSL(), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7HSL()
                filter.hue = value
                filter.saturation = value
                filter.lightness = value
                return filter
            }),
            FilterItem(name: "Curves", filter: C7Curves(rgbPoints: [
                C7Point2D(x: 0.0, y: 0.0),
                C7Point2D(x: 0.2, y: 0.8),
                C7Point2D(x: 0.6, y: 0.4),
                C7Point2D(x: 0.8, y: 0.6),
                C7Point2D(x: 1.0, y: 1.0)
            ]), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Color Balance Enhanced", filter: C7ColorBalanceEnhanced(), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7ColorBalanceEnhanced()
                filter.strength = value
                return filter
            }),
            FilterItem(name: "Warmth", filter: C7Warmth(), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Warmth()
                filter.warmth = value
                return filter
            }),
            FilterItem(name: "Granularity", filter: C7Granularity(grain: 0.3), hasSlider: true, sliderRange: (0, 0.5, 0.3), callback: { value in
                return C7Granularity(grain: value)
            }),
            FilterItem(name: "Levels", filter: C7Levels(minimum: C7Color(hex: "#5C48FA")), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Channel RGBA", filter: C7ColorRGBA(color: C7Color(hex: "#5C48FA")), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7ColorRGBA(color: C7Color(hex: "#5C48FA"))
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "False Color", filter: C7FalseColor(fristColor: C7Color.black, secondColor: C7Color(hex: "#5C48FA")), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Color Invert", filter: C7ColorConvert(with: .invert), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Color2BGRA", filter: C7ColorConvert(with: .bgra), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Color2BRGA", filter: C7ColorConvert(with: .brga), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Color2GBRA", filter: C7ColorConvert(with: .gbra), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Color2GRBA", filter: C7ColorConvert(with: .grba), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Color2RBGA", filter: C7ColorConvert(with: .rbga), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Color Space", filter: C7ColorSpace(with: .rgb_to_yiq), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Luminance Adaptive Contrast", filter: C7LuminanceAdaptiveContrast(amount: 2), hasSlider: true, sliderRange: (0, 2, 2), callback: { value in
                var filter = C7LuminanceAdaptiveContrast(amount: value)
                return filter
            }),
            FilterItem(name: "Apple Log Decode", filter: C7AppleLogDecode(), hasSlider: false, sliderRange: nil, callback: nil),
        ]),
        
        FilterGroup(name: "🌫️ Blur Effects", items: [
            FilterItem(name: "Gaussian Blur", filter: C7GaussianBlur(radius: 2.0), hasSlider: true, sliderRange: (0, 10, 2.0), callback: { value in
                var filter = C7GaussianBlur()
                filter.radius = value
                return filter
            }),
            FilterItem(name: "Mean Blur", filter: C7MeanBlur(radius: 0.5), hasSlider: true, sliderRange: (0, 5, 0.5), callback: { value in
                var filter = C7MeanBlur()
                filter.radius = value
                return filter
            }),
            FilterItem(name: "Bilateral Blur", filter: C7BilateralBlur(radius: 0.5), hasSlider: true, sliderRange: (0, 5, 0.5), callback: { value in
                var filter = C7BilateralBlur()
                filter.radius = value
                return filter
            }),
            FilterItem(name: "Motion Blur", filter: C7MotionBlur(radius: 5, blurAngle: 45), hasSlider: true, sliderRange: (1, 10, 5), callback: { value in
                var filter = C7MotionBlur()
                filter.radius = value
                filter.blurAngle = 45
                return filter
            }),
            FilterItem(name: "Zoom Blur", filter: C7ZoomBlur(radius: 10), hasSlider: true, sliderRange: (5, 15, 10), callback: { value in
                var filter = C7ZoomBlur()
                filter.radius = value
                return filter
            }),
            FilterItem(name: "Tilt Shift", filter: C7TiltShift(blurRadius: 2), hasSlider: true, sliderRange: (0, 10, 2), callback: { value in
                var filter = C7TiltShift()
                filter.blurRadius = value
                return filter
            }),
            FilterItem(name: "Red Monochrome Blur", filter: C7RedMonochromeBlur(pixelRadius: 1), hasSlider: true, sliderRange: (0, 10, 1), callback: { value in
                var filter = C7RedMonochromeBlur()
                filter.pixelRadius = Int(value)
                return filter
            }),
            FilterItem(name: "Monochrome Dilation", filter: C7RedMonochromeBlur(pixelRadius: 1), hasSlider: true, sliderRange: (0, 10, 1), callback: { value in
                var filter = C7RedMonochromeBlur()
                filter.pixelRadius = Int(value)
                return filter
            }),
            FilterItem(name: "Circle Blur", filter: C7CircleBlur(radius: 10), hasSlider: true, sliderRange: (1, 20, 10), callback: { value in
                var filter = C7CircleBlur()
                filter.radius = value
                return filter
            }),
            FilterItem(name: "Detail Preserving Blur", filter: C7DetailPreservingBlur(strength: 2), hasSlider: true, sliderRange: (0, 10, 2), callback: { value in
                var filter = C7DetailPreservingBlur(strength: value)
                return filter
            }),
            FilterItem(name: "Surface Blur", filter: C7SurfaceBlur(radius: 8.0, threshold: 0.1), hasSlider: true, sliderRange: (1.0, 20.0, 8.0), callback: { value in
                var filter = C7SurfaceBlur()
                filter.radius = value
                filter.threshold = 0.1
                return filter
            }),
            FilterItem(name: "Local Blur", filter: C7LocalBlur(radius: 5), hasSlider: true, sliderRange: (1, 20, 5), callback: { value in
                var filter = C7LocalBlur()
                filter.radius = value
                return filter
            }),
        ]),
        
        FilterGroup(name: "🎭 Stylization", items: [
            FilterItem(name: "Oil Painting", filter: C7OilPainting(radius: 4, pixel: 1), hasSlider: true, sliderRange: (1, 10, 4), callback: { value in
                return C7OilPainting(radius: value, pixel: 1)
            }),
            FilterItem(name: "Toon", filter: C7Toon(threshold: 0.5), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Toon()
                filter.threshold = value
                return filter
            }),
            FilterItem(name: "Comic Strip", filter: C7ComicStrip(), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Kuwahara", filter: C7Kuwahara(radius: 3), hasSlider: true, sliderRange: (1, 10, 3), callback: { value in
                return C7Kuwahara(radius: Int(value))
            }),
            FilterItem(name: "Soul Out", filter: C7SoulOut(soul: 0.7, maxScale: 1.5), hasSlider: true, sliderRange: (0.1, 0.8, 0.7), callback: { value in
                return C7SoulOut(soul: value, maxScale: 1.5)
            }),
            FilterItem(name: "Granularity", filter: C7Granularity(grain: 0.3), hasSlider: true, sliderRange: (0, 0.5, 0.3), callback: { value in
                return C7Granularity(grain: value)
            }),
            FilterItem(name: "Fluctuate", filter: C7Fluctuate(fluctuate: 0.5), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                return C7Fluctuate(fluctuate: value)
            }),
            FilterItem(name: "Shift Glitch", filter: C7ShiftGlitch(), hasSlider: true, sliderRange: (0.1, 0.5, 0.5), callback: { value in
                var filter = C7ShiftGlitch()
                filter.time = value
                return filter
            }),
            FilterItem(name: "Voronoi Overlay", filter: C7VoronoiOverlay(), hasSlider: true, sliderRange: (0.1, 0.6, 0.5), callback: { value in
                var filter = C7VoronoiOverlay()
                filter.time = value
                return filter
            }),
            FilterItem(name: "Split Screen", filter: C7SplitScreen(), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Color CGA Space", filter: C7ColorCGASpace(), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Glitch", filter: C7Glitch(glitch: 0.5), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Glitch()
                filter.glitch = value
                return filter
            }),
            FilterItem(name: "RGBADilation", filter: C7RGBADilation(), hasSlider: false, sliderRange: nil, callback: nil),
        ]),
        
        FilterGroup(name: "🔄 Transform", items: [
            FilterItem(name: "Rotate", filter: C7Rotate(angle: 30), hasSlider: true, sliderRange: (0, 360, 30), callback: { value in
                var filter = C7Rotate()
                filter.angle = value
                return filter
            }),
            FilterItem(name: "Flip", filter: C7Flip(vertical: true), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Resize", filter: C7Resize(width: 1000, height: 0), hasSlider: true, sliderRange: (50, 2000, 1000), callback: { value in
                return C7Resize(width: value, height: 0)
            }),
            FilterItem(name: "Pixellated", filter: C7Pixellated(scale: 20), hasSlider: true, sliderRange: (5, 50, 20), callback: { value in
                var filter = C7Pixellated()
                filter.scale = value
                return filter
            }),
            FilterItem(name: "Crop", filter: C7Crop(origin: C7Point2D(x: 0.3, y: 0.3), width: 0, height: 1080), hasSlider: true, sliderRange: (0, 1, 0.3), callback: { value in
                var filter = C7Crop(origin: C7Point2D(x: value, y: value), width: 0, height: 1080)
                return filter
            }),
            FilterItem(name: "Transform", filter: C7Transform(transform: CGAffineTransform(scaleX: 0.8, y: 1).rotated(by: .pi / 6)), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Mirror", filter: C7Mirror(), hasSlider: false, sliderRange: nil, callback: nil),
        ]),
        
        FilterGroup(name: "✨ Edge & Detail", items: [
            FilterItem(name: "Sobel Edge", filter: C7Sobel(edgeStrength: 1), hasSlider: true, sliderRange: (0, 5, 1), callback: { value in
                var filter = C7Sobel()
                filter.edgeStrength = value
                return filter
            }),
            FilterItem(name: "Sharpen", filter: C7Sharpen(sharpeness: 1), hasSlider: true, sliderRange: (-4, 4, 1), callback: { value in
                return C7Sharpen(sharpeness: value)
            }),
            FilterItem(name: "Clarity", filter: C7Clarity(intensity: 0.5), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Clarity()
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Sharpen Detail", filter: C7SharpenDetail(sharpen: 0.5), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7SharpenDetail()
                filter.sharpen = value
                return filter
            }),
            FilterItem(name: "Sharpen 3x3", filter: C7ConvolutionMatrix3x3(convolutionType: .sharpen(iterations: 1)), hasSlider: true, sliderRange: (0, 7, 1), callback: { value in
                return C7ConvolutionMatrix3x3(convolutionType: .sharpen(iterations: value))
            }),
            FilterItem(name: "Canny", filter: C7Canny(), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Canny()
                filter.threshold1 = value
                filter.threshold2 = value
                return filter
            }),
            FilterItem(name: "Luminance", filter: C7Luminance(), hasSlider: true, sliderRange: (0, 1, 0.6), callback: { value in
                var filter = C7Luminance()
                filter.luminance = value
                return filter
            }),
            FilterItem(name: "Detail Enhancer", filter: C7DetailEnhancer(amount: 2), hasSlider: true, sliderRange: (0, 2, 2), callback: { value in
                var filter = C7DetailEnhancer()
                filter.amount = value
                return filter
            }),
            FilterItem(name: "Edge Aware Sharpen", filter: C7EdgeAwareSharpen(amount: 2), hasSlider: true, sliderRange: (0, 2, 2), callback: { value in
                var filter = C7EdgeAwareSharpen(amount: value)
                return filter
            }),
            FilterItem(name: "Threshold Sketch", filter: C7ThresholdSketch(threshold: 0.5), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7ThresholdSketch()
                filter.threshold = value
                return filter
            }),
            FilterItem(name: "Edge Glow", filter: C7EdgeGlow(), hasSlider: true, sliderRange: (0.1, 0.6, 0.5), callback: { value in
                var filter = C7EdgeGlow()
                filter.time = value
                return filter
            }),
            FilterItem(name: "Sharpen Enhanced", filter: C7SharpenEnhanced(), hasSlider: true, sliderRange: (0, 5, 0.5), callback: { value in
                var filter = C7SharpenEnhanced()
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Sticker Outline", filter: C7StickerOutline(outlineColor: C7Color(hex: "#5C48FA"), outlineThickness: 0.015, outlineBlur: 0.2), hasSlider: true, sliderRange: (0, 1, 0.2), callback: { value in
                var filter = C7StickerOutline(outlineColor: C7Color(hex: "#5C48FA"), outlineThickness: 0.015, outlineBlur: value)
                return filter
            }),
        ]),
        
        FilterGroup(name: "🔧 Other Effects", items: [
            FilterItem(name: "Storyboard", filter: C7Storyboard(ranks: 2), hasSlider: true, sliderRange: (1, 10, 2), callback: { value in
                var filter = C7Storyboard()
                filter.ranks = Int(ceil(value))
                return filter
            }),
            FilterItem(name: "Vignette", filter: C7Vignette(color: C7Color(hex: "#5C48FA")), hasSlider: true, sliderRange: (0.1, 0.75, 0.3), callback: { value in
                var filter = C7Vignette(color: C7Color(hex: "#5C48FA"))
                filter.start = value
                return filter
            }),
            FilterItem(name: "Color Invert", filter: C7ColorConvert(with: .invert), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Grayscale", filter: C7ColorConvert(with: .gray), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Monochrome", filter: C7Monochrome(intensity: 1.0), hasSlider: true, sliderRange: (0, 1, 1.0), callback: { value in
                return C7Monochrome(intensity: value)
            }),
            FilterItem(name: "Fade", filter: C7Fade(), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Fade()
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Grayed", filter: C7Grayed(with: .desaturation), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Haze", filter: C7Haze(distance: 0.05), hasSlider: true, sliderRange: (0, 0.5, 0.05), callback: { value in
                var filter = C7Haze()
                filter.distance = value
                return filter
            }),
            FilterItem(name: "Pow", filter: C7Pow(value: 0.2), hasSlider: true, sliderRange: (0, 1, 0.2), callback: { value in
                var filter = C7Pow()
                filter.value = value
                return filter
            }),
            FilterItem(name: "Vignette Normal", filter: C7VignetteBlend(start: 0.3, color: C7Color(hex: "#5C48FA"), blendMode: .normal), hasSlider: true, sliderRange: (0.1, 0.75, 0.3), callback: { value in
                let filter = C7VignetteBlend(start: value, color: C7Color(hex: "#5C48FA"), blendMode: .normal)
                return filter
            }),
            FilterItem(name: "Vignette Multiply", filter: C7VignetteBlend(start: 0.3, color: C7Color(hex: "#5C48FA"), blendMode: .multiply), hasSlider: true, sliderRange: (0.1, 0.75, 0.3), callback: { value in
                let filter = C7VignetteBlend(start: value, color: C7Color(hex: "#5C48FA"), blendMode: .multiply)
                return filter
            }),
            FilterItem(name: "Vignette Overlay", filter: C7VignetteBlend(start: 0.3, color: C7Color(hex: "#5C48FA"), blendMode: .overlay), hasSlider: true, sliderRange: (0.1, 0.75, 0.3), callback: { value in
                let filter = C7VignetteBlend(start: value, color: C7Color(hex: "#5C48FA"), blendMode: .overlay)
                return filter
            }),
            FilterItem(name: "Vignette Soft Light", filter: C7VignetteBlend(start: 0.3, color: C7Color(hex: "#5C48FA"), blendMode: .softLight), hasSlider: true, sliderRange: (0.1, 0.75, 0.3), callback: { value in
                let filter = C7VignetteBlend(start: value, color: C7Color(hex: "#5C48FA"), blendMode: .softLight)
                return filter
            }),
        ]),
        
        FilterGroup(name: "🎨 Art Style", items: [
            FilterItem(name: "Comic Strip", filter: C7ComicStrip(), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Oil Painting", filter: C7OilPainting(), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Oil Painting Enhanced", filter: C7OilPaintingEnhanced(intensity: 0.5), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7OilPaintingEnhanced()
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Sketch", filter: C7Sketch(edgeStrength: 0.3), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Crosshatch", filter: C7Crosshatch(crosshatchSpacing: 0.03), hasSlider: true, sliderRange: (0.01, 0.08, 0.03), callback: { value in
                var filter = C7Crosshatch()
                filter.crosshatchSpacing = value
                return filter
            }),
            FilterItem(name: "Toon", filter: C7Toon(threshold: 0.5), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Toon()
                filter.threshold = value
                return filter
            }),
            FilterItem(name: "Kuwahara", filter: C7Kuwahara(radius: 3), hasSlider: true, sliderRange: (1, 10, 3), callback: { value in
                return C7Kuwahara(radius: Int(value))
            }),
        ]),
        
        FilterGroup(name: "🔗 Blend Modes", items: [
            FilterItem(name: "Hue Blend", filter: C7Blend(with: .hue, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .hue, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Alpha Blend", filter: C7Blend(with: .alpha, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .alpha, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Luminance Blend", filter: C7Blend(with: .luminosity, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .luminosity, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Color Blend", filter: C7Blend(with: .color, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .color, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Saturation Blend", filter: C7Blend(with: .saturation, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .saturation, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Normal Blend", filter: C7Blend(with: .normal, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .normal, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Add Blend", filter: C7Blend(with: .add, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .add, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Color Burn Blend", filter: C7Blend(with: .colorBurn, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .colorBurn, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Color Dodge Blend", filter: C7Blend(with: .colorDodge, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .colorDodge, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Darken Blend", filter: C7Blend(with: .darken, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .darken, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Darker Color Blend", filter: C7Blend(with: .darkerColor, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .darkerColor, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Difference Blend", filter: C7Blend(with: .difference, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .difference, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Dissolve Blend", filter: C7Blend(with: .dissolve, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .dissolve, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Divide Blend", filter: C7Blend(with: .divide, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .divide, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Exclusion Blend", filter: C7Blend(with: .exclusion, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .exclusion, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Hard Light Blend", filter: C7Blend(with: .hardLight, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .hardLight, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Hard Mix Blend", filter: C7Blend(with: .hardMix, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .hardMix, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Lighten Blend", filter: C7Blend(with: .lighten, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .lighten, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Lighter Color Blend", filter: C7Blend(with: .lighterColor, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .lighterColor, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Linear Burn Blend", filter: C7Blend(with: .linearBurn, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .linearBurn, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Linear Light Blend", filter: C7Blend(with: .linearLight, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .linearLight, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Mask Blend", filter: C7Blend(with: .mask, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .mask, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Multiply Blend", filter: C7Blend(with: .multiply, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .multiply, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Overlay Blend", filter: C7Blend(with: .overlay, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .overlay, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Pin Light Blend", filter: C7Blend(with: .pinLight, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .pinLight, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Screen Blend", filter: C7Blend(with: .screen, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .screen, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Soft Light Blend", filter: C7Blend(with: .softLight, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .softLight, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Source Over Blend", filter: C7Blend(with: .sourceOver, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .sourceOver, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Subtract Blend", filter: C7Blend(with: .subtract, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .subtract, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Vivid Light Blend", filter: C7Blend(with: .vividLight, blendTexture: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7Blend(with: .vividLight, blendTexture: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Color Burn Enhanced Blend", filter: C7ColorBurnEnhancedBlend(with: nil), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7ColorBurnEnhancedBlend(with: nil)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Blend Chroma Key", filter: C7BlendChromaKey(), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7BlendChromaKey()
                filter.intensity = value
                return filter
            }),
        ]),
        
        FilterGroup(name: "📊 Matrix", items: [
            FilterItem(name: "Color Matrix 4x4", filter: C7ColorMatrix4x4(matrix: Matrix4x4.Color.replaced_red_green), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7ColorMatrix4x4(matrix: Matrix4x4.Color.replaced_red_green)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Color Matrix 4x5", filter: C7ColorMatrix4x5(matrix: Matrix4x5(values: [
                1, 0, 0, 0, 0,
                0, 1, 0, 0, 0,
                0, 0, 1, 0, 0,
                0, 0, 0, 1, 0
            ])), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7ColorMatrix4x5(matrix: Matrix4x5(values: [
                    1, 0, 0, 0, 0,
                    0, 1, 0, 0, 0,
                    0, 0, 1, 0, 0,
                    0, 0, 0, 1, 0
                ]))
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Color Vector 4", filter: C7ColorVector4(vector: Vector4.Color.sunset), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Convolution 3x3", filter: C7ConvolutionMatrix3x3(convolutionType: .embossment), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7ConvolutionMatrix3x3(convolutionType: .embossment)
                filter.intensity = value
                return filter
            }),
            FilterItem(name: "Sharpen 3x3", filter: C7ConvolutionMatrix3x3(convolutionType: .sharpen(iterations: 1)), hasSlider: true, sliderRange: (0, 7, 1), callback: { value in
                return C7ConvolutionMatrix3x3(convolutionType: .sharpen(iterations: value))
            }),
            FilterItem(name: "Sepia", filter: C7Sepia(), hasSlider: false, sliderRange: nil, callback: nil),
        ]),
        
        FilterGroup(name: "🔧 Utility", items: [
            FilterItem(name: "Highlight Shadow Tint", filter: C7HighlightShadowTint(highlights: 0.5, shadows: 0.5), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7HighlightShadowTint()
                filter.highlights = value
                filter.shadows = value
                return filter
            }),
            FilterItem(name: "Highlights", filter: C7Highlights(highlight: 0.5), hasSlider: true, sliderRange: (-1, 1, 0.5), callback: { value in
                var filter = C7Highlights()
                filter.highlight = value
                return filter
            }),
            FilterItem(name: "Shadows", filter: C7Shadows(shadow: 0.5), hasSlider: true, sliderRange: (-1, 1, 0.5), callback: { value in
                var filter = C7Shadows()
                filter.shadow = value
                return filter
            }),
            FilterItem(name: "Luminance Threshold", filter: C7LuminanceThreshold(threshold: 0.5), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7LuminanceThreshold()
                filter.threshold = value
                return filter
            }),
            FilterItem(name: "Luminance Range Reduction", filter: C7LuminanceRangeReduction(), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Depth Luminance", filter: C7DepthLuminance(), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = C7DepthLuminance()
                filter.depthRange = value
                return filter
            }),
            FilterItem(name: "Chroma Key", filter: C7ChromaKey(smoothing: 0.05, chroma: C7Color(hex: "#5C48FA")), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Replace Color", filter: C7ChromaKey(smoothing: 0.1, chroma: C7Color.red, replace: C7Color(hex: "#5C48FA")), hasSlider: false, sliderRange: nil, callback: nil),
        ]),
        
        FilterGroup(name: "📋 Lookup", items: [
            FilterItem(name: "Abao", filter: C7LookupTable(name: "lut_abao"), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                return C7LookupTable(name: "lut_abao", intensity: value)
            }),
            FilterItem(name: "Color Cube", filter: C7ColorCube(cubeName: "violet"), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                return C7ColorCube(cubeName: "violet", intensity: value)
            }),
            FilterItem(name: "Color Lookup 512x512", filter: C7ColorLookup512x512(name: "lut"), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                return C7ColorLookup512x512(name: "lut", intensity: value)
            }),
            FilterItem(name: "Lookup Table", filter: C7LookupTable(name: "lut"), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                return C7LookupTable(name: "lut", intensity: value)
            }),
        ]),
        
        FilterGroup(name: "🔬 Blit", items: [
            FilterItem(name: "Blit Copy Region", filter: C7CopyRegionBlit(destOrigin: MTLOrigin(x: 0, y: 0, z: 0)), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Blit Generate Mipmaps", filter: C7GenerateMipmapsBlit(), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Blit Crop", filter: C7CropBlit(rect: CGRect(x: 200, y: 500, width: 200, height: 200)), hasSlider: false, sliderRange: nil, callback: nil),
        ]),
        
        FilterGroup(name: "🔌 CoreImage", items: [
            FilterItem(name: "CI Highlight Shadow", filter: CIHighlight(highlight: 0.5), hasSlider: true, sliderRange: (0, 1, 0.5), callback: { value in
                var filter = CIHighlight()
                filter.highlight = value
                return filter
            }),
            FilterItem(name: "CI Gaussian Blur", filter: CIGaussianBlur(radius: 2), hasSlider: true, sliderRange: (0, 10, 2), callback: { value in
                var filter = CIGaussianBlur()
                filter.radius = value
                return filter
            }),
            FilterItem(name: "CI Vignette", filter: CIVignette(vignette: 0.3), hasSlider: true, sliderRange: (0, 2, 0.3), callback: { value in
                var filter = CIVignette()
                filter.vignette = value
                return filter
            }),
            FilterItem(name: "CI Color Monochrome", filter: CIColorMonochrome(), hasSlider: true, sliderRange: (0, 1, 1), callback: { value in
                var filter = CIColorMonochrome()
                filter.intensity = value
                return filter
            }),
        ]),
        
        FilterGroup(name: "⚡ MPS", items: [
            FilterItem(name: "MPS Box Blur", filter: MPSBoxBlur(radius: 5), hasSlider: true, sliderRange: (1, 20, 5), callback: { value in
                var filter = MPSBoxBlur()
                filter.radius = value
                return filter
            }),
            FilterItem(name: "MPS Median Blur", filter: MPSMedian(radius: 3), hasSlider: true, sliderRange: (1, 25, 3), callback: { value in
                var filter = MPSMedian()
                filter.radius = value
                return filter
            }),
            FilterItem(name: "MPS Gaussian Blur", filter: MPSGaussianBlur(radius: 2), hasSlider: true, sliderRange: (0, 10, 2), callback: { value in
                var filter = MPSGaussianBlur()
                filter.radius = value
                return filter
            }),
        ]),
        
        FilterGroup(name: "🎲 Distortion & Warp", items: [
            FilterItem(name: "Bulge", filter: C7Bulge(scale: 0.2), hasSlider: true, sliderRange: (-0.5, 0.5, 0.2), callback: { value in
                var filter = C7Bulge()
                filter.scale = value
                return filter
            }),
            FilterItem(name: "Pinch", filter: C7Pinch(radius: 0.25), hasSlider: true, sliderRange: (0, 0.5, 0.25), callback: { value in
                var filter = C7Pinch()
                filter.radius = value
                return filter
            }),
            FilterItem(name: "Swirl", filter: C7Swirl(radius: 0.25), hasSlider: true, sliderRange: (0, 0.5, 0.25), callback: { value in
                var filter = C7Swirl()
                filter.radius = value
                return filter
            }),
            FilterItem(name: "Water Ripple", filter: C7WaterRipple(ripple: 0.5), hasSlider: true, sliderRange: (0, 0.8, 0.5), callback: { value in
                var filter = C7WaterRipple()
                filter.ripple = value
                return filter
            }),
            FilterItem(name: "Glass Sphere", filter: C7GlassSphere(radius: 0.25), hasSlider: true, sliderRange: (0, 0.5, 0.25), callback: { value in
                var filter = C7GlassSphere()
                filter.radius = value
                return filter
            }),
            FilterItem(name: "Pixellated", filter: C7Pixellated(scale: 20), hasSlider: true, sliderRange: (5, 50, 20), callback: { value in
                var filter = C7Pixellated()
                filter.scale = value
                return filter
            }),
            FilterItem(name: "Polka Dot", filter: C7PolkaDot(fractionalWidth: 0.05), hasSlider: true, sliderRange: (0.01, 0.2, 0.05), callback: { value in
                var filter = C7PolkaDot()
                filter.fractionalWidth = value
                return filter
            }),
            FilterItem(name: "Halftone", filter: C7Halftone(fractionalWidth: 0.05), hasSlider: true, sliderRange: (0.01, 0.2, 0.05), callback: { value in
                var filter = C7Halftone()
                filter.fractionalWidth = value
                return filter
            }),
            FilterItem(name: "Polar Pixellate", filter: C7PolarPixellate(scale: 0.25), hasSlider: true, sliderRange: (0, 1, 0.25), callback: { value in
                var filter = C7PolarPixellate()
                filter.scale = value
                return filter
            }),
            FilterItem(name: "Sphere Refraction", filter: C7SphereRefraction(radius: 0.5), hasSlider: true, sliderRange: (0.1, 1, 0.5), callback: { value in
                var filter = C7SphereRefraction()
                filter.radius = value
                return filter
            }),
            FilterItem(name: "Morphology", filter: C7Morphology(operation: .dilation), hasSlider: true, sliderRange: (1, 10, 3), callback: { value in
                var filter = C7Morphology(operation: .dilation)
                filter.kernelSize = value
                return filter
            }),
            FilterItem(name: "Color Packing", filter: C7ColorPacking(), hasSlider: false, sliderRange: nil, callback: nil),
        ]),
        
        FilterGroup(name: "✨ Generators", items: [
            FilterItem(name: "Color Gradient", filter: C7ColorGradient(with: .radial), hasSlider: false, sliderRange: nil, callback: nil),
            FilterItem(name: "Solid Color", filter: C7SolidColor(color: C7Color(hex: "#5C48FA")), hasSlider: false, sliderRange: nil, callback: nil),
        ]),
    ]
}
