# ATMetalBand

![x](Screenshot/launch.jpeg)

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-brightgreen.svg?style=flat&colorA=28a745&&colorB=4E4E4E)](https://github.com/yangKJ/ATMetalBand)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/ATMetalBand.svg?style=flat&label=ATMetalBand&colorA=28a745&&colorB=4E4E4E)](https://cocoapods.org/pods/ATMetalBand)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/OpencvQueen.svg?style=flat&label=OpenCV&colorA=28a745&&colorB=4E4E4E)](https://cocoapods.org/pods/OpencvQueen)
![Platform](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20watchOS-4E4E4E.svg?colorA=28a745)

[**ATMetalBand**](https://github.com/yangKJ/ATMetalBand) is mainly used to learn image processing related records, such as [OpenCV 4.0.1](https://docs.opencv.org/4.0.1/modules.html), [Metal](https://developer.apple.com/metal), [OpenGL](https://www.opengl.org) graphic filter processing etc.

<font color=red>**Graphics processing And Filter production.👒👒👒**</font>

-------

## Features
🟣At the moment, the most important features of ATMetalBand can be summarized as follows:

- [OpenCV module](https://github.com/yangKJ/OpencvQueen):
	- [x] Hough line detection and correction text.
	- [x] Feature extraction processing.
	- [x] Repair old photos.
	- [x] Repair the picture to remove the watermark.
	- [x] Maximum area cut.
	- [x] Morphology operation.
	- [x] Blurred skin whitening treatment.
 	- [x] Picture perspective or blend.
	- [x] Modify brightness and contrast.
	- [x] Picture mosaic tile.

- Some

<p align="left">
<img src="Screenshot/ZoomBlur.gif" width="200" hspace="1px">
<img src="https://p6-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/eed0fef004d941bf926efb31ee191a83~tplv-k3u1fbpfcp-watermark.image?" width="200" hspace="30px">
<img src="https://p6-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/9c40c28f123642468a9f2211c55999a8~tplv-k3u1fbpfcp-watermark.image?" width="200" hspace="1px">
</p>

- Currently there are 6 modules of filter effects:
   - Blend: Image fusion technology
   - Blur: Blur effect
   - ColorProcess: basic pixel processing of images
   - Effect: Effect processing
   - Lookup: Lookup table filter
   - Shape: Image shape size related

- A total of `80+` kinds of filters are currently available.

### Custom filters
- Accomplish `C7FilterProtocal`

```
public protocol C7FilterProtocol {
    /// Encoder type and corresponding function name
    ///
    /// Compute requires the corresponding `kernel` function name
    /// Render requires a `vertex` shader function name and a `fragment` shader function name
    var modifier: Modifier { get }
    
    /// MakeBuffer
    /// Set modify parameter factor, you need to convert to `Float`.
    var factors: [Float] { get }
    
    /// Multiple input source extensions
    /// An array containing the `MTLTexture`
    var otherInputTextures: C7InputTextures { get }
    
    /// Change the size of the output image
    func outputSize(input size: C7Size) -> C7Size
}
```

- Write a kernel function shader based on parallel computing.
- Configure the passed parameter factor, only supports `Float` type.
- Configure additional required textures.

### Example

```
public struct C7Crop: C7FilterProtocol {
    /// The adjusted contrast, from 0 to 1.0, with a default of 0.0
    public var origin: C7Point2D = C7Point2DZero
    
    public var width: Int = 0
    public var height: Int = 0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Crop")
    }
    
    public var factors: [Float] {
        return [origin.x, origin.y]
    }
    
    public func outputSize(input size: C7Size) -> C7Size {
        let w: Int = width > 0 ? width : size.width
        let h: Int = height > 0 ? height : size.height
        return (width: w, height: h)
    }
    
    public init() { }
}
```

### CocoaPods

- If you want to import [**Metal**](https://github.com/yangKJ/ATMetalBand) module, you need in your Podfile: 

```
pod 'ATMetalBand'
```

- If you want to import [**OpenCV**](https://github.com/yangKJ/OpencvQueen) image module, you need in your Podfile: 

```
pod 'OpencvQueen'
```

### Remarks

> The general process is almost like this, the Demo is also written in great detail, you can check it out for yourself.🎷
>
> [**ATMetalBandDemo**](https://github.com/yangKJ/ATMetalBand)
>
> Tip: If you find it helpful, please help me with a star. If you have any questions or needs, you can also issue.
>
> Thanks.🎇

### About the author
- 🎷 **E-mail address: [yangkj310@gmail.com](yangkj310@gmail.com) 🎷**
- 🎸 **GitHub address: [yangKJ](https://github.com/yangKJ) 🎸**

-----

### License
ATMetalBand is available under the [MIT](LICENSE) license. See the [LICENSE](LICENSE) file for more info.

-----
