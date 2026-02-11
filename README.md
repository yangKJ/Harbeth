# Harbeth

| Animated | Still |
| :---: | :---: |
|<img width=230px src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/Soul.gif" />|<img width=230px src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/Mix2.png" />|

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-brightgreen.svg?style=flat&colorA=28a745&&colorB=4E4E4E)](https://github.com/yangKJ/Harbeth)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Harbeth.svg?style=flat&label=Harbeth&colorA=28a745&&colorB=4E4E4E)](https://cocoapods.org/pods/Harbeth)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/OpencvQueen.svg?style=flat&label=OpenCV&colorA=28a745&&colorB=4E4E4E)](https://cocoapods.org/pods/OpencvQueen)
![Platform](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20watchOS-4E4E4E.svg?colorA=28a745)
 
[**Harbeth**](https://github.com/yangKJ/Harbeth) is a high-performance Swift library focused on GPU-accelerated real-time image processing, camera capture, and video processing. Built on Metal technology, it also integrates with CoreImage and Metal Performance Shaders, providing developers with a powerful and easy-to-integrate image processing solution.

Harbeth is designed to address the performance bottlenecks of traditional CPU-based image processing. By fully leveraging GPU parallel computing capabilities, it achieves real-time, smooth image processing effects. Whether for simple color adjustments or complex real-time video effects, Harbeth handles them with ease.

This library is highly inspired by [GPUImage](https://github.com/BradLarson/GPUImage).

-------

English | [**简体中文**](README_CN.md)

## Features
🟣 At the moment, the most important features of metal moudle can be summarized as follows:

- Support more platform system, macOS and iOS, both UIKit/AppKit and SwiftUI.
- High performance quickly add filters at these sources:    
  - UIImage, NSImage, CIImage, CGImage, CMSampleBuffer, CVPixelBuffer.
- The built-in metal kernel filters is roughly divided into the following modules.
- Setup [MetalPerformanceShaders](https://github.com/yangKJ/Harbeth/tree/master/Sources/MPS) filters And also compatible for [CoreImage](https://github.com/yangKJ/Harbeth/tree/master/Sources/CoreImage) filters.
- Previews and rendering backed with the power of Metal.
- Drop-in support for your own custom filters using [LUTs](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Lookup/C7LookupTable.swift) or using [Cube](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Lookup%20Tables/C7ColorCube.swift) files.
- Realtime camera capture and video smooth playback with filters.
- Video source processing video file by [Kakapos](https://github.com/yangKJ/Kakapos) library.

### 🎨 Filter System
Harbeth offers a comprehensive filter classification to meet various image processing needs:
- **Color Adjustment**: Brightness, contrast, saturation, exposure, white balance, etc.
- **Blur Effects**: Gaussian blur, bilateral blur, motion blur, zoom blur, etc.
- **Blend Modes**: Normal, multiply, screen, overlay, hard light, etc.
- **Edge & Detail**: Sharpen, edge detection, sketch, comic strip effect, etc.
- **Distortion & Warp**: Bulge, pinch, swirl, water ripple, glass sphere, etc.
- **Stylization**: Oil painting, cartoon, glitch effect, split screen, soul out, etc.
- **Geometric Transform**: Crop, flip, rotate, resize, etc.
- **Matrix Processing**: 3x3 convolution matrix, 4x4 color matrix, 4x5 color matrix, etc.
- **Utility**: Chroma key, highlight shadow, levels, luminance threshold, etc.
- **Generators**: Solid color, color gradient, etc.
- **Lookup Tables**: LUT-based color adjustments and CUBE file support
- **Blit Operations**: Copy region, crop, generate mipmaps
- **CoreImage Integration**: Access to CoreImage filters
- **Metal Performance Shaders**: High-performance MPS filters

#### **A total of 200+ kinds of built-in filters are currently available.✌️**

### 🔧 Technical Advantages
- **Metal Acceleration**: Fully leverages GPU parallel computing power
- **Multi-encoder Support**: Automatically selects optimal command encoder based on filter type
- **Intelligent Memory Management**: Automatic texture pooling and memory limit mechanisms
- **Performance Monitoring**: Built-in performance monitoring tools to help optimize processing workflows
- **Seamless Integration**: Integrates with CoreImage and Metal Performance Shaders
- **Type Safety**: Pure Swift implementation with complete type safety
- **Combination Filters**: Create complex effects by combining multiple filters
- **Extensibility**: Easy to add custom filters using Metal shaders or LUT files

## Requirements

| iOS Target | macOS Target | Xcode Version | Swift Version |
|:---:|:---:|:---:|:---:|
| iOS 10.0+ | macOS 10.13+ | Xcode 10.0+ | Swift 5.0+ |

## Usage

<p align="left">
<img src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/ShiftGlitch.gif" width=35% hspace="1px">
<img src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/EdgeGlow.gif" width=35% hspace="15px">
</p>

### Image

- 🎷 Code zero intrusion add filter function for image.

```
let filter1 = C7ColorMatrix4x4(matrix: Matrix4x4.Color.sepia)
let filter2 = C7Granularity(grain: 0.8)
let filter3 = C7SoulOut(soul: 0.7)

let filters = [filter1, filter2, filter3]

// Use:
let dest = HarbethIO.init(element: originImage, filters: filters)
// Synchronize do something..
ImageView.image = try? dest.output()

// OR Use:
ImageView.image = try? originImage.makeGroup(filters: filters)

// OR Use:
ImageView.image = originImage.filtering(filter1, filter2, filter3)

// OR Use Operator:
ImageView.image = originImage ->> filter1 ->> filter2 ->> filter3
```

- Asynchronous do something..

This performance is the best. 🚗🚗

```
let dest = HarbethIO.init(element: ``Source``, filter: ``filter``)

dest.transmitOutput(success: { [weak self] image in
    // do something..
})
```

### Camera

- 📸 Camera capture generates pictures.

```
// Add an edge detection filter:
let filter = C7EdgeGlow(lineColor: .red)

// Generate camera collector:
let camera = C7CollectorCamera.init(delegate: self)
camera.captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
camera.filters = [filter]

extension CameraViewController: C7CollectorImageDelegate {
    func preview(_ collector: C7Collector, fliter image: C7Image) {
        // do something..
    }
}
```

### Video

- 📺 Local video or Network video are simply apply with filters.
  - 🙄 For details, See [PlayerViewController](https://github.com/yangKJ/Harbeth/blob/master/Demo/Harbeth-iOS-Demo/Modules/PlayerViewController.swift).
  - You can also extend this by using [HarbethIO](https://github.com/yangKJ/Harbeth/blob/master/Sources/Basic/Outputs/HarbethIO.swift) to filter the collected `CVPixelBuffer`.

```
lazy var video: C7CollectorVideo = {
    let videoURL = URL.init(string: "Link")!
    let asset = AVURLAsset.init(url: videoURL)
    let playerItem = AVPlayerItem.init(asset: asset)
    let player = AVPlayer.init(playerItem: playerItem)
    let video = C7CollectorVideo.init(player: player, delegate: self)
    let filter = C7ColorMatrix4x4(matrix: Matrix4x4.Color.sepia)
    video.filters = [filter]
    return video
}()

self.video.play()

extension PlayerViewController: C7CollectorImageDelegate {
    func preview(_ collector: C7Collector, fliter image: C7Image) {
        // do something..
    }
}
```

### SwiftUI Support
- For the direct use [HarbethView](https://github.com/yangKJ/Harbeth/blob/master/Sources/SwiftUI/HarbethView.swift), it is just a simple implementation.
- The SwiftUI API is still in-progress and may not be production ready. We're looking for help! 🤲

```
let filters: [C7FilterProtocol] = [
    CIHighlight(highlight: intensity),
    C7WaterRipple(ripple: intensity),
]
HarbethView(image: inputImage, filters: filters, content: { image in
    image.resizable()
        .aspectRatio(contentMode: .fit)
})
```

### 🎨 Filter List

#### 🔗 Combination Filters
Combination filters allow you to create complex effects by combining multiple individual filters. These filters are designed to work together to achieve specific visual styles or effects that would be difficult to create with a single filter.

**Advantages of Combination Filters:**
- **Simplified Usage**: Apply multiple effects with a single filter
- **Optimized Performance**: Filters are applied in a single pass when possible
- **Consistent Results**: Pre-configured combinations ensure predictable outcomes
- **Customizable**: Many combination filters allow adjustment of individual parameters

**Examples of Combination Filters:**
- **C7CombinationBeautiful**: Enhances facial features and skin tone for beauty effects
- **C7CombinationCinematic**: Creates a cinematic look with enhanced contrast and color grading
- **C7CombinationModernHDR**: Achieves modern HDR effects with improved dynamic range
- **C7CombinationVintage**: Applies vintage film effects with warm tones and grain

#### 🎨 Color Adjustment
- **C7Brightness**: Adjusts the overall brightness of the image, with values ranging from -1.0 (darkest) to 1.0 (brightest), where 0.0 represents the original image
- **C7ColorConvert**: Converts colors between different color spaces, such as RGB to YUV or other color space transformations
- **C7ColorRGBA**: Independently adjusts the red, green, blue, and alpha channels of the image, allowing for precise color control
- **C7ColorSpace**: Performs advanced color space operations, enabling complex color manipulations and transformations
- **C7Contrast**: Adjusts the contrast of the image, with values ranging from 0.0 (no contrast) to 2.0 (maximum contrast), where 1.0 is the original image
- **C7Exposure**: Simulates camera exposure adjustments, with values ranging from -10.0 (underexposed) to 10.0 (overexposed), where 0.0 is the original exposure
- **C7FalseColor**: Uses the luminance values of the original image to mix between two user-specified colors, creating artistic false color effects
- **C7Gamma**: Applies gamma correction to the image, with values ranging from 0.0 (high contrast) to 3.0 (low contrast), where 1.0 is the original image
- **C7Grayed**: Converts the image to grayscale, removing all color information while preserving luminance
- **C7Haze**: Applies a haze effect to the image, reducing contrast and adding a foggy or misty appearance
- **C7Hue**: Adjusts the overall hue of the image in degrees, rotating the color wheel to shift all colors uniformly
- **C7LuminanceAdaptiveContrast**: Dynamically adjusts contrast based on local pixel brightness, enhancing details in both dark and bright areas
- **C7Monochrome**: Converts the image to a monochrome version, tinting it with a specific color based on the brightness of each pixel
- **C7Nostalgic**: Applies a nostalgic color tone effect, reminiscent of vintage photographs with warm, aged colors
- **C7Opacity**: Adjusts the transparency of the image, making it more or less see-through
- **C7Posterize**: Reduces the number of colors in the image, creating a stylized, poster-like effect with distinct color blocks
- **C7Saturation**: Adjusts the color saturation of the image, with values ranging from 0.0 (grayscale) to 2.0 (highly saturated), where 1.0 is the original image
- **C7Sepia**: Applies a sepia tone effect to the image, giving it a warm, brownish vintage appearance similar to old photographs
- **C7Vibrance**: Intelligently adjusts the vibrance of the image, enhancing muted colors while preserving skin tones, with values ranging from -1.2 (desaturated) to 1.2 (highly vibrant)
- **C7WhiteBalance**: Adjusts the white balance of the image based on color temperature, allowing correction of color casts from different lighting conditions

#### 🌫️ Blur Effects
- **C7BilateralBlur**: Applies a bilateral blur effect that preserves edges while blurring flat areas, creating a smooth appearance without losing important details
- **C7CircleBlur**: Creates a circular blur effect that radiates from a central point, with blur intensity decreasing outward from the center
- **C7DetailPreservingBlur**: Applies a blur that reduces noise and smooths the image while preserving important details and edges
- **C7GaussianBlur**: Applies a classic Gaussian blur effect, creating a smooth, natural-looking blur by averaging pixel values with a Gaussian distribution
- **C7MeanBlur**: Applies a mean (box) blur effect, averaging pixel values within the blur radius for a simple but effective blur
- **C7MotionBlur**: Simulates motion blur in a specified direction, creating the illusion of movement or camera shake
- **C7RedMonochromeBlur**: Applies a blur effect that affects only the red channel while converting the rest of the image to monochrome
- **C7ZoomBlur**: Creates a zoom blur effect that simulates the camera zooming in or out, with radial blur lines emanating from a central point

#### 🔄 Blend Modes
- **C7Blend**: Base class for all blend modes, providing common functionality for blending operations
- **C7BlendChromaKey**: Implements chroma key (green screen) functionality, allowing replacement of a specific color with another image or transparency
- **C7BlendColorAdd**: Adds the color values of the blend layer to the base layer, resulting in a brighter image
- **C7BlendColorAlpha**: Blends layers based on the alpha channel values, creating semi-transparent effects
- **C7BlendColorBurn**: Darkens the base layer by increasing contrast, creating a rich, dark blending effect
- **C7BlendColorDodge**: Brightens the base layer by decreasing contrast, creating a lightening effect
- **C7BlendDarken**: Keeps the darker pixel values from either layer, resulting in an overall darker image
- **C7BlendDifference**: Subtracts the darker color from the lighter one, creating a high-contrast effect
- **C7BlendDissolve**: Randomly replaces pixels from the base layer with pixels from the blend layer, creating a dissolve effect
- **C7BlendDivide**: Divides the base layer colors by the blend layer colors, resulting in a brighter image
- **C7BlendExclusion**: Similar to difference mode but with lower contrast, creating a softer effect
- **C7BlendHardLight**: Combines multiply and screen modes, creating a strong lighting effect
- **C7BlendHue**: Uses the hue of the blend layer with the saturation and luminance of the base layer
- **C7BlendLighten**: Keeps the lighter pixel values from either layer, resulting in an overall brighter image
- **C7BlendLinearBurn**: Linearly darkens the base layer by the blend layer values
- **C7BlendLuminosity**: Uses the luminance of the blend layer with the hue and saturation of the base layer
- **C7BlendMask**: Uses a mask to control which areas of the blend layer are visible
- **C7BlendMultiply**: Multiplies the color values of the two layers, resulting in a darker image
- **C7BlendNormal**: The standard blending mode where the blend layer simply covers the base layer
- **C7BlendOverlay**: Combines multiply and screen modes, enhancing contrast while preserving highlights and shadows
- **C7BlendScreen**: Inverts both layers, multiplies them, then inverts the result, creating a lighter image
- **C7BlendSoftLight**: Gently lightens or darkens the base layer based on the blend layer values
- **C7BlendSourceOver**: The default blending mode where the blend layer is drawn over the base layer
- **C7BlendSubtract**: Subtracts the blend layer colors from the base layer colors, resulting in a darker image
- **C7BlendWithMask**: Uses a separate mask texture to control the blending of two layers

#### 🔍 Edge & Detail
- **C7Canny**: Applies the Canny edge detection algorithm, a multi-stage process that identifies edges with high accuracy and low noise
- **C7ComicStrip**: Creates a comic strip effect, with bold outlines and flat colors reminiscent of comic book art
- **C7Crosshatch**: Applies a crosshatch pattern to the image, creating a sketch-like appearance with intersecting lines
- **C7DetailEnhancer**: Enhances fine details in the image without amplifying noise, resulting in a sharper appearance
- **C7EdgeAwareSharpen**: Sharpens only the edge areas of the image while preserving smooth regions, avoiding the amplification of noise
- **C7Granularity**: Adjusts the film graininess of the image, adding or reducing texture for a more cinematic or vintage appearance
- **C7Sharpen**: Sharpens the entire image by increasing contrast at edges, making details more pronounced
- **C7Sketch**: Converts the image into a pencil sketch effect, emphasizing edges and reducing color information
- **C7Sobel**: Applies the Sobel edge detection algorithm, which calculates gradients to identify edges in the image
- **C7ThresholdSketch**: Creates a sketch effect using edge detection with thresholding, resulting in a high-contrast, line-based representation

#### 🌀 Distortion & Warp
- **C7Bulge**: Creates a bulge distortion effect that pushes pixels outward from a central point, creating a convex appearance
- **C7ColorCGASpace**: Applies a CGA (Color Graphics Adapter) color space effect, limiting colors to a palette of 16 colors for a retro computer appearance
- **C7ColorPacking**: Applies a color packing effect that reduces color depth, creating a stylized, low-color appearance
- **C7Fluctuate**: Creates a fluctuation effect that distorts the image in a wavelike pattern, similar to a heat haze or water distortion
- **C7GlassSphere**: Simulates the effect of looking through a glass sphere, combining refraction and reflection for a spherical distortion
- **C7Halftone**: Creates a halftone printing effect, replacing continuous tones with dots of varying size and density
- **C7Morphology**: Applies morphological operations such as erosion and dilation, useful for edge detection and noise reduction
- **C7Pinch**: Creates a pinch distortion effect that pulls pixels inward toward a central point, creating a concave appearance
- **C7Pixellated**: Applies a pixelation effect, reducing the image resolution to create large, visible pixels
- **C7PolarPixellate**: Converts the image to polar coordinates and applies pixelation, creating a circular, distorted appearance
- **C7PolkaDot**: Overlays a polka dot pattern on the image, replacing pixels with dots of varying size and color
- **C7SphereRefraction**: Simulates light refraction through a sphere, creating a distorted view of the image
- **C7Swirl**: Creates a swirl distortion effect that rotates pixels around a central point, creating a vortex appearance
- **C7WaterRipple**: Simulates water ripple effects, creating concentric waves that distort the image

#### 🎭 Stylization
- **C7ColorCGASpace**: Applies a CGA (Color Graphics Adapter) color filter, limiting colors to a retro palette of black, light blue, and purple blocks
- **C7Fluctuate**: Creates a fluctuation effect that distorts the image in a wavelike pattern, similar to graffiti or heat distortion
- **C7Glitch**: Applies a glitch art effect, simulating digital errors such as horizontal displacement and color corruption
- **C7Kuwahara**: Applies the Kuwahara filter, creating an oil painting effect by averaging pixel values within a neighborhood
- **C7OilPainting**: Creates an oil painting effect with brush strokes and texture, simulating the appearance of traditional oil paint
- **C7RGBADilation**: Finds the maximum value of each color channel within a specified radius, creating a color expansion effect
- **C7ShiftGlitch**: Applies an RGB shift glitch effect, separating the red, green, and blue color channels for a trippy appearance
- **C7SoulOut**: Creates a "soul out" effect, duplicating and offsetting the image to create a ghostly double image
- **C7SplitScreen**: Creates a split screen effect, dividing the image into multiple sections with different treatments
- **C7Storyboard**: Applies a storyboard effect, giving the image the appearance of a comic book panel
- **C7Toon**: Creates a cartoon effect with simplified colors and bold outlines, resembling animated characters
- **C7VoronoiOverlay**: Overlays a Voronoi diagram on the image, creating cellular patterns with sharp edges

#### 📊 Matrix Processing
- **C7ColorMatrix4x4**: Applies a 4x4 color matrix transformation to the image, allowing for complex color adjustments and transformations
- **C7ColorMatrix4x5**: Applies a 4x5 color matrix transformation, providing an additional offset value for more flexible color adjustments
- **C7ColorVector4**: Applies a 4D color vector transformation, modifying the red, green, blue, and alpha components of the image
- **C7ConvolutionMatrix3x3**: Applies a 3x3 convolution matrix to the image, useful for edge detection, sharpening, and other image processing operations
- **C7EdgeGlow**: Detects edges in the image and adds a glow effect to them, creating a dramatic, outlined appearance

#### 🎛️ Utility
- **C7ChromaKey**: Removes the background that matches a specified color, similar to green screen effects in video production
- **C7DepthLuminance**: Adjusts luminance based on depth information, creating a more realistic lighting effect
- **C7HighlightShadow**: Independently adjusts the highlights and shadows of the image, allowing for precise tonal control
- **C7HighlightShadowTint**: Tints the highlights and shadows of the image with specified colors, creating a color graded appearance
- **C7Highlights**: Specifically adjusts only the highlight areas of the image, brightening or darkening them as needed
- **C7Levels**: Adjusts the image levels, controlling the shadows, midtones, and highlights for better tonal range
- **C7Luminance**: Extracts the luminance (brightness) component from the image, creating a grayscale representation
- **C7LuminanceRangeReduction**: Reduces the luminance range of the image, compressing the difference between bright and dark areas
- **C7LuminanceThreshold**: Applies a threshold to the luminance values, creating a high-contrast black and white image
- **C7Shadows**: Specifically adjusts only the shadow areas of the image, brightening or darkening them as needed

#### 📐 Geometric Transform
- **C7Crop**: Crops the image to a specified rectangular region, removing unwanted areas
- **C7Flip**: Flips the image horizontally or vertically, creating a mirror image along one axis
- **C7Mirror**: Creates a mirror effect by duplicating and flipping a portion of the image
- **C7Resize**: Resizes the image to a specified width and height, optionally maintaining aspect ratio
- **C7Rotate**: Rotates the image by a specified angle, around a center point
- **C7Transform**: Applies an affine transformation to the image, allowing for rotation, scaling, and translation in a single operation

#### 🎨 Generators
- **C7ColorGradient**: Generates a color gradient, creating a smooth transition between two or more colors, useful for backgrounds or overlays
- **C7SolidColor**: Generates a solid color image, useful for backgrounds, masks, or as a base for other effects

#### 📋 Lookup Tables
- **C7ColorCube**: Applies a 3D LUT (Look-Up Table) from CUBE files, allowing for professional color grading and complex color transformations
- **C7LookupSplit**: Applies split screen lookup tables, allowing different color treatments in different parts of the image
- **C7LookupTable**: Applies a color lookup table (LUT) from image files, used for color grading and stylization

#### 🔗 Combination Effects
- **C7CombinationBeautiful**: A beauty combination effect that enhances facial features and skin tone, combining multiple beauty-enhancing filters for a polished appearance
- **C7CombinationCinematic**: A cinematic combination effect that creates a film-like appearance with enhanced contrast, saturation, and subtle vignette
- **C7CombinationModernHDR**: A modern HDR combination effect that improves dynamic range, enhancing both shadow detail and highlight information
- **C7CombinationVintage**: A vintage combination effect that simulates old film stock with warm tones, subtle grain, and reduced contrast

#### 🎚️ Other Effects
- **C7Grayed**: Converts the image to grayscale using various methods, including luminosity, average, and desaturation
- **C7Haze**: Applies a haze effect to the image, reducing contrast and adding a foggy or misty appearance
- **C7Pow**: Applies a power function to the image, creating non-linear brightness adjustments
- **C7Vignette**: Applies a vignette effect that darkens the edges of the image, drawing attention to the center
- **C7VignetteBlend**: Applies a vignette effect with multiple blend modes, allowing for different styles of edge darkening

#### 🖼️ Blit Operations
- **C7CopyRegionBlit**: Copies a specific region from one texture to another
- **C7CropBlit**: Crops the image to a specified region
- **C7GenerateMipmapsBlit**: Generates mipmaps for a texture, useful for efficient downsampling

#### 🎯 CoreImage Integration
- **CIBrightness**: CoreImage brightness adjustment
- **CIColorControls**: CoreImage color controls (brightness, contrast, saturation)
- **CIColorCube**: CoreImage color cube filter
- **CIColorMonochrome**: CoreImage monochrome effect
- **CIContrast**: CoreImage contrast adjustment
- **CIExposure**: CoreImage exposure adjustment
- **CIFade**: CoreImage fade effect
- **CIGaussianBlur**: CoreImage Gaussian blur
- **CIHighlight**: CoreImage highlight adjustment
- **CILookupTable**: CoreImage lookup table filter
- **CINoiseReduction**: CoreImage noise reduction
- **CIPhotoEffect**: CoreImage photo effects (chrome, fade, instant, mono, noir, process, tonal, transfer)
- **CIResizedSmooth**: CoreImage smooth resizing
- **CISaturation**: CoreImage saturation adjustment
- **CIShadows**: CoreImage shadow adjustment
- **CISharpen**: CoreImage sharpening
- **CISketch**: CoreImage sketch effect
- **CITemperature**: CoreImage temperature adjustment
- **CIUnsharpMask**: CoreImage unsharp mask sharpening
- **CIVignette**: CoreImage vignette effect
- **CIWhitePoint**: CoreImage white point adjustment

#### ⚡ Metal Performance Shaders
- **MPSBoxBlur**: Metal Performance Shaders box blur
- **MPSGaussianBlur**: Metal Performance Shaders Gaussian blur
- **MPSHistogram**: Metal Performance Shaders histogram calculation
- **MPSMedian**: Metal Performance Shaders median filter
- **MPSCanny**: Metal Performance Shaders Canny edge detection

---

**Find suggestions：**
1. Need color adjustment → Check **Color adjustment** classification
2. Need blur effect → View **Blur effect** classification
3. Need to blend layers → View **Mixed Mode** Classification
4. Need artistic style → View **Stylized effect** classification
Five. Need to deform and twist → Check the classification of **Tortion and deformation**
6. Edge detection is required → View **Edge and Details** Classification
7. Need geometric transformation → View **Geometric transformation** classification

### CocoaPods

- If you want to import [**Metal**](https://github.com/yangKJ/Harbeth) module, you need in your Podfile: 

```
pod 'Harbeth'
```

### Swift Package Manager

[Swift Package Manager](https://swift.org/package-manager/) is a tool for managing the distribution of Swift code. It’s integrated with the Swift build system to automate the process of downloading, compiling, and linking dependencies.

> Xcode 11+ is required to build [Harbeth](https://github.com/yangKJ/Harbeth) using Swift Package Manager.

To integrate Harbeth into your Xcode project using Swift Package Manager, add it to the dependencies value of your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yangKJ/Harbeth.git", branch: "master"),
]
```

### Remarks

> The general process is almost like this, the Demo is also written in great detail, you can check it out for yourself.🎷
>
> [**HarbethDemo**](https://github.com/yangKJ/Harbeth)
>
> Tip: If you find it helpful, please help me with a star. If you have any questions or needs, you can also issue.
>
> Thanks.🎇

### About the author
- 🎷 **E-mail address: [yangkj310@gmail.com](yangkj310@gmail.com) 🎷**
- 🎸 **GitHub address: [yangKJ](https://github.com/yangKJ) 🎸**

Buy me a coffee or support me on [GitHub](https://github.com/sponsors/yangKJ?frequency=one-time&sponsor=yangKJ).

<a href="https://www.buymeacoffee.com/yangkj3102">
<img width=25% alt="yellow-button" src="https://user-images.githubusercontent.com/1888355/146226808-eb2e9ee0-c6bd-44a2-a330-3bbc8a6244cf.png">
</a>

Alipay or WeChat. Thanks.

<p align="left">
<img src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/WechatIMG1.jpg" width=30% hspace="1px">
<img src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/WechatIMG2.jpg" width=30% hspace="15px">
</p>

-----

### License
Harbeth is available under the [MIT](LICENSE) license. See the [LICENSE](LICENSE) file for more info.

-----

### 📞 Technical Support

#### Frequently Asked Questions

**Q: Which platforms does Harbeth support?**
A: Harbeth supports iOS 10.0+, macOS 10.13+, tvOS 12.0+, and watchOS 5.0+.

**Q: How is Harbeth's performance?**
A: Harbeth is built on Metal, fully leveraging GPU acceleration, which is several times faster than CPU processing, especially suitable for real-time processing scenarios.

**Q: How to create custom filters?**
A: You can create custom filters by implementing the `C7FilterProtocol` protocol, or create custom color adjustment filters using LUT files.

**Q: What advantages does Harbeth have compared to CoreImage?**
A: Harbeth provides a cleaner API, more built-in filters, and better performance monitoring functionality. At the same time, Harbeth is also compatible with CoreImage filters.

**Q: How to handle memory issues?**
A: You can limit Harbeth's memory usage by adjusting the `memoryLimitMB` property, or use asynchronous processing to avoid memory peaks.

<p align="center">
  <em>Thank you for using Harbeth! I hope it can help with your projects.</em>
</p>