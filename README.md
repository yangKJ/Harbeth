# Harbeth

| Soul | Combination |
| :---: | :---: |
|<img width=230px src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/Soul.gif" />|<img width=230px src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/Mix2.png" />|

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-brightgreen.svg?style=flat&colorA=28a745&&colorB=4E4E4E)](https://github.com/yangKJ/Harbeth)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Harbeth.svg?style=flat&label=Harbeth&colorA=28a745&&colorB=4E4E4E)](https://cocoapods.org/pods/Harbeth)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Kakapos.svg?style=flat&label=Kakapos&colorA=28a745&&colorB=4E4E4E)](https://cocoapods.org/pods/Kakapos)
![Platform](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20watchOS-4E4E4E.svg?colorA=28a745)
 
[**Harbeth**](https://github.com/yangKJ/Harbeth) is a high-performance Swift library for Apple-platform image and frame processing. Built on Metal technology, it integrates GPU filters, frame pipelines, and Metal Performance Shaders into a reusable processing core.

Harbeth is best understood as a GPU image and frame processing core for Apple platforms. It works with still images, Metal textures, pixel buffers, and sample buffers, so it can be embedded into real product pipelines such as photo editing, live capture, video playback, and frame-by-frame video processing.

The camera and video examples in this repository are integration demos: Harbeth provides the processing core and reference wiring, while your app remains responsible for source acquisition policy, media orchestration, persistence, and product-specific workflows.

This library is highly inspired by [GPUImage](https://github.com/BradLarson/GPUImage).

-------

English | [**简体中文**](README_CN.md)

## Features
🟣 Harbeth offers a comprehensive set of features for building fast, reusable image and frame processing pipelines:

- **Cross-Platform Support**: Runs seamlessly on iOS, macOS, tvOS, and watchOS, supporting both UIKit/AppKit and SwiftUI frameworks.
- **Versatile Input Sources**: Apply filters to a wide range of image and video sources including MTLTexture, UIImage, NSImage, CGImage, CMSampleBuffer, and CVPixelBuffer.
- **Rich Filter Ecosystem**: Over 200+ built-in filters organized into intuitive categories, covering everything from basic color adjustments to advanced artistic effects.
- **Advanced Integration**: Leverage the power of [Metal Performance Shaders (MPS)](https://github.com/yangKJ/Harbeth/tree/master/Sources/MPS) for high-performance filtering alongside Harbeth's native Metal filter pipeline.
- **Metal-Powered Rendering**: Texture-first processing and rendering operations are accelerated by Metal, ensuring smooth real-time performance even with complex filter chains.
- **Custom Filter Support**: Easily create and integrate custom filters using LUTs has `1D Lookup Tables`、`2D Lookup Tables`、`3D Cube Files` And `Multi Zone Tables`, or custom Metal shaders. Create advanced combination filters by subclassing `C7CombinationBase` for complex, multi-step effects.
- **Real-Time Frame Processing**: Apply filter chains to live frame sources such as capture pipelines, video playback, and other low-latency flows.
- **Reference Video Integration**: Process local and network video frames through the integrated [Kakapos](https://github.com/yangKJ/Kakapos) examples as reference wiring, while keeping product orchestration in the host app.
- **Intuitive API**: Enjoy a clean, Swift-friendly API with chainable filter operations and operator overloading for concise, expressive code.
- **Performance Optimization**: Benefit from automatic texture pooling, memory management, and multi-encoder support for optimal performance across devices.
- **Extensive Documentation**: Comprehensive documentation and demo projects to help you get started quickly and make the most of Harbeth's capabilities.
- **SwiftUI integration**: Native support for SwiftUI framework.

### Core Capabilities

Harbeth is designed as a capability-first processing core. The current repository is best understood as four composable layers:

- **Source ingestion**: image, texture, pixel buffer, and sample buffer inputs can enter the same Metal-based processing pipeline.
- **Filter execution**: color, blur, blend, geometry, optics, LUT, and MPS-backed operations can be chained as reusable technical capabilities.
- **Frame rendering**: texture-first and frame-first outputs support interactive rendering, stable reusable derivatives, export outputs, and readback-oriented delivery.
- **Correction and replay**: render profiles, frame metadata, cache identity, and reusable derivative contracts support repeated rendering and higher-level host workflows.

### ⚡ Performance Advantage

Harbeth leverages Metal GPU acceleration to deliver exceptional performance, especially when processing complex filter chains:

<p align="left">
<img src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/FilterChainPerformance.png" width=75% />
</p>

**Key Performance Benefits:**
- **5x Faster**: GPU processing is up to 5x faster than CPU for complex filter chains
- **Excellent Scalability**: GPU time grows slowly (3.2ms → 15.8ms) while CPU time increases linearly (12.5ms → 96.8ms)
- **Real-time Capable**: Process up to 10 filters while maintaining 60 FPS (16.67ms threshold)
- **Efficient Resource Usage**: Automatic texture pooling and memory management optimize performance across devices

### 🎨 Filter System
Harbeth offers a comprehensive filter classification to meet various image processing needs:
- **Color Adjustment**: Brightness, contrast, saturation, exposure, white balance, etc.
- **Blur Effects**: Gaussian blur, bilateral blur, noise reduction, motion blur, zoom blur, etc.
- **Blend Modes**: Normal, multiply, screen, overlay, hard light, etc.
- **Edge & Detail**: Sharpen, unsharp mask, edge detection, sketch, comic strip effect, etc.
- **Distortion & Warp**: Bulge, pinch, swirl, water ripple, glass sphere, etc.
- **Geometry & Optics**: Lens distortion correction, chromatic aberration correction, vignette correction, defringe, diffraction correction, quad rectification, perspective and 3D transforms.
- **Stylization**: Oil painting, cartoon, glitch effect, split screen, soul out, etc.
- **Geometric Transform**: Crop, flip, rotate, resize, Lanczos resize, etc.
- **Matrix Processing**: 3x3 convolution matrix, 4x4 color matrix, 4x5 color matrix, etc.
- **Utility**: Chroma key, highlight shadow, levels, luminance threshold, etc.
- **Generators**: Solid color, color gradient, etc.
- **Lookup Tables**: LUT-based color adjustments and CUBE file support.
- **Blit Operations**: Copy region, crop, generate mipmaps.
- **Metal Performance Shaders**: High-performance MPS filters
- **Render Vertex Fragment**: The Render module provides low-level rendering capabilities using vertex and fragment shaders.

#### **A total of 200+ kinds of built-in filters are currently available.✌️**

### Integration Scope

- **Harbeth provides**: GPU filters, filter chaining, texture / image / pixelBuffer / sampleBuffer processing, LUT pipelines, MPS / Metal integration, SwiftUI rendering surfaces, and reference wiring for frame-based integrations.
- **Your app provides**: source acquisition policy, media orchestration, persistence, presentation surfaces, and all product-specific business logic.
- **Commercial integration**: If you need private LUTs, branded filter packs, real-time camera/video tuning, or custom Metal kernels, use the open-source examples as the technical baseline and discuss a private integration scope with the maintainer.

### Geometry and Optics

Harbeth also provides a reusable correction and transform layer for editor-grade geometry and optics workflows:

- **Lens correction**: distortion, chromatic aberration, vignette, diffraction, defringe, and sharpness-falloff compensation.
- **Transform correction**: affine, perspective, quad rectify, quad warp, and 3D projection transforms.
- **Profile-driven composition**: `LensProfile` and `OpticsSettings` can assemble multiple optics corrections into a stable pipeline.
- **Guide-driven upright**: `GuidedUpright` can turn vertical and horizontal guide lines into a recommended rectify transform.

## Requirements

| iOS Target | macOS Target | Xcode Version | Swift Version |
|:---:|:---:|:---:|:---:|
| iOS 10.0+ | macOS 10.13+ | Xcode 10.0+ | Swift 5.0+ |

## Usage

### Source and Output Types

Harbeth supports multiple source types and more than one output shape:

- Use `UIImage`, `NSImage`, `CGImage`, `MTLTexture`, `CVPixelBuffer`, or `CMSampleBuffer` as processing inputs.
- Use `output()` for the primitive image path.
- Use `renderTexture(profile:)` / `renderFrame(profile:)` for the frame-first filters path.
- Use `renderTexture(recipe:)` / `renderFrame(recipe:)` for recipe-driven execution.
- Use `renderTransitionTexture(_:)` / `renderTransitionFrame(_:)` for transition primitives.

### Render Profiles and Frame Rendering

The render profile expresses technical intent instead of product UI state:

- `interactiveLatency`: lowest-latency rendering for interactive adjustment loops.
- `responseLatency`: fast first useful response with reusable texture output.
- `stablePreview`: stable reusable derivative for display and repeated viewing.
- `inspectionQuality`: higher-fidelity derivative for closer inspection.
- `exportQuality`: full-quality output for export pipelines.
- `readbackQuality`: full-quality output optimized for CPU-side readback.

```swift
let io = HarbethIO(element: inputImage, filters: filters)

let interactiveTexture = try io.renderTexture(profile: .interactiveLatency)
let stableFrame = try io.renderFrame(profile: .stablePreview)
let exportTexture = try io.renderTexture(profile: .exportQuality)
```

### Execution Core

Harbeth now exposes a more explicit execution core for host apps that need stable contracts instead of one-off image output:

- `Shared.shared`: the default global runtime owner for `Device`, `HarbethContext`, texture pooling, command queue access, and lifecycle reset.
- `HarbethContext.shared`: the default execution context facade for render pipeline cache, sampler cache, and execution diagnostics.
- `RenderedFrame`: texture-first output with stable metadata such as `renderIntent`, `sourceTier`, `alphaType`, `pixelFormat`, `orientation`, and cache identity.
- `HarbethImageNode`: immutable lazy texture graph nodes for source, filters, recipe, transition, kernel, and layer composition paths.
- `HarbethKernelDescriptor`: lightweight technical metadata for function identity, parameter fingerprinting, input texture usage, pass descriptors, resource behavior, and alpha/output contracts.
- `HarbethRenderTask`: observable GPU task handles for texture-first rendering, including command-buffer status, completion observation, diagnostics, and explicit waiting.
- `RenderOutputContract`: explicit alpha, color-space, and pixel-format intent for diagnostics and conservative planning.
- `RenderOptimizationPlan`: conservative stage metadata for transient texture reuse, persistent outputs, estimated texture cost, readback boundaries, and format conversion decisions. The texture-first execution path can use the plan to prewarm reusable render targets without changing visual output.

```swift
let runtime = Shared.shared
let context = runtime.defaultContext
let frame = try HarbethIO(element: inputTexture, filters: filters)
    .renderFrame(profile: .stablePreview)

let cacheSnapshot = context.debugCacheSnapshot()
let semantic = frame.semantic
let replayContract = frame.replayBaseContract
```

```swift
let task = try HarbethIO(element: inputTexture, filters: filters)
    .startRenderTextureTask(profile: .stablePreview)

task.observeCompletion { task in
    print(task.commandBufferStatus)
}

let outputTexture = try task.output()
let diagnostics = task.diagnostics
```

```swift
let node = HarbethImageNode.filters(
    input: .source(.texture(inputTexture)),
    filters: [C7Brightness(brightness: 0.1), C7Contrast(contrast: 1.05)]
)

let nodeFrame = try HarbethIO(element: inputTexture, filters: [])
    .renderFrame(node: node, profile: .stablePreview)
let nodeDiagnostics = try HarbethIO(element: inputTexture, filters: [])
    .renderDiagnostics(node: node)
```

### Geometry, Local Mask, and Transition Primitives

Harbeth now includes reusable editor-grade primitives without turning the core into a product-specific editor:

- `ImageCropRegion`, `ImageTransformRecipe`, `AspectPolicy`, `CoordinateSpace`
- `MaskDescriptor`, `MaskBlendMode`, `MaskFeatherPolicy`, `LocalEffectRecipe`
- `ImageLayer`, `LayerCompositeRecipe`, and `LayerBlendMode` for single-frame texture compositing with normalized placement, opacity, masks, corner radius, and common blend modes
- `TransitionKernel` with built-in dissolve, directional wipe, luma wipe, and displacement transitions
- `EditRecipe` for lightweight preview/final render contracts

```swift
let geometry = ImageTransformRecipe(
    cropRegion: ImageCropRegion(
        rect: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
        coordinateSpace: .normalized
    ),
    targetSize: CGSize(width: 1080, height: 1080),
    aspectPolicy: .fill
)
let mask = MaskDescriptor(texture: maskTexture, opacity: 0.8)
let recipe = EditRecipe(
    geometry: geometry,
    filters: [C7NoiseReduction(radius: 4, amount: 0.2, edgePreservation: 0.75)],
    localEffects: [
        LocalEffectRecipe(
            filters: [C7UnsharpMask(radius: 2, intensity: 0.6, threshold: 0.02)],
            mask: mask
        )
    ],
    previewProfile: .stablePreview,
    finalProfile: .exportQuality
)

let io = HarbethIO(element: inputImage, filters: [])
let previewFrame = try io.renderFrame(recipe: recipe, mode: .preview)
let finalTexture = try io.renderTexture(recipe: recipe, mode: .final)
```

```swift
let transition = TransitionRecipe(
    from: .texture(fromTexture),
    to: .texture(toTexture),
    kernel: .directionalWipe(angleDegrees: 90, softness: 0.08),
    progress: 0.35,
    profile: .stablePreview
)

let transitionFrame = try HarbethIO(element: fromTexture, filters: [])
    .renderTransitionFrame(transition)
```

```swift
let composite = LayerCompositeRecipe(
    background: .texture(backgroundTexture),
    layers: [
        ImageLayer(
            content: .texture(layerTexture),
            normalizedFrame: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
            opacity: 0.9,
            blendMode: .sourceOver,
            mask: MaskDescriptor(texture: maskTexture)
        )
    ]
)

let compositeTexture = try HarbethIO(element: backgroundTexture, filters: [])
    .renderTexture(node: .layerComposite(composite))
```

### 🎨 Real-time Filter Effects

Harbeth delivers stunning visual effects with GPU-accelerated real-time processing:

<p align="left">
<img src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/ShiftGlitch.gif" width=35% hspace="10px" title="C7ShiftGlitch: Creates dynamic RGB channel separation with glitch art aesthetics">
<img src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/EdgeGlow.gif" width=35% hspace="10px" title="C7EdgeGlow: Detects edges and adds neon glow effects in real-time">
</p>

**✨ Featured Filters:**

| Filter | Effect | Use Case |
|--------|--------|----------|
| **C7ShiftGlitch** | RGB channel displacement with horizontal shift | Digital art, retro VHS effects, creative transitions |
| **C7EdgeGlow** | Edge detection + neon glow overlay | Photo enhancement, artistic portraits, night photography |

**🚀 Key Advantages:**
- **Zero-latency rendering** - Effects applied in real-time at 60 FPS
- **Chainable effects** - Combine multiple filters without performance degradation
- **GPU-optimized** - Metal-powered processing for smooth animations
- **One-line implementation** - Simple API for complex visual effects

### Image Processing

Apply stunning filters to images with an elegant, zero-intrusion API design:

#### ✨ Quick Start - Three Ways to Apply Filters

**Method 1: HarbethIO (Recommended for batch processing)**
```swift
let filter1 = C7ColorMatrix4x4(matrix: Matrix4x4.Color.sepia)
let filter2 = C7Granularity(grain: 0.8)
let filter3 = C7SoulOut(soul: 0.7)

let filters = [filter1, filter2, filter3]

// Synchronous processing
let dest = HarbethIO(element: inputImage, filters: filters)
ImageView.image = try? dest.output()
```

**Method 2: Direct Extension (Most concise)**
```swift
// Apply filters directly to image
ImageView.image = try? inputImage.make(filters: filters)
```

**Method 3: Operator Chaining (Most expressive)**
```swift
// Chain filters with intuitive operators
ImageView.image = inputImage ->> filter1 ->> filter2 ->> filter3
```

#### 🧱 Frame-First Rendering

Use frame rendering when the host app needs metadata, replay, or profile-based output control:

```swift
let filters: [C7FilterProtocol] = [
    C7NoiseReduction(radius: 4, amount: 0.2, edgePreservation: 0.75),
    C7UnsharpMask(radius: 2, intensity: 0.35, threshold: 0.02)
]

let io = HarbethIO(element: inputImage, filters: filters)
let frame = try io.renderFrame(profile: .stablePreview)

let renderedImage = frame.image
let semantic = frame.semantic
let replayContract = frame.replayBaseContract
```

#### 📷 Geometry and Optics Pipeline

Geometry and optics corrections can be assembled as a normal filter chain:

```swift
let filters: [C7FilterProtocol] = [
    C7LensDistortionCorrection(
        amount: -0.18,
        cubicDistortion: 0.03,
        scale: 1.02
    ),
    C7ChromaticAberrationCorrection(intensity: 0.45),
    C7LensVignetteCorrection(intensity: 0.3),
    C7DefringeCorrection(amount: 0.4),
    C7SharpnessFalloffCorrection(intensity: 0.25)
]

let corrected = try inputImage.make(filters: filters)
```

You can also build profile-driven correction from `LensProfile` and `OpticsSettings`:

```swift
let profile = LensProfile(
    distortion: .init(amount: -0.2, cubic: 0.04, scale: 1.01),
    vignette: .init(intensity: 0.2),
    chromaticAberration: .init(intensity: 0.35)
)

let settings = OpticsSettings(
    lensProfile: profile,
    enablesDefringe: true,
    enablesSharpnessFalloffCorrection: true
)

let corrected = try inputImage.make(filters: settings.filters)
```

For guided perspective correction:

```swift
let upright = GuidedUpright(
    verticalGuides: [leftEdge, rightEdge],
    horizontalGuides: [roofLine]
)

let transform = upright.recommendedTransform()
let corrected = try inputImage ->> transform
```

#### ⚡ Asynchronous Processing (Best Performance)

For large images or real-time scenarios, use async processing to avoid blocking the main thread:

```swift
let dest = HarbethIO(element: sourceImage, filters: filters)

dest.transmitOutput { [weak self] result in
    switch result {
    case .success(let image):
        DispatchQueue.main.async {
            self?.imageView.image = image
        }
    case .failure(let error):
        print("Processing failed: \(error)")
    }
}
```

**💡 Pro Tips:**
- Use `transmitOutputRealTimeCommit = true` for low-latency frame streams
- Enable `enableDoubleBuffer` for better memory efficiency
- Set `bufferPixelFormat` to match your input format for optimal performance

### Recommended Workflows

- **Photo editing pipeline**: start with `stablePreview`, then switch to `inspectionQuality` or `exportQuality` for final output.
- **Live frame pipeline**: use texture-first rendering, `interactiveLatency`, and a compact filter chain.
- **Video frame processing**: treat camera and player integrations as host-side frame providers, and keep Harbeth focused on per-frame processing.
- **Geometry or optics correction**: perform correction early in the chain, then apply color and stylization filters on the corrected result.
- **Readback-heavy workflows**: use `readbackQuality` when CPU-side analysis, export composition, or host-side pixel inspection is required.

### 📸 Camera

Harbeth includes reference camera wiring that shows how to connect live frame sources into the processing core:

#### ✨ Key Features
- **Real-time filtering** - Apply filters to camera feed at 60 FPS
- **High-quality capture** - Supports multiple camera resolutions and orientations
- **Reference wiring** - Simple delegate pattern for receiving filtered frames
- **Flexible filter chain** - Apply multiple filters simultaneously
- **Performance optimized** - Metal-powered processing with texture pooling

### 📺 Video

Harbeth includes reference video wiring for local and network frame sources:

#### ✨ Key Features
- **Universal video support** - Works with both local files and network streams
- **Real-time filtering** - Apply filters during video playback
- **Reference integration** - Built-in AVPlayer example wiring
- **Customizable processing** - Use HarbethIO for advanced frame processing
- **Performance optimized** - Metal acceleration for smooth playback

### ⛺️ SwiftUI Support

First-class SwiftUI integration with native `View` components:

#### HarbethView - Native SwiftUI Component

```swift
import SwiftUI
import Harbeth

struct FilteredImageView: View {
    @State private var inputImage: UIImage = UIImage(named: "sample")!
    @State private var intensity: Float = 0.5
    
    var body: some View {
        VStack {
            HarbethView(image: inputImage, filters: [
                C7HighlightShadow(highlight: intensity),
                C7WaterRipple(ripple: intensity),
            ]) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(12)
                    .shadow(radius: 5)
            }
            
            Slider(value: $intensity, in: 0...1)
                .padding()
        }
        .padding()
    }
}
```

**✨ SwiftUI Features:**
- **Native View integration** - Works seamlessly with SwiftUI view hierarchy
- **State-driven updates** - Filters update automatically when `@State` changes
- **Declarative syntax** - Clean, expressive API matching SwiftUI patterns
- **Performance optimized** - Efficient re-rendering with minimal overhead

**💡 SwiftUI Best Practices:**
- Use `@State` for filter parameters to enable real-time adjustments
- Wrap `HarbethView` in `VStack` or `ZStack` for complex layouts
- Apply SwiftUI modifiers (`.cornerRadius()`, `.shadow()`) to the output image
- Consider using `@Binding` to share filter state between views

### 🖥️ macOS Support

Harbeth fully supports macOS platform, providing powerful image processing capabilities for desktop applications with a native, optimized experience:

#### 🎨 macOS Gallery

Explore Harbeth's macOS capabilities with these featured use cases:

<div align="center" style="margin-top: 20px; margin-bottom: 20px;">
  <table style="border-collapse: collapse; width: 100%;">
    <tr style="height: 100%;">
      <td align="center" style="padding: 10px 5px; height: 100%;">
        <img src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/mac1.png" width=98% style="display: block;" />
        <p style="margin-top: 8px; margin-bottom: 4px; font-size: 14px; font-weight: 500;">Cinematic Color</p>
      </td>
      <td align="center" style="padding: 10px 5px; height: 100%;">
        <img src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/mac2.png" width=98% style="display: block;" />
        <p style="margin-top: 8px; margin-bottom: 4px; font-size: 14px; font-weight: 500;">Film Simulation</p>
      </td>
      <td align="center" style="padding: 10px 5px; height: 100%;">
        <img src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/mac3.png" width=98% style="display: block;" />
        <p style="margin-top: 8px; margin-bottom: 4px; font-size: 14px; font-weight: 500;">Vignette Effects</p>
      </td>
    </tr>
    <tr style="height: 100%;">
      <td align="center" style="padding: 10px 5px; height: 100%;">
        <img src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/mac4.png" width=98% style="display: block;" />
        <p style="margin-top: 8px; margin-bottom: 4px; font-size: 14px; font-weight: 500;">Pinch Preview</p>
      </td>
      <td align="center" style="padding: 10px 5px; height: 100%;">
        <img src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/mac5.png" width=98% style="display: block;" />
        <p style="margin-top: 8px; margin-bottom: 4px; font-size: 14px; font-weight: 500;">Gaussion Blur</p>
      </td>
      <td align="center" style="padding: 10px 5px; height: 100%;">
        <img src="https://raw.githubusercontent.com/yangKJ/Harbeth/master/Screenshot/mac6.png" width=98% style="display: block;" />
        <p style="margin-top: 8px; margin-bottom: 4px; font-size: 14px; font-weight: 500;">Luminance Adaptive Contrast</p>
      </td>
    </tr>
  </table>
</div>

#### 🌟 macOS Experience

#### ✨ Key Features
- **Native AppKit integration** - Works seamlessly with NSImage and AppKit components
- **High-resolution support** - Optimized for Retina displays and large image processing
- **Drag & Drop support** - Easy integration with macOS drag and drop functionality
- **Performance optimized** - Leverages full GPU power available on Mac devices
- **Multi-window support** - Process multiple images across different windows simultaneously

#### 🚀 Implementation Example

```swift
import Cocoa
import Harbeth

class ImageProcessingViewController: NSViewController {
    @IBOutlet weak var imageView: NSImageView!
    
    func applyFilter(to image: NSImage) {
        // Create filter chain
        let filters: [C7FilterProtocol] = [
            C7Brightness(brightness: 0.1),
            C7Contrast(contrast: 1.2),
            C7Saturation(saturation: 1.1)
        ]
        
        // Process image using HarbethIO
        let dest = HarbethIO(element: image, filters: filters)
        
        // Asynchronous processing for large images
        dest.transmitOutput { [weak self] result in
            switch result {
            case .success(let output):
                DispatchQueue.main.async {
                    self?.imageView.image = output
                }
            case .failure(let error):
                print("Filter application failed: \(error)")
            }
        }
    }
}
```

### 📝 HarbethIO Properties

HarbethIO provides several properties to customize the image processing behavior. Here's a detailed explanation of each property:

| Property | Description |
| :--- | :--- |
| `element` | The input element to apply filters to. Supports UIImage/NSImage, CGImage, MTLTexture, CMSampleBuffer, and CVPixelBuffer. |
| `filters` | An array of filters to apply to the input element. |
| `bufferPixelFormat` | The pixel format for the output buffer. Keep it aligned with incoming frame sources, which often use `kCVPixelFormatType_32BGRA`, to avoid channel mismatch issues. |
| `createDestTexture` | Whether to create a separate output texture. Disabling this may cause texture overlay issues. |
| `transmitOutputRealTimeCommit` | Whether to use real-time commit for Metal texture output. Enables `MTLCommandBuffer.realTimeCommit` for faster processing by only waiting until scheduled, not completed. |
| `enableDoubleBuffer` | Whether to enable double buffer optimization for metal filters. Reduces memory usage and improves texture pool efficiency. |

#### Usage Examples

```swift
// Custom configuration
var dest = HarbethIO(element: image, filters: [filter1, filter2])
dest.bufferPixelFormat = .rgba8Unorm
dest.enableDoubleBuffer = true
_ = try? dest.output()

// Asynchronous processing with custom configuration
var dest = HarbethIO(element: image, filters: [filter1, filter2])
dest.transmitOutputRealTimeCommit = true
dest.transmitOutput { result in
    switch result {
    case .success(let output):
        // Handle successful output
    case .failure(let error):
        // Handle error
    }
}
```

#### Performance Optimization Tips

1. **For low-latency frame processing**:
   - Set `transmitOutputRealTimeCommit = true`
   - Enable `enableDoubleBuffer` for better memory management

2. **For memory-constrained devices**:
   - Set a lower memory limit using `Device.setMemoryLimitMB(value)`
   - Ensure `enableDoubleBuffer = true`
   - Use asynchronous processing to avoid memory peaks

3. **For high-quality output**:
   - Set `createDestTexture = true` to avoid texture overlay
   - Use appropriate `bufferPixelFormat` for your output needs

4. **For performance monitoring**:
   - Enable performance monitoring using `Device.setEnablePerformanceMonitor(true)`
   - Check performance statistics with `PerformanceMonitor.shared.getStatistics()`

### 🚀 Threadgroup Optimization Strategy

Harbeth implements advanced threadgroup optimization based on memory access patterns to maximize GPU performance:

| Memory Access Pattern | Description | Typical Use Cases | Apple Silicon Threadgroup Size | Intel Threadgroup Size |
| :--- | :--- | :--- | :--- | :--- |
| **Point** | Accesses only the current pixel | Brightness, Contrast, Saturation, Hue, HSL, Color Balance, Geometric Transforms | 32x32 | 16x16 |
| **Neighborhood** | Accesses surrounding pixels | Gaussian Blur, Edge Detection, Morphology, Clarity | 8x8 | 8x8 |
| **Dual Texture** | Accesses two textures | Blend Modes, Lookup Tables | 24x24 | 16x16 |
| **Multi Texture** | Accesses multiple textures | Combination Filters, Blend with Mask | 16x16 | 16x16 |

**Optimization Benefits:**
- **Dynamic Threadgroup Sizing**: Automatically adjusts based on GPU architecture and memory access pattern
- **Aspect Ratio Optimization**: Adapts threadgroup shape to match texture dimensions for better memory coalescing
- **Architecture-Aware**: Uses larger threadgroups on Apple Silicon for better utilization
- **Memory Coalescing**: Optimizes memory access patterns to reduce GPU memory latency

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
- **C7CombinationColorGrading**: Professional color grading with temperature, tint, and tone adjustments
- **C7CombinationCreativeAtmosphere**: Adds creative atmosphere effects like warm glow, cool blue, golden hour, and moody
- **C7CombinationCyberpunk**: Creates a cyberpunk style with neon glow, color shifting, and edge detection
- **C7CombinationDreamy**: Achieves a dreamy, soft look with Gaussian blur, warmth, and reduced saturation
- **C7CombinationFilmSimulation**: Simulates modern film effects with grain and color characteristics
- **C7CombinationHDRBoost**: Enhances dynamic range with improved highlight and shadow details
- **C7CombinationModernHDR**: Achieves modern HDR effects with improved dynamic range
- **C7CombinationSkinSmoothing**: A skin smoothing combination effect that uses frequency separation to smooth skin while preserving details
- **C7CombinationVintage**: Applies vintage film effects with warm tones and grain
- **C7CombinationVintageFilm**: Simulates vintage film stock with grain, vignette, and sepia tone effects

#### 🎨 Color Adjustment
- **C7Brightness**: Adjusts the overall brightness of the image, with values ranging from -1.0 (darkest) to 1.0 (brightest), where 0.0 represents the original image
- **C7ColorConvert**: Converts colors between different color spaces, such as RGB to YUV or other color space transformations
- **C7ColorRGBA**: Independently adjusts the red, green, blue, and alpha channels of the image, allowing for precise color control
- **C7ColorSpace**: Performs advanced color space operations, enabling complex color manipulations and transformations
- **C7Contrast**: Adjusts the contrast of the image, with values ranging from 0.0 (no contrast) to 2.0 (maximum contrast), where 1.0 is the original image
- **C7Curves**: Allows precise adjustment of the image's tonal curve, providing detailed control over brightness and contrast across different tonal ranges
- **C7Exposure**: Simulates camera exposure adjustments, with values ranging from -10.0 (underexposed) to 10.0 (overexposed), where 0.0 is the original exposure
- **C7FalseColor**: Uses the luminance values of the original image to mix between two user-specified colors, creating artistic false color effects
- **C7Gamma**: Applies gamma correction to the image, with values ranging from 0.0 (high contrast) to 3.0 (low contrast), where 1.0 is the original image
- **C7Grayed**: Converts the image to grayscale, removing all color information while preserving luminance
- **C7Haze**: Applies a haze effect to the image, reducing contrast and adding a foggy or misty appearance
- **C7HSL**: Adjusts the hue, saturation, and lightness of the image independently, providing comprehensive color control
- **C7Hue**: Adjusts the overall hue of the image in degrees, rotating the color wheel to shift all colors uniformly
- **C7LuminanceAdaptiveContrast**: Dynamically adjusts contrast based on local pixel brightness, enhancing details in both dark and bright areas
- **C7Monochrome**: Converts the image to a monochrome version, tinting it with a specific color based on the brightness of each pixel
- **C7Nostalgic**: Applies a nostalgic color tone effect, reminiscent of vintage photographs with warm, aged colors
- **C7Opacity**: Adjusts the transparency of the image, making it more or less see-through
- **C7Posterize**: Reduces the number of colors in the image, creating a stylized, poster-like effect with distinct color blocks
- **C7Saturation**: Adjusts the color saturation of the image, with values ranging from 0.0 (grayscale) to 2.0 (highly saturated), where 1.0 is the original image
- **C7Sepia**: Applies a sepia tone effect to the image, giving it a warm, brownish vintage appearance similar to old photographs
- **C7Vibrance**: Intelligently adjusts the vibrance of the image, enhancing muted colors while preserving skin tones, with values ranging from -1.2 (desaturated) to 1.2 (highly vibrant)
- **C7Temperature**: Adjusts the color temperature, tint, and color shift of the image
- **C7Warmth**: Adjusts the color temperature of the image, with values ranging from -1.0 (cooler) to 1.0 (warmer)
- **C7WhiteBalance**: Adjusts the white balance of the image based on color temperature, allowing correction of color casts from different lighting conditions
- **C7ColorCorrection**: Comprehensive color correction filter with levels, curves, and color balance controls
- **C7AppleLogDecode**: Decodes Apple Log encoded images to linear space, used for processing HDR content

#### 🌫️ Blur Effects
- **C7BilateralBlur**: Applies a bilateral blur effect that preserves edges while blurring flat areas, creating a smooth appearance without losing important details
- **C7CircleBlur**: Creates a circular blur effect that radiates from a central point, with blur intensity decreasing outward from the center
- **C7DetailPreservingBlur**: Applies a blur that reduces noise and smooths the image while preserving important details and edges
- **C7GaussianBlur**: Applies a classic Gaussian blur effect, creating a smooth, natural-looking blur by averaging pixel values with a Gaussian distribution
- **C7MeanBlur**: Applies a mean (box) blur effect, averaging pixel values within the blur radius for a simple but effective blur
- **C7MotionBlur**: Simulates motion blur in a specified direction, creating the illusion of movement or camera shake
- **C7RedMonochromeBlur**: Applies a blur effect that affects only the red channel while converting the rest of the image to monochrome
- **C7TiltShift**: Applies a tilt-shift effect, creating a selective focus area with blur outside the focus region, simulating the shallow depth of field of tilt-shift lenses
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
- **C7ColorBurnEnhancedBlend**: Enhanced color burn blend mode
- **C7XORBlendWithMask**: XOR hybrid filter is used to achieve the effect of odd and even

#### 🔍 Edge & Detail
- **C7Canny**: Applies the Canny edge detection algorithm, a multi-stage process that identifies edges with high accuracy and low noise
- **C7Clarity**: Enhances the clarity of the image by increasing contrast in midtones, making details more pronounced without amplifying noise
- **C7ComicStrip**: Creates a comic strip effect, with bold outlines and flat colors reminiscent of comic book art
- **C7Crosshatch**: Applies a crosshatch pattern to the image, creating a sketch-like appearance with intersecting lines
- **C7DetailEnhancer**: Enhances fine details in the image without amplifying noise, resulting in a sharper appearance
- **C7EdgeAwareSharpen**: Sharpens only the edge areas of the image while preserving smooth regions, avoiding the amplification of noise
- **C7Granularity**: Adjusts the film graininess of the image, adding or reducing texture for a more cinematic or vintage appearance
- **C7Sharpen**: Sharpens the entire image by increasing contrast at edges, making details more pronounced
- **C7SharpenDetail**: Comprehensive sharpening filter combining sharpen, clarity, and detail enhancement for professional image sharpening
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

##### 🎨 Artistic Style Filters
- **C7PastelDream**: Creates a soft pastel dream effect with gentle colors, subtle blur, and a warm glow, perfect for creating ethereal, dreamlike images
- **C7NeonPunk**: Applies a neon punk effect with vibrant colors, glowing edges, and high contrast, capturing the energetic and rebellious aesthetic of punk culture
- **C7PaperCut**: Creates a paper cut art effect with sharp edges, layered appearance, and subtle shadows, simulating the look of intricate paper cut designs

##### 🚀 Sci-fi and Futurism Filters
- **C7Hologram**: Creates a holographic effect with cyan tint, scan lines, and subtle glitch elements, simulating futuristic holographic displays
- **C7DigitalGlitch**: Applies a digital glitch effect with random row offsets, RGB channel separation, and noise, creating the appearance of digital data corruption
- **C7QuantumDistortion**: Creates a quantum distortion effect with wave-like pixel offsets, color aberration, and glow, simulating the warping of space-time

##### 🌿 Natural and Organic Filters
- **C7Watercolor**: Applies a watercolor painting effect with soft edges, color bleeding, and paper texture, capturing the fluid and transparent qualities of watercolor art
- **C7OrganicGrowth**: Creates an organic growth effect with noise-based patterns, natural color shifts, and edge enhancement, simulating the appearance of organic forms and textures
- **C7LensFlare**: Applies a lens flare effect with light spots, hexagonal artifacts, and color dispersion, simulating the optical flares created by camera lenses

##### 📼 Retro and Nostalgic Filters
- **C7VintageFilmGrain**: Applies a vintage film grain effect with warm tones, subtle grain noise, desaturation, and vignette, simulating the look of old film stock
- **C7ComicBook**: Creates a comic book style effect with bold black outlines, color quantization, and high contrast, resembling hand-drawn comic book art
- **C780sSynthwave**: Applies an 80s synthwave effect with neon colors, purple-blue tint, high contrast, and subtle glow, capturing the nostalgic aesthetic of 1980s synthwave culture

##### 📷 Camera Style Filters
- **C7FujiNC**: Simulates Fuji film NC style, natural colors, suitable for portraits and daily shooting
- **C7FujiNN**: Simulates Fuji film NN style, high contrast black and white effect, suitable for documentary and art photography
- **C7FujiFlash**: Simulates Fuji film flash mode, bright and transparent, suitable for sunny and outdoor scenes
- **C7FujiX100V**: Simulates Fuji X100V camera style, classic vintage tone, suitable for street and humanistic photography
- **C7FujiCC**: Simulates Fuji Classic Chrome style, low saturation high texture, suitable for landscape and architectural photography
- **C7RicohPositive**: Simulates Ricoh positive film style, vibrant colors, rich layers
- **C7RicohNegative**: Simulates Ricoh negative film style, high contrast, rich dark details
- **C7Universal400**: Simulates universal 400 film style, strong adaptability, suitable for various scenes
- **C7CPM35**: Simulates CPM35 film style, warm vintage, suitable for portraits and street photography
- **C7Polaroid**: Simulates Polaroid camera style, with border effect, vintage and cute

##### 🌅 Scene Style Filters
- **C7DarkToneEnhance**: Enhances dark tone colors, improves picture layering, suitable for low light environment shooting
- **C7Sunset**: Simulates warm tone effect at sunset, suitable for黄昏 and sunrise scenes
- **C7GrayRemoval**: Removes picture haze, brightens and whitens, suitable for cloudy and hazy weather shooting

#### 📊 Matrix Processing
- **C7ColorMatrix4x4**: Applies a 4x4 color matrix transformation to the image, allowing for complex color adjustments and transformations
- **C7ColorMatrix4x5**: Applies a 4x5 color matrix transformation, providing an additional offset value for more flexible color adjustments
- **C7ColorVector4**: Applies a 4D color vector transformation, modifying the red, green, blue, and alpha components of the image
- **C7ConvolutionMatrix3x3**: Applies a 3x3 convolution matrix to the image, useful for edge detection, sharpening, and other image processing operations
- **C7EdgeGlow**: Detects edges in the image and adds a glow effect to them, creating a dramatic, outlined appearance

#### 🎛️ Utility
- **C7ChromaKey**: Removes the background that matches a specified color, similar to green screen effects in video production
- **C7DepthLuminance**: Adjusts luminance based on depth information, creating a more realistic lighting effect
- **C7Highlights**: Specifically adjusts only the highlight areas of the image, brightening or darkening them as needed
- **C7HighlightShadow**: Independently adjusts the highlights and shadows of the image, allowing for precise tonal control
- **C7HighlightShadowTint**: Tints the highlights and shadows of the image with specified colors, creating a color graded appearance
- **C7HighlightShadowTone**: Comprehensive tone adjustment filter with controls for shadows, highlights, midtones, contrast
- **C7HighPassSkinSmoothing**: Performs skin smoothing using frequency separation, preserving details while smoothing skin texture
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
- **C7LanczosResize**: High-quality Lanczos3 resize for fine rendering and export paths

#### 📷 Geometry & Optics Correction
- **C7LensDistortionCorrection**: Corrects barrel or pincushion lens distortion with optional cubic distortion and scale compensation
- **C7ChromaticAberrationCorrection**: Reduces red/cyan and blue/yellow color fringing near high-contrast edges
- **C7LensVignetteCorrection**: Lifts edge falloff caused by lens shading while preserving the image center
- **C7DefringeCorrection**: Suppresses purple and green fringe artifacts along strong contrast transitions
- **C7DiffractionCorrection**: Recovers edge definition softened by diffraction-like blur
- **C7SharpnessFalloffCorrection**: Boosts edge sharpness progressively toward image corners
- **RenderTransform3D**: Applies 3D projection transforms with configurable viewport behavior
- **RenderQuadTransform**: Warps an image using a destination quad
- **RenderQuadRectifyTransform**: Rectifies a source quad back into a regular output frame
- **GuidedUpright**: Builds a recommended perspective or quad rectify transform from vertical and horizontal guides
- **LensProfile**: Describes reusable lens correction coefficients for a device or lens
- **OpticsSettings**: Composes profile-driven optics corrections with strength overrides into a filter pipeline

#### 🎨 Generators
- **C7ColorGradient**: Generates a color gradient, creating a smooth transition between two or more colors, useful for backgrounds or overlays
- **C7SolidColor**: Generates a solid color image, useful for backgrounds, masks, or as a base for other effects

#### 📋 Lookup Tables
- **C7ColorCube**: Applies a 3D LUT (Look-Up Table) from CUBE files, allowing for professional color grading and complex color transformations. Supports multiple initialization methods including from file name, URL, or raw data.
- **C7LookupTable**: Applies a color lookup table (LUT) from image files, used for color grading and stylization
- **C7LookupTable512x512**: 512x512 color search table filter for high-quality color

#### 🎚️ Other Effects
- **C7Fade**: Applies a fade effect to the image, gradually transitioning between the original image and a white overlay
- **C7Grayed**: Converts the image to grayscale using various methods, including luminosity, average, and desaturation
- **C7Haze**: Applies a haze effect to the image, reducing contrast and adding a foggy or misty appearance
- **C7Pow**: Applies a power function to the image, creating non-linear brightness adjustments
- **C7Vignette**: Applies a vignette effect that darkens the edges of the image, drawing attention to the center
- **C7VignetteBlend**: Applies a vignette effect with multiple blend modes, allowing for different styles of edge darkening

#### 🖼️ Blit Operations
- **C7CopyRegionBlit**: Copies a specific region from one texture to another
- **C7CropBlit**: Crops the image to a specified region
- **C7GenerateMipmapsBlit**: Generates mipmaps for a texture, useful for efficient downsampling

#### ⚡ Metal Performance Shaders
- **MPSBoxBlur**: Metal Performance Shaders box blur
- **MPSCanny**: Metal Performance Shaders Canny edge detection
- **MPSGaussianBlur**: Metal Performance Shaders Gaussian blur
- **MPSHistogram**: Metal Performance Shaders histogram calculation
- **MPSMedian**: Metal Performance Shaders median filter

#### 📌 Render Module
- **RenderGrayscale**: Grayscale rendering filter
- **RenderSepia**: Tan rendering filter

**Use Cases:**
- Custom UI effects and transitions
- Advanced visualizations
- 3D-like effects in 2D space
- Complex compositing operations
- Performance-critical rendering tasks

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

If you find Harbeth helpful, please consider supporting the project:

<a href="https://github.com/sponsors/yangKJ">
  <img src="https://img.shields.io/badge/GitHub-Sponsors-blue?style=for-the-badge" alt="GitHub Sponsors">
</a>

Your support helps keep the project active and enables new features!

### License
Harbeth is available under the [MIT](LICENSE) license. See the [LICENSE](LICENSE) file for more info.

-----

### 📞 Technical Support

#### Frequently Asked Questions

**Q: Which platforms does Harbeth support?**
A: Harbeth supports iOS 10.0+, macOS 10.13+, tvOS 12.0+, and watchOS 5.0+.

**Q: How is Harbeth's performance?**
A: Harbeth is built on Metal, fully leveraging GPU acceleration, which is several times faster than CPU processing, especially suitable for real-time processing scenarios.

**Q: How to integrate Harbeth with SwiftUI?**
A: Use the HarbethView component, which provides a SwiftUI-friendly interface for applying filters to images.

**Q: How to handle different input source types?**
A: HarbethIO supports various input types including UIImage, CGImage, MTLTexture, CMSampleBuffer, and CVPixelBuffer. Simply pass your input to the HarbethIO initializer.

**Q: How to debug filter issues?** 
A: Enable performance monitoring to check for errors, verify input/output texture sizes, and ensure your filters are compatible with each other.

**Q: How to handle different pixel formats?**
A: Set the bufferPixelFormat property in HarbethIO to match your input/output requirements, especially for frame sources that use `kCVPixelFormatType_32BGRA`.

<p align="center">
  <em>Thank you for using Harbeth! I hope it can help with your projects.</em>
</p>
