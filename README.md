# Harbeth

![x](https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/launch.jpeg)

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-brightgreen.svg?style=flat&colorA=28a745&&colorB=4E4E4E)](https://github.com/yangKJ/Harbeth)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Harbeth.svg?style=flat&label=Harbeth&colorA=28a745&&colorB=4E4E4E)](https://cocoapods.org/pods/Harbeth)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/OpencvQueen.svg?style=flat&label=OpenCV&colorA=28a745&&colorB=4E4E4E)](https://cocoapods.org/pods/OpencvQueen)
![Platform](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20watchOS-4E4E4E.svg?colorA=28a745)
 
[**Harbeth**](https://github.com/yangKJ/Harbeth) is a tiny set of utils and extensions over Apple's Metal framework dedicated to make your Swift GPU code much cleaner and let you prototype your pipelines faster.

-------

English | [**简体中文**](README_CN.md)

## Features
🟣 At the moment, the most important features of [**metal moudle**](https://github.com/yangKJ/Harbeth) can be summarized as follows:

- Support iOS and macOS.
- Support operator chain filter.
- Support `UIImage`, `CIImage`, `CGImage`, `CMSampleBuffer` and `CVPixelBuffer` add fillters.
- Support quick design filters.
- Support merge multiple filter effects.
- Support fast expansion of output sources.
- Support camera capture effects.
- Support video to add filter special effects.
- Support matrix convolution.
- Support `MetalPerformanceShaders` related types of filters.
- Support compatible for `CoreImage`.
- The filter part is roughly divided into the following modules:
  - [x] [Blend](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Blend): This module mainly contains image blend filters.
  - [x] [Blur](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Blur): Blur effect filters.
  - [x] [Pixel](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/ColorProcess): Basic pixel processing of images.
  - [x] [Effect](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Effect): Effect processing.
  - [x] [Lookup](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Lookup): Lookup table filters.
  - [x] [Matrix](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Matrix): Matrix convolution filters.
  - [x] [Shape](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Shape): Image shape size related filters.
  - [x] [Visual](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Visual): Visual dynamic effect filters.
  - [x] [MPS](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/MPS): MetalPerformanceShaders related types of filters.

#### **A total of `100+` kinds of filters are currently available.✌️**

## Usage

<p align="left">
<img src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/ShiftGlitch.gif" width=35% hspace="10px">
<img src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/EdgeGlow.gif" width=35% hspace="15px">
</p>

- Original code.
```swift
lazy var ImageView: UIImageView = {
    let imageView = UIImageView(image: originImage)
    //imageView.contentMode = .scaleAspectFit
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.layer.borderColor = R.color("background2")?.cgColor
    imageView.layer.borderWidth = 0.5
    return imageView
}()

ImageView.image = originImage
```

- 🫡 Code zero intrusion add filter function.

```swift
let filter1 = C7ColorMatrix4x4(matrix: Matrix4x4.Color.sepia)

let filter2 = C7Granularity(grain: 0.8)

let filter3 = C7SoulOut(soul: 0.7)

let filters = [filter1, filter2, filter3]

// Use:
let dest = BoxxIO.init(element: originImage, filters: filters)
ImageView.image = try? dest.output()

// OR Use:
ImageView.image = try? originImage.makeGroup(filters: filters)

// OR Use Operator:
ImageView.image = originImage -->>> filters
```

- 📸 Camera capture generates pictures.

```swift
// Add an edge detection filter:
let filter = C7EdgeGlow(lineColor: .red)

// Add a particle filter:
let filter2 = C7Granularity(grain: 0.8)

// Generate camera collector:
let camera = C7CollectorCamera.init(delegate: self)
camera.captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
camera.filters = [filter, filter2]

extension CameraViewController: C7CollectorImageDelegate {
    func preview(_ collector: C7Collector, fliter image: C7Image) {
        DispatchQueue.main.async {
            self.originImageView.image = image
        }
    }
}
```

- Local video or Network video are simply apply with filters.
  - 🙄 For details, See [PlayerViewController](https://github.com/yangKJ/Harbeth/blob/master/Demo/Harbeth-iOS-Demo/Modules/PlayerViewController.swift).
  - You can also extend this by using [BoxxIO](https://github.com/yangKJ/Harbeth/blob/master/Sources/Basic/Outputs/BoxxIO.swift) to filter the collected `CVPixelBuffer`.

```swift
lazy var video: C7CollectorVideo = {
    let videoURL = URL.init(string: "Link")!
    let asset = AVURLAsset.init(url: videoURL)
    let playerItem = AVPlayerItem.init(asset: asset)
    let player = AVPlayer.init(playerItem: playerItem)
    let video = C7CollectorVideo.init(player: player, delegate: self)
    video.filters = [C7ColorMatrix4x4(matrix: Matrix4x4.Color.sepia)]
    return video
}()

self.video.play()

extension PlayerViewController: C7CollectorImageDelegate {
    func preview(_ collector: C7Collector, fliter image: C7Image) {
        self.originImageView.image = image
        // Simulated dynamic effect.
        if let filter = self.tuple?.callback?(self.nextTime) {
            self.video.filters = [filter]
        }
    }
}
```

### Advanced usage

<p align="left">
<img src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/Mix.png" width="250" hspace="15px">
</p>

- Operator chain processing

```swift
/// 1.Convert to BGRA
let filter1 = C7ColorConvert(with: .bgra)

/// 2.Adjust the granularity
let filter2 = C7Granularity(grain: 0.8)

/// 3.Adjust white balance
let filter3 = C7WhiteBalance(temperature: 5555)

/// 4.Adjust the highlight shadows
let filter4 = C7HighlightShadow(shadows: 0.4, highlights: 0.5)

/// 5.Combination operation
filterImageView.image = originImage ->> filter1 ->> filter2 ->> filter3 ->> filter4
```

-----

<p align="left">
<img src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/Mix2.png" width="250" hspace="15px">
</p>

- Batch processing

```swift
/// 1.Convert to RBGA
let filter1 = C7ColorConvert(with: .rbga)

/// 2.Adjust the granularity
let filter2 = C7Granularity(grain: 0.8)

/// 3.Soul effect
let filter3 = C7SoulOut(soul: 0.7)

/// 4.Combination operation
let group: [C7FilterProtocol] = [filter1, filter2, filter3]

/// 5.Get the result
filterImageView.image = try? originImage.makeGroup(filters: group)
```

**Both methods can handle multiple filter schemes, depending on your mood.✌️**

----

### Design
- For example, how to design an soul filter.🎷

<p align="left">
<img src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/Soul.gif" width="250" hspace="30px">
</p>

1. Accomplish `C7FilterProtocal`

```swift
public struct C7SoulOut: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.5)
    
    /// The adjusted soul, from 0.0 to 1.0, with a default of 0.5
    @ZeroOneRange public var soul: Float = range.value
    public var maxScale: Float = 1.5
    public var maxAlpha: Float = 0.5
    
    public var modifier: Modifier {
        return .compute(kernel: "C7SoulOut")
    }
    
    public var factors: [Float] {
        return [soul, maxScale, maxAlpha]
    }
    
    public init(soul: Float = range.value, maxScale: Float = 1.5, maxAlpha: Float = 0.5) {
        self.soul = soul
        self.maxScale = maxScale
        self.maxAlpha = maxAlpha
    }
}
```

2. Configure additional required textures.

3. Configure the passed parameter factor, only supports `Float` type.
    - This filter requires three parameters: 
        - `soul`: The adjusted soul, from 0.0 to 1.0, with a default of 0.5
        - `maxScale`: Maximum soul scale.
        - `maxAlpha`: The transparency of the max soul.

4. Write a kernel function shader based on parallel computing.

```metal
kernel void C7SoulOut(texture2d<half, access::write> outputTexture [[texture(0)]],
                      texture2d<half, access::sample> inputTexture [[texture(1)]],
                      constant float *soulPointer [[buffer(0)]],
                      constant float *maxScalePointer [[buffer(1)]],
                      constant float *maxAlphaPointer [[buffer(2)]],
                      uint2 grid [[thread_position_in_grid]]) {
    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
    const half4 inColor = inputTexture.read(grid);
    const float x = float(grid.x) / outputTexture.get_width();
    const float y = float(grid.y) / outputTexture.get_height();
    
    const half soul = half(*soulPointer);
    const half maxScale = half(*maxScalePointer);
    const half maxAlpha = half(*maxAlphaPointer);
    
    const half alpha = maxAlpha * (1.0h - soul);
    const half scale = 1.0h + (maxScale - 1.0h) * soul;
    
    const half soulX = 0.5h + (x - 0.5h) / scale;
    const half soulY = 0.5h + (y - 0.5h) / scale;
    
    const half4 soulMask = inputTexture.sample(quadSampler, float2(soulX, soulY));
    const half4 outColor = inColor * (1.0h - alpha) + soulMask * alpha;
    
    outputTexture.write(outColor, grid);
}
```

5. Simple to use, since my design is based on a parallel computing pipeline, images can be generated directly.

```swift
/// Add a soul out of the body filter.
let filter = C7SoulOut(soul: 0.5, maxScale: 2.0)

/// Display directly in ImageView.
ImageView.image = originImage ->> filter
```

6. As for the animation above, it is also very simple, add a timer, and then change the value of `soul` and you are done, simple.

----

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

-----

### License
Harbeth is available under the [MIT](LICENSE) license. See the [LICENSE](LICENSE) file for more info.

-----
