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

#### **A total of 200+ kinds of built-in filters are currently available.✌️**

### 🔧 Technical Advantages
- **Metal Acceleration**: Fully leverages GPU parallel computing power
- **Multi-encoder Support**: Automatically selects optimal command encoder based on filter type
- **Intelligent Memory Management**: Automatic texture pooling and memory limit mechanisms
- **Performance Monitoring**: Built-in performance monitoring tools to help optimize processing workflows
- **Seamless Integration**: Integrates with CoreImage and Metal Performance Shaders
- **Type Safety**: Pure Swift implementation with complete type safety

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

#### 🎨 Color Adjustment
- **C7Brightness**: Brightness adjustment, ranging from -1.0 to 1.0
- **C7ColorConvert**: Color space conversion
- **C7ColorRGBA**: RGBA channel adjustment
- **C7ColorSpace**: Advanced color space operations
- **C7Contrast**: Contrast adjustment, ranging from 0.0 to 2.0
- **C7Exposure**: Exposure adjustment, ranging from -10.0 to 10.0
- **C7FalseColor**: Uses the luminance of the image to mix between two user-specified colors
- **C7Gamma**: Gamma correction, ranging from 0.0 to 3.0
- **C7Grayed**: Grayscale conversion
- **C7Haze**: Haze effect
- **C7Hue**: Hue adjustment, in degrees
- **C7LuminanceAdaptiveContrast**: Adaptive contrast adjustment based on pixel brightness
- **C7Monochrome**: Convert the image into a monochrome version and color it according to the brightness of each pixel
- **C7Nostalgic**: Nostalgic tone effect
- **C7Opacity**: Transparency adjustment, similar to changing alpha
- **C7Posterize**: Posterization effect, reduces the number of colors in the image
- **C7Pow**: Power adjustment
- **C7Saturation**: Saturation adjustment, ranging from 0.0 to 2.0
- **C7Sepia**: Sepia tone effect
- **C7Vibrance**: Vibrance adjustment, ranging from -1.2 to 1.2
- **C7WhiteBalance**: Adjust the white balance based on color temperature

#### 🌫️ Blur Effects
- **C7BilateralBlur**: Bilateral blur (edge-preserving blur)
- **C7CircleBlur**: Circle blur
- **C7DetailPreservingBlur**: Keep the details as much as possible while reducing noise
- **C7GaussianBlur**: Gaussian blur
- **C7MeanBlur**: Mean blur
- **C7MotionBlur**: Motion blur
- **C7RedMonochromeBlur**: Red monochrome blur effect
- **C7ZoomBlur**: Zoom blur

#### 🔄 Blend Modes
- **C7Blend**: Base class for blend modes
- **C7BlendChromaKey**: Chroma key (green screen)
- **C7BlendColorAdd**: Color add blending mode
- **C7BlendColorAlpha**: Color alpha blending mode
- **C7BlendColorBurn**: Color burn blending mode
- **C7BlendColorDodge**: Color dodge blending mode
- **C7BlendDarken**: Darken blending mode
- **C7BlendDifference**: Difference blending mode
- **C7BlendDissolve**: Dissolve blending mode
- **C7BlendDivide**: Divide blending mode
- **C7BlendExclusion**: Exclusion blending mode
- **C7BlendHardLight**: Hard light blending mode
- **C7BlendHue**: Hue blending mode
- **C7BlendLighten**: Lighten blending mode
- **C7BlendLinearBurn**: Linear burn blending mode
- **C7BlendLuminosity**: Luminosity blending mode
- **C7BlendMask**: Mask blend
- **C7BlendMultiply**: Multiply blending mode
- **C7BlendNormal**: Normal blending mode
- **C7BlendOverlay**: Overlay blending mode
- **C7BlendScreen**: Screen blending mode
- **C7BlendSoftLight**: Soft light blending mode
- **C7BlendSourceOver**: Source over blending mode
- **C7BlendSubtract**: Subtract blending mode
- **C7BlendWithMask**: Blending with mask

