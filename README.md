# Harbeth

| Animated | Still |
| :---: | :---: |
|<img width=230px src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/Soul.gif" />|<img width=230px src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/Mix2.png" />|

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-brightgreen.svg?style=flat&colorA=28a745&&colorB=4E4E4E)](https://github.com/yangKJ/Harbeth)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Harbeth.svg?style=flat&label=Harbeth&colorA=28a745&&colorB=4E4E4E)](https://cocoapods.org/pods/Harbeth)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/OpencvQueen.svg?style=flat&label=OpenCV&colorA=28a745&&colorB=4E4E4E)](https://cocoapods.org/pods/OpencvQueen)
![Platform](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20watchOS-4E4E4E.svg?colorA=28a745)
 
[**Harbeth**](https://github.com/yangKJ/Harbeth) is a high performance Swift library for GPU accelerated image processing and realtime camera capture and video smooth playback, and then add filters based on Metal, and also compatible for CoreImage filters and using Metal performance shaders filters.

This library is highly inspired by [GPUImage](https://github.com/BradLarson/GPUImage).

-------

English | [**简体中文**](README_CN.md)

## Features
🟣 At the moment, the most important features of metal moudle can be summarized as follows:

- Support more platform system, macOS and iOS, both UIKit/AppKit and SwiftUI.
- High performance quickly add filters at these sources:    
  - UIImage, NSImage, CIImage, CGImage, CMSampleBuffer, CVPixelBuffer.
- The built-in metal kernel filters is roughly divided into the following modules:    
  - [Blend](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Blend), [Blur](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Blur), [Color](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Color), [Combination](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Combination), [DistortionWarp](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/DistortionWarp), [EdgeDetail](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/EdgeDetail), [Generators](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Generators), [Geometric Transform](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Geometric), [Lookup](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Lookup), [Matrix](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Matrix), [Other](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Other), [Stylization](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Stylization), [Utility](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Utility).
- Setup [MetalPerformanceShaders](https://github.com/yangKJ/Harbeth/tree/master/Sources/MPS) filters And also compatible for [CoreImage](https://github.com/yangKJ/Harbeth/tree/master/Sources/CoreImage) filters.
- Previews and rendering backed with the power of Metal.
- Drop-in support for your own custom filters using [LUTs](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Lookup/C7LookupTable.swift) or using [Cube](https://github.com/yangKJ/Harbeth/tree/master/Sources/CoreImage/CIColorCube.swift).
- Realtime camera capture and video smooth playback with filters.
- Video source processing video file by [Kakapos](https://github.com/yangKJ/Kakapos) library.

#### **A total of 100+ kinds of built-in filters are currently available.✌️**

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

### Filters Group

#### 🎨 Color Adjustment
- C7Brightness（亮度）
- C7ColorConvert（色彩转换）
- C7ColorRGBA（RGBA调整）
- C7ColorSpace（色彩空间）
- C7Contrast（对比度）
- C7Exposure（曝光）
- C7FalseColor（伪色）
- C7Gamma（伽马校正）
- C7Hue（色调）
- C7Monochrome（单色）
- C7Nostalgic（怀旧色调）
- C7Posterize（色调分离）
- C7Saturation（饱和度）
- C7Sepia（棕褐色调）
- C7Vibrance（自然饱和度）
- C7WhiteBalance（白平衡）

#### 🌫️ Blur Effects
- C7BilateralBlur（双边模糊）
- C7CircleBlur（圆形模糊）
- C7GaussianBlur（高斯模糊）
- C7MeanBlur（均值模糊）
- C7MotionBlur（运动模糊）
- C7RedMonochromeBlur（红色单色模糊）
- C7ZoomBlur（缩放模糊）

#### 🔄 Blend Modes
- C7BlendChromaKey（色度键控）
- C7BlendColorBurn（颜色加深）
- C7BlendColorDodge（颜色减淡）
- C7BlendDarken（变暗）
- C7BlendDifference（差值）
- C7BlendExclusion（排除）
- C7BlendHardLight（强光）
- C7BlendLighten（变亮）
- C7BlendMask（蒙版混合）
- C7BlendMultiply（正片叠底）
- C7BlendNormal（正常）
- C7BlendOverlay（叠加）
- C7BlendScreen（滤色）
- C7BlendSoftLight（柔光）

#### 🔍 Edge & Detail
- C7Canny（边缘检测）
- C7ComicStrip（漫画效果）
- C7Crosshatch（交叉线）
- C7Granularity（颗粒感）
- C7Sobel（索贝尔边缘检测）
- C7Sharpen（锐化）
- C7Sketch（素描）
- C7ThresholdSketch（阈值素描）

#### 🌀 Distortion & Warp
- C7Bulge（凸起）
- C7ColorPacking（颜色打包）
- C7GlassSphere（玻璃球）
- C7Halftone（半色调）
- C7Pinch（收缩）
- C7Pixellated（像素化）
- C7PolarPixellate（极坐标像素化）
- C7PolkaDot（圆点花纹）
- C7SphereRefraction（球面折射）
- C7Swirl（漩涡）
- C7WaterRipple（水波纹）

#### 🎭 Stylization
- C7ColorCGASpace（CGA色彩空间）
- C7Fluctuate（波动）
- C7Glitch（故障效果）
- C7Kuwahara（桑原滤波）
- C7OilPainting（油画）
- C7ShiftGlitch（移位故障）
- C7SoulOut（灵魂出窍）
- C7SplitScreen（分屏）
- C7Storyboard（故事板）
- C7Toon（卡通）
- C7VoronoiOverlay（维诺图叠加）

#### 📊 Matrix Processing
- C7ColorMatrix4x4（4x4颜色矩阵）
- C7ColorMatrix4x5（4x5颜色矩阵）
- C7ColorVector4（4维颜色向量）
- C7ConvolutionMatrix3x3（3x3卷积矩阵）
- C7EdgeGlow（边缘发光）
- C7RGBADilation（RGBA扩张）

#### 🎛️ Utility
- C7ChromaKey（色度键控）
- C7DepthLuminance（深度亮度）
- C7HighlightShadow（高光阴影）
- C7HighlightShadowTint（高光阴影色调）
- C7Levels（色阶）
- C7Luminance（亮度）
- C7LuminanceRangeReduction（亮度范围压缩）
- C7LuminanceThreshold（亮度阈值）
- C7Opacity（不透明度）

#### 📐 Geometric Transform
- C7Crop（裁剪）
- C7Flip（翻转）
- C7Mirror（镜像）
- C7Resize（调整大小）
- C7Rotate（旋转）
- C7Transform（变换）

#### 🎨 Generators
- C7ColorGradient（颜色渐变）
- C7SolidColor（纯色）

#### 📋 Lookup Tables
- C7LookupSplit（分屏查找表）
- C7LookupTable（查找表）

#### 🔗 Combination
- C7CombinationBeautiful（美颜组合）
- C7CombinationBilateralBlur（双边模糊组合）

#### 🎚️ Other Effects
- C7Grayed（灰度化）
- C7Haze（雾霾）
- C7Pow（幂次调整）
- C7Vignette（暗角）

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

- If you want to import [**OpenCV**](https://github.com/yangKJ/OpencvQueen) image module, you need in your Podfile: 

```
pod 'OpencvQueen'
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
