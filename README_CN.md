# Harbeth

![x](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/3eaa018dedb9433bb51f408f5bb73faf~tplv-k3u1fbpfcp-jj-mark:0:0:0:0:q75.image#?w=600&h=234&s=31350&e=jpg&b=f5f4f4)

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-brightgreen.svg?style=flat&colorA=28a745&&colorB=4E4E4E)](https://github.com/yangKJ/Harbeth)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Harbeth.svg?style=flat&label=Harbeth&colorA=28a745&&colorB=4E4E4E)](https://cocoapods.org/pods/Harbeth)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/OpencvQueen.svg?style=flat&label=OpenCV&colorA=28a745&&colorB=4E4E4E)](https://cocoapods.org/pods/OpencvQueen)
![Platform](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20watchOS-4E4E4E.svg?colorA=28a745)
 
[**Harbeth**](https://github.com/yangKJ/Harbeth) 是基于GPU快速实现图片or视频注入滤镜特效，代码零侵入实现图像显示and视频导出功能，支持iOS系统和macOS系统。👒👒👒

-------

[**中文详细介绍**](https://juejin.cn/post/7066964198596542471)

## 功能清单
- 支持macOS和iOS平台系统，也支持SwiftUI使用；
- 高性能在如下数据源快速添加过滤器效果：  
  UIImage, NSImage, CIImage, CGImage, CMSampleBuffer, CVPixelBuffer
- 支持两种查找滤镜 [LUTs](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Lookup/C7LookupTable.swift) 和 [Cube](https://github.com/yangKJ/Harbeth/tree/master/Sources/CoreImage/CIColorCube.swift) 来定制专属滤镜；
- 支持相机采集特效和视频播放加入滤镜效果；
- Metal滤镜部分大致分为以下几个模块：  
  [Blend](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Blend), [Blur](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Blur), [Color](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Color), [Combination](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Combination), [DistortionWarp](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/DistortionWarp), [EdgeDetail](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/EdgeDetail), [Generators](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Generators), [Geometric Transform](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Geometric), [Lookup](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Lookup), [Matrix](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Matrix), [Other](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Other), [Stylization](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Stylization), [Utility](https://github.com/yangKJ/Harbeth/tree/master/Sources/Compute/Utility).
- 支持使用 [Kakapos](https://github.com/yangKJ/Kakapos) 库对已有视频添加滤镜并导出；
- 支持系统 MetalPerformanceShaders 和 CoreImage 滤镜混合使用；

#### **总结下来目前将近两百种滤镜供您使用。✌️**

## 如何使用
- 代码零侵入注入滤镜功能，

```
原始代码：
ImageView.image = originImage

🎷注入滤镜代码：
let filter = C7ColorMatrix4x4(matrix: Matrix4x4.Color.sepia)
let filter2 = C7Granularity(grain: 0.8)
let filter3 = C7SoulOut(soul: 0.7)

let filters = [filter, filter2, filter3]

ImageView.image = try? originImage.makeGroup(filters: filters)

// 也可数据源模式使用
let dest = HarbethIO.init(element: originImage, filters: filters)

// 同步处理
ImageView.image = try? dest.output()

// 异步处理
dest.transmitOutput(success: { [weak self] image in
    DispatchQueue.main.async {
        self?.ImageView.image = image
    }
})

// 或者运算符操作
ImageView.image = originImage -->>> filters

// 甚至函数式编程高级用法
filters.forEach { originImage = originImage ->> $0 }
ImageView.image = originImage

// 甚至不定参数使用
ImageView.image = originImage.filtering(filter, filter2, filter3)

怎么使用就看你的心情了!!!🫤
```

- 相机采集生成图片

```
// 注入边缘检测滤镜:
let filter = C7EdgeGlow(lineColor: .red)
// 注入颗粒感滤镜:
let filter2 = C7Granularity(grain: 0.8)

// 生成相机采集器:
let camera = C7CollectorCamera.init(delegate: self)
camera.captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
camera.filters = [filter, filter2]

extension CameraViewController: C7CollectorImageDelegate {
    func preview(_ collector: C7Collector, fliter image: C7Image) {
        // 显示注入滤镜之后的图像
    }
}
```

- 本地视频 or 网络视频简单注入滤镜
  - 🙄 详细请参考[PlayerViewController](https://github.com/yangKJ/Harbeth/blob/master/MetalDemo/Modules/PlayerViewController.swift)
  - 您也可以自己去扩展，使用`HarbethIO`对采集的`CVPixelBuffer`进行滤镜注入处理。

```
lazy var video: C7CollectorVideo = {
    let videoURL = URL.init(string: "https://mp4.vjshi.com/2017-06-03/076f1b8201773231ca2f65e38c34033c.mp4")!
    let asset = AVURLAsset.init(url: videoURL)
    let playerItem = AVPlayerItem(asset: asset)
    let player = AVPlayer.init(playerItem: playerItem)
    let video = C7CollectorVideo.init(player: player, delegate: self)
    let filter = C7ColorMatrix4x4(matrix: Matrix4x4.Color.sepia)
    video.filters = [filter]
    return video
}()

// 播放视频
self.video.play()

extension PlayerViewController: C7CollectorImageDelegate {
    func preview(_ collector: C7Collector, fliter image: C7Image) {
        self.originImageView.image = image
        if let filter = self.tuple?.callback?(self.nextTime) {
            self.video.filters = [filter]
        }
    }
}
```

### SwiftUI Support
- 直接使用即可 [HarbethView](https://github.com/yangKJ/Harbeth/blob/master/Sources/SwiftUI/HarbethView.swift)
- 这个API可能也暂时不够稳定，暂时先这样吧！
- 当然你也可以来完善它，感谢！ 🤲

```swift
let filters: [C7FilterProtocol] = [
    CIHighlight(highlight: intensity),
    C7WaterRipple(ripple: intensity),
]
HarbethView(image: inputImage, filters: filters, content: { image in
    image.resizable()
        .aspectRatio(contentMode: .fit)
}, async: false)
```

### Metal 滤镜分组

#### 🎨 颜色调整
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

#### 🌫️ 模糊效果
- C7BilateralBlur（双边模糊）
- C7CircleBlur（圆形模糊）
- C7GaussianBlur（高斯模糊）
- C7MeanBlur（均值模糊）
- C7MotionBlur（运动模糊）
- C7RedMonochromeBlur（红色单色模糊）
- C7ZoomBlur（缩放模糊）

#### 🔄 混合模式
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

#### 🔍 边缘与细节
- C7Canny（边缘检测）
- C7ComicStrip（漫画效果）
- C7Crosshatch（交叉线）
- C7Granularity（颗粒感）
- C7Sobel（索贝尔边缘检测）
- C7Sharpen（锐化）
- C7Sketch（素描）
- C7ThresholdSketch（阈值素描）

#### 🌀 扭曲与变形
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

#### 🎭 风格化效果
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

#### 📊 矩阵处理
- C7ColorMatrix4x4（4x4颜色矩阵）
- C7ColorMatrix4x5（4x5颜色矩阵）
- C7ColorVector4（4维颜色向量）
- C7ConvolutionMatrix3x3（3x3卷积矩阵）
- C7EdgeGlow（边缘发光）
- C7RGBADilation（RGBA扩张）

#### 🎛️ 实用工具
- C7ChromaKey（色度键控）
- C7DepthLuminance（深度亮度）
- C7HighlightShadow（高光阴影）
- C7HighlightShadowTint（高光阴影色调）
- C7Levels（色阶）
- C7Luminance（亮度）
- C7LuminanceRangeReduction（亮度范围压缩）
- C7LuminanceThreshold（亮度阈值）
- C7Opacity（不透明度）

#### 📐 几何变形
- C7Crop（裁剪）
- C7Flip（翻转）
- C7Mirror（镜像）
- C7Resize（调整大小）
- C7Rotate（旋转）
- C7Transform（变换）

#### 🎨 生成器
- C7ColorGradient（颜色渐变）
- C7SolidColor（纯色）

#### 📋 查找表
- C7LookupSplit（分屏查找表）
- C7LookupTable（查找表）

#### 🔗 组合滤镜
- C7CombinationBeautiful（美颜组合）
- C7CombinationBilateralBlur（双边模糊组合）

#### 🎚️ 其他效果
- C7Grayed（灰度化）
- C7Haze（雾霾）
- C7Pow（幂次调整）
- C7Vignette（暗角）

查找建议：
1. 需要颜色调整 → 查看颜色调整分类
2. 需要模糊效果 → 查看模糊效果分类
3. 需要混合图层 → 查看混合模式分类
4. 需要艺术风格 → 查看风格化效果分类
5. 需要变形扭曲 → 查看扭曲与变形分类
6. 需要边缘检测 → 查看边缘与细节分类
7. 需要几何变换 → 查看几何变换分类

### CocoaPods Install

- 如果要导入 [Metal](https://github.com/yangKJ/Harbeth) 模块，则需要在 Podfile 中：

```
pod 'Harbeth'
```

- 如果要导入 [**OpenCV**](https://github.com/yangKJ/OpencvQueen) 图像模块，则需要在 Podfile 中：

```
pod 'OpencvQueen'
```

### Swift Package Manager

```
dependencies: [
    .package(url: "https://github.com/yangKJ/Harbeth.git", branch: "master"),
]
```

### 关于作者
- 🎷 **邮箱地址：[ykj310@126.com](ykj310@126.com) 🎷**
- 🎸 **GitHub地址：[yangKJ](https://github.com/yangKJ) 🎸**
- 🎺 **掘金地址：[茶底世界之下](https://juejin.cn/user/1987535102554472/posts) 🎺**
- 🚴🏻 **简书地址：[77___](https://www.jianshu.com/u/c84c00476ab6) 🚴🏻**

----

当然如果您这边觉得好用对你有所帮助，请给作者一点辛苦的打赏吧。再次感谢感谢！！！  
有空我也会一直更新维护优化 😁😁😁

<p align="left">
<img src="https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/bfb6d859b345472aa3a4bf224dee5969~tplv-k3u1fbpfcp-jj-mark:0:0:0:0:q75.image#?w=828&h=828&s=112330&e=jpg&b=59be6d" width=30% hspace="1px">
<img src="https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/6f4bb3a1b49d427fbe0405edc6b7f7ee~tplv-k3u1fbpfcp-jj-mark:0:0:0:0:q75.image#?w=1200&h=1200&s=185343&e=jpg&b=3977f5" width=30% hspace="15px">
</p>

**救救孩子吧，谢谢各位老板。**

🥺

-----