#### 🔍 Edge & Detail
- **C7Canny**: Canny edge detection
- **C7ComicStrip**: Comic strip effect
- **C7Crosshatch**: Crosshatch effect
- **C7DetailEnhancer**: Enhances image details
- **C7EdgeAwareSharpen**: Sharpens only edge areas
- **C7Granularity**: Adjusts film graininess
- **C7Sharpen**: Sharpens the image
- **C7Sketch**: Sketch effect
- **C7Sobel**: Sobel edge detection
- **C7ThresholdSketch**: Threshold-based sketch effect

#### 🌀 Distortion & Warp
- **C7Bulge**: Bulge distortion effect
- **C7ColorCGASpace**: CGA color space effect
- **C7ColorPacking**: Color packing effect
- **C7Fluctuate**: Fluctuation effect
- **C7GlassSphere**: Glass sphere effect
- **C7Halftone**: Halftone effect
- **C7Pinch**: Pinch distortion effect
- **C7Pixellated**: Pixelation effect
- **C7PolarPixellate**: Polar coordinate pixelation effect
- **C7PolkaDot**: Polka dot pattern
- **C7SphereRefraction**: Sphere refraction effect
- **C7Swirl**: Swirl distortion effect
- **C7WaterRipple**: Water ripple effect

#### 🎭 Stylization
- **C7ColorCGASpace**: Image CGA color filter to form black, light blue and purple blocks
- **C7Fluctuate**: The fluctuation effect can also be similar to the graffiti effect
- **C7Glitch**: Glitch art effect
- **C7Kuwahara**: Kuwahara filter (oil painting effect)
- **C7OilPainting**: Oil painting effect
- **C7RGBADilation**: Find the maximum value of each color channel in the range of radius
- **C7ShiftGlitch**: RGB shift glitch effect
- **C7SoulOut**: The effect of soul out of the trick
- **C7SplitScreen**: Split screen effect
- **C7Storyboard**: Storyboard effect
- **C7Toon**: Cartoon effect
- **C7VoronoiOverlay**: Voronoi diagram overlay effect

#### 📊 Matrix Processing
- **C7ColorMatrix4x4**: 4x4 color matrix transformation
- **C7ColorMatrix4x5**: 4x5 color matrix transformation
- **C7ColorVector4**: 4D color vector transformation
- **C7ConvolutionMatrix3x3**: 3x3 convolution matrix
- **C7EdgeGlow**: Edge glow effect

#### 🎛️ Utility
- **C7ChromaKey**: Remove the background that has the specified color
- **C7DepthLuminance**: Depth-based luminance
- **C7HighlightShadow**: Adjusts highlights and shadows
- **C7HighlightShadowTint**: Tints highlights and shadows
- **C7Levels**: Levels adjustment
- **C7Luminance**: Extracts luminance from the image
- **C7LuminanceRangeReduction**: Reduces luminance range
- **C7LuminanceThreshold**: Threshold filter with dynamic threshold size

#### 📐 Geometric Transform
- **C7Crop**: Crop the image
- **C7Flip**: Flip the image
- **C7Mirror**: Mirror the image
- **C7Resize**: Resize the image
- **C7Rotate**: Rotate the image
- **C7Transform**: Applies affine transformation

#### 🎨 Generators
- **C7ColorGradient**: Color gradient
- **C7SolidColor**: Solid color

#### 📋 Lookup Tables
- **C7ColorCube**: 3D LUT color cube filter for CUBE files
- **C7LookupSplit**: Split screen lookup table
- **C7LookupTable**: Color lookup table (LUT)

#### 🔗 Combination Effects
- **C7CombinationBeautiful**: Beauty combination effect
- **C7CombinationCinematic**: Cinematic combination effect
- **C7CombinationModernHDR**: Modern HDR combination effect
- **C7CombinationVintage**: Vintage combination effect

#### 🎚️ Other Effects
- **C7Vignette**: Vignette effect

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