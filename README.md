# Harbeth

| Animated | Still |
| :---: | :---: |
|<img width=230px src="Screenshot/Soul.gif" />|<img width=230px src="Screenshot/Mix2.png" />|

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-brightgreen.svg?style=flat&colorA=28a745&&colorB=4E4E4E)](https://github.com/yangKJ/Harbeth)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Harbeth.svg?style=flat&label=Harbeth&colorA=28a745&&colorB=4E4E4E)](https://cocoapods.org/pods/Harbeth)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/OpencvQueen.svg?style=flat&label=OpenCV&colorA=28a745&&colorB=4E4E4E)](https://cocoapods.org/pods/OpencvQueen)
![Platform](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20watchOS-4E4E4E.svg?colorA=28a745)
 
[**Harbeth**](https://github.com/yangKJ/Harbeth) is a tiny set of utils and extensions over Apple's Metal framework dedicated to make your Swift GPU code much cleaner and let you prototype your pipelines faster.

-------

English | [**简体中文**](README_CN.md)

## Features
🟣 At the moment, the most important features of metal moudle can be summarized as follows:

- Support more platform system, macOS and iOS, both UIKit/AppKit and SwiftUI.
- High performance quickly add filters at these sources:    
  - UIImage, NSImage, CIImage, CGImage, CMSampleBuffer, CVPixelBuffer.
- The built-in metal kernel filters is roughly divided into the following modules:    
  - [Blend](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Blend), [Blur](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Blur), [Pixel](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Pixel), [Coordinate](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Coordinate), [Lookup](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Lookup), [Matrix](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Matrix), [Shape](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Shape), [Generator](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Generator).
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

- 🚗 Original code.
```swift
lazy var ImageView: UIImageView = {
    let imageView = UIImageView(image: originImage)
    imageView.layer.borderColor = R.color("background2")?.cgColor
    imageView.layer.borderWidth = 0.5
    return imageView
}()

ImageView.image = originImage
```

- 🎷 Code zero intrusion add filter function.

```swift
let filter1 = C7ColorMatrix4x4(matrix: Matrix4x4.Color.sepia)
let filter2 = C7Granularity(grain: 0.8)
let filter3 = C7SoulOut(soul: 0.7)

let filters = [filter1, filter2, filter3]

// Use:
let dest = BoxxIO.init(element: originImage, filters: filters)
// Synchronize do something..
ImageView.image = try? dest.output()

// Asynchronous do something..
dest.transmitOutput(success: { [weak self] image in
    DispatchQueue.main.async {
        self?.ImageView.image = image
    }
})

// OR Use:
ImageView.image = try? originImage.makeGroup(filters: filters)

// OR Use Operator:
ImageView.image = originImage ->> filter1 ->> filter2 ->> filter3
```

### Camera

- 📸 Camera capture generates pictures.

```swift
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
  - You can also extend this by using [BoxxIO](https://github.com/yangKJ/Harbeth/blob/master/Sources/Basic/Outputs/BoxxIO.swift) to filter the collected `CVPixelBuffer`.

```swift
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
- For the direct use [FiterImage](https://github.com/yangKJ/Harbeth/tree/master/Sources/SwiftUI/FiterImage), it is just a simple implementation.
- The SwiftUI API is still in-progress and may not be production ready. We're looking for help! 🤲

```swift
let filters: [C7FilterProtocol] = [
    CIHighlight(highlight: intensity),
    C7WaterRipple(ripple: intensity),
]
FilterImage(with: inputImage, filters: filters, builder: {
    Image(c7Image: $0)
})
```

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

-----

### License
Harbeth is available under the [MIT](LICENSE) license. See the [LICENSE](LICENSE) file for more info.

-----
