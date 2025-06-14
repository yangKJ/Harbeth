## 代码结构分析

本文档分析了 `Harbeth` Swift 图像处理库的代码结构。

### 1. 核心概念和协议

`Harbeth` 框架的核心设计围绕一组协议和基本概念构建，这些协议和概念定义了滤镜的创建和应用方式。

#### `C7FilterProtocol`

这是所有滤镜类型都必须遵守的基础协议。它规定了滤镜行为的通用接口。主要属性和方法包括：

*   **`modifier: Modifier`**: 此属性定义了滤镜将使用哪种类型的 Metal Encoder（或其他处理机制）。它是滤镜行为的核心。
*   **`factors: [Float]`**: 一个浮点数数组，用于向 Metal 着色器传递参数（例如亮度值、颜色矩阵等）。每个着色器最多支持16个 `Float` 参数。
*   **`otherInputTextures: C7InputTextures`**: 用于支持需要多个输入纹理的滤镜（例如混合滤镜）。
*   **`hasCount: Bool`**: 指示是否需要将像素总数作为因子传递。
*   **`resize(input size: C7Size) -> C7Size`**: 定义输出纹理相对于输入纹理的尺寸调整逻辑。默认情况下，它返回与输入相同的尺寸。
*   **`setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int)`**: 用于设置特殊类型的参数因子，例如4x4矩阵。如果可能，建议直接通过 `factors` 传递参数。
*   **`combinationBegin(for buffer: MTLCommandBuffer, source texture: MTLTexture, dest texture2: MTLTexture) throws -> MTLTexture`**: 在滤镜链中，滤镜实际应用之前对输入纹理进行预处理或替换。
*   **`combinationAfter(for buffer: MTLCommandBuffer, input texture: MTLTexture, source texture2: MTLTexture) throws -> MTLTexture`**: 在滤镜应用之后，对输出纹理进行后处理。
*   **`applyAtTexture(form texture: MTLTexture, to destTexture: MTLTexture, for buffer: MTLCommandBuffer) throws -> MTLTexture`**: 将滤镜应用于输入纹理并生成输出纹理的核心方法。此方法的默认实现会根据 `modifier` 的类型（compute, render, mps）调用相应的绘制/编码逻辑。

#### `Modifier` 枚举

此枚举指定了滤镜的具体实现方式和将使用的底层技术：

*   **`.compute(kernel: String)`**: 表示滤镜是基于 `MTLComputeCommandEncoder` 实现的。它需要一个 Metal 内核函数名字符串。这类滤镜直接在GPU上进行并行计算，通常用于图像处理。
*   **`.render(vertex: String, fragment: String)`**: 表示滤镜是基于 `MTLRenderCommandEncoder` 实现的。它需要顶点着色器和片元着色器的函数名。这通常用于需要渲染管线的3D场景或2D图形操作。
*   **`.blit`**: 表示滤镜操作是基于 `MTLBlitCommandEncoder`。通常用于纹理之间的复制、mipmap生成等操作。
*   **`.coreimage(CIName: String)`**: 表示滤镜是基于苹果的 `Core Image` 框架。它需要一个 `CIFilter` 的名称。这允许 `Harbeth` 集成和利用 `Core Image` 提供的现有滤镜。
*   **`.mps(performance: MPSKernel)`**: 表示滤镜是基于 `Metal Performance Shaders` (MPS) 框架。MPS 提供了一系列高度优化的、常见的图像处理和机器学习内核（如高斯模糊、直方图均衡等）。

#### 专门化协议

为了更好地组织和区分不同类型的滤镜，`Harbeth` 定义了一些继承自 `C7FilterProtocol` 的专门化协议：

*   **`CoreImageProtocol`**: 供基于 `Core Image` 的滤镜遵守。
    *   `croppedOutputImage: Bool`: 指示输出图像是否应裁剪到定义的矩形区域。
    *   `coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage`: 允许在应用主 `CIFilter` 之前或之后串联其他 `CIFilter`。
*   **`RenderProtocol`**: 供基于渲染管线的滤镜遵守。
    *   `setupVertexUniformBuffer(for device: MTLDevice) -> MTLBuffer?`: 允许滤镜为顶点着色器设置和提供特定的 Uniform Buffer。
*   **`MPSKernelProtocol`**: 供基于 `Metal Performance Shaders` 的滤镜遵守。
    *   `encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture`: 定义了如何将 MPS 内核编码到命令缓冲区中。输入纹理数组通常包含目标纹理和源纹理。

这些协议和枚举共同构成了一个灵活且可扩展的系统，允许开发者集成不同来源和类型的图像处理操作，同时保持统一的应用接口。

### 2. 输入/输出处理 (`HarbethIO`)

`HarbethIO<Dest>` 结构体是 `Harbeth` 框架中用于应用滤镜和处理输入输出的主要接口。它被设计为一个通用的、易于使用的工具，用于将一个或多个滤镜应用于各种图像和纹理数据源。

#### 主要特性和用法

*   **通用性 (`HarbethIO<Dest>`)**:
    *   `Dest` 是一个泛型类型参数，代表最终输出的数据类型。这使得 `HarbethIO` 可以处理多种输入源并以相同的类型输出。
    *   **支持的输入/输出类型**:
        *   `MTLTexture`: Metal 纹理对象。
        *   `UIImage` (iOS) / `NSImage` (macOS): 平台原生的图像对象。
        *   `CGImage`: Core Graphics 图像对象。
        *   `CIImage`: Core Image 图像对象。
        *   `CVPixelBuffer` (或 `CVImageBuffer`): Core Video 像素缓冲区，常用于相机捕捉和视频处理。
        *   `CMSampleBuffer`: Core Media 样本缓冲区，通常包含来自相机或视频的未压缩或压缩数据。

*   **初始化**:
    *   通过提供输入元素 `element` 和一个滤镜数组 `filters: [C7FilterProtocol]` 来初始化 `HarbethIO` 实例。
    *   例如: `let dest = HarbethIO(element: originImage, filters: [brightnessFilter, contrastFilter])`

*   **应用滤镜**:
    *   **同步操作 (`output() -> Dest?`)**:
        *   此方法会同步应用所有滤镜。它会阻塞当前线程，直到所有处理完成并返回最终结果。
        *   如果处理成功，返回一个可选的 `Dest` 类型结果；如果发生错误，则可能抛出异常或返回 `nil` (具体取决于错误处理机制)。
        *   用法: `let resultImage = try? dest.output()`
    *   **异步操作 (`transmitOutput(complete: @escaping (Result<Dest, HarbethError>) -> Void)`)**:
        *   此方法会异步应用所有滤镜，不会阻塞当前线程。
        *   处理完成后，会通过提供的闭包 `complete` 返回结果。该闭包接收一个 `Result<Dest, HarbethError>` 参数，表示成功（包含处理后的元素）或失败（包含一个 `HarbethError`）。
        *   用法:
            ```swift
            dest.transmitOutput { result in
                switch result {
                case .success(let processedImage):
                    // 使用 processedImage
                case .failure(let error):
                    // 处理错误
                }
            }
            ```

*   **内部工作流程**:
    *   `HarbethIO` 内部负责将各种输入类型转换为 `MTLTexture`，因为 Metal 滤镜主要操作纹理。
    *   它会按顺序迭代 `filters` 数组中的每个滤镜。
    *   对于每个滤镜，它会调用滤镜的 `applyAtTexture` 方法（或类似方法），将前一个滤镜的输出作为当前滤镜的输入。
    *   在应用所有滤镜后，最终的 `MTLTexture` 会被转换回原始的 `Dest` 类型。
    *   它还智能地管理 `MTLCommandBuffer` 的创建、提交和完成等待，确保 Metal 命令正确执行。

#### 关键可配置属性

*   **`bufferPixelFormat: MTLPixelFormat`**: (默认为 `.bgra8Unorm`)
    *   指定用于从 `CVPixelBuffer` 或 `CMSampleBuffer` 创建 `MTLTexture` 时的像素格式。
    *   这非常重要，因为相机捕获的数据通常是 `kCVPixelFormatType_32BGRA` (`.bgra8Unorm`)。如果纹理格式与源数据不匹配，可能会出现颜色失真（例如图像变蓝）。
    *   可以根据需要设置为其他格式，例如 `.rgba8Unorm`。
*   **`mirrored: Bool`**: (默认为 `false`)
    *   当输入源是 `CIImage` 时，此属性用于控制在转换为 `MTLTexture` 或从 `MTLTexture` 转回 `CIImage` 时是否需要进行垂直翻转。`CIImage` 的坐标系有时与其他图像类型不同。
*   **`createDestTexture: Bool`**: (默认为 `true`)
    *   决定是否为每个滤镜的输出创建一个新的 `MTLTexture` 对象。
    *   如果为 `true`（默认），每个滤镜操作都会写入一个新的目标纹理。这可以防止纹理内容在链式操作中意外重叠或被覆盖，确保每个滤镜都基于前一个滤镜的正确输出进行操作。
    *   如果为 `false`，在某些情况下可能会复用纹理以优化性能，但这需要开发者更仔细地管理纹理状态。某些特定滤镜（如纯色生成器）可能会内部覆盖此设置，因为它们不需要读取输入纹理。
*   **`transmitOutputRealTimeCommit: Bool`**: (默认为 `false`)
    *   主要用于实时处理场景，例如相机预览帧。
    *   当设置为 `true` 时，如果滤镜链中包含 `CoreImage` 滤镜，`HarbethIO` 会调整命令缓冲区的提交策略，以尝试确保更及时的输出。
*   **`hasCoreImage: Bool`**: (内部属性)
    *   一个内部标志，指示滤镜链中是否包含任何 `CoreImageProtocol` 类型的滤镜。
    *   `HarbethIO` 会根据此标志调整其处理逻辑，因为混合使用 Metal 滤镜和 Core Image 滤镜可能需要不同的命令缓冲区管理和渲染策略以获得最佳性能和正确性。例如，Core Image 滤镜可能需要在其自己的上下文中渲染，并且与 Metal 的集成需要仔细处理。

`HarbethIO` 通过这些特性和选项，为开发者提供了一个强大而灵活的工具，简化了在 Metal 上应用复杂图像处理滤镜链的过程。

### 3. 滤镜实现示例 (`C7Brightness`)

理解单个滤镜是如何实现的是掌握 `Harbeth` 框架的关键。我们将以 `C7Brightness`（亮度调整滤镜）为例，展示一个典型的基于 Metal Compute Shader 的滤镜的构成。

#### Swift 侧 (`C7Brightness.swift`)

每个滤镜通常都对应一个 Swift 结构体，该结构体遵守 `C7FilterProtocol` (或其子协议)。

```swift
// Sources/Compute/Pixel/C7Brightness.swift

import Foundation

/// 亮度
public struct C7Brightness: C7FilterProtocol {

    /// 可调整的亮度范围，从 -1.0 到 1.0，默认 0.0 为原始图像。
    public static let range: ParameterRange<Float, Self> = .init(min: -1.0, max: 1.0, value: 0.0)

    @Clamping(range.min...range.max) public var brightness: Float = range.value

    public var modifier: Modifier {
        return .compute(kernel: "C7Brightness")
    }

    public var factors: [Float] {
        return [brightness]
    }

    public init(brightness: Float = range.value) {
        self.brightness = brightness
    }
}
```

*   **结构体声明**: `public struct C7Brightness: C7FilterProtocol`
    *   声明了一个名为 `C7Brightness` 的公共结构体，并使其遵守 `C7FilterProtocol`。
*   **参数定义**:
    *   `public static let range: ParameterRange<Float, Self>`: 定义了滤镜参数的有效范围和默认值。这里，亮度值可以在 -1.0 到 1.0 之间，默认是 0.0。`ParameterRange` 是一个辅助类型，用于参数配置。
    *   `@Clamping(range.min...range.max) public var brightness: Float = range.value`:
        *   `brightness` 是实际的亮度参数。
        *   `@Clamping` 是一个属性包装器，确保赋给 `brightness` 的值始终被限制在 `range` 定义的最小和最大值之间。这有助于防止无效参数导致的着色器行为异常。
*   **`modifier: Modifier`**:
    *   `return .compute(kernel: "C7Brightness")`
    *   这指定了该滤镜使用 Metal Compute Shader。
    *   `kernel: "C7Brightness"` 指明了将在 `.metal` 文件中定义的 Metal 内核函数的名称。`Harbeth` 将使用此名称来查找并创建对应的 `MTLComputePipelineState`。
*   **`factors: [Float]`**:
    *   `return [brightness]`
    *   此属性返回一个浮点数数组，这些值将作为参数传递给 Metal 内核函数。在这个例子中，它只传递当前的 `brightness` 值。这些因子会按顺序映射到 Metal 内核函数参数中标记为 `[[buffer(0)]]`，`[[buffer(1)]]`等的缓冲区。
*   **`init(brightness: Float = range.value)`**:
    *   构造函数，允许在创建滤镜实例时设置亮度值，如果未提供，则使用默认值。

#### Metal 着色器侧 (`C7Brightness.metal`)

与 Swift 结构体对应的是一个 `.metal` 文件，其中包含实际在 GPU 上执行的着色器代码。

```metal
// Sources/Compute/Pixel/C7Brightness.metal

#include <metal_stdlib>
using namespace metal;

kernel void C7Brightness(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::read> inputTexture [[texture(1)]],
                         constant float *brightness [[buffer(0)]],
                         uint2 grid [[thread_position_in_grid]]) {
    const half4 inColor = inputTexture.read(grid);

    const half4 outColor = half4(inColor.rgb + half3(*brightness), inColor.a);

    outputTexture.write(outColor, grid);
}
```

*   **`#include <metal_stdlib>`**: 包含了 Metal 标准库的定义。
*   **`using namespace metal;`**: 避免在代码中反复写 `metal::` 前缀。
*   **内核函数声明**:
    *   `kernel void C7Brightness(...)`:
        *   `kernel`: 关键字，表示这是一个计算内核函数。
        *   `void`: 表示此函数没有返回值（输出是通过写入纹理实现的）。
        *   `C7Brightness`: 函数名，必须与 Swift 侧 `modifier` 中指定的内核名完全一致。
*   **参数**:
    *   `texture2d<half, access::write> outputTexture [[texture(0)]]`:
        *   `outputTexture`: 输出纹理，类型为 `texture2d`，存储 `half` 精度（通常是16位浮点数）的颜色数据。
        *   `access::write`: 表示此纹理在内核中是可写的。
        *   `[[texture(0)]]`: 属性，将此参数绑定到 Metal 函数参数表中的索引0位置的纹理。
    *   `texture2d<half, access::read> inputTexture [[texture(1)]]`:
        *   `inputTexture`: 输入纹理，只读。
        *   `[[texture(1)]]`: 绑定到索引1位置的纹理。
    *   `constant float *brightness [[buffer(0)]]`:
        *   `brightness`: 指向一个浮点数的指针，这个浮点数就是从 Swift 侧 `factors` 数组传递过来的亮度值。
        *   `constant`: 地址空间限定符，表示数据存储在常量内存中，通常由主机端（CPU）设置并且对于内核的单次执行是不变的。
        *   `[[buffer(0)]]`: 将此参数绑定到索引0位置的缓冲区。这对应于 `factors` 数组中的第一个（也是唯一的）元素。
    *   `uint2 grid [[thread_position_in_grid]]`:
        *   `grid`: 一个二维无符号整数向量 (`uint2`)，表示当前执行线程在计算网格中的位置（通常是像素坐标 x, y）。
        *   `[[thread_position_in_grid]]`: Metal提供的内置属性，自动填充当前线程的网格位置。
*   **内核逻辑**:
    *   `const half4 inColor = inputTexture.read(grid);`: 从输入纹理的当前像素位置 (`grid`) 读取颜色值 (`half4` 表示包含红、绿、蓝、透明度四个分量的半精度浮点向量)。
    *   `const half4 outColor = half4(inColor.rgb + half3(*brightness), inColor.a);`:
        *   计算新的颜色。`inColor.rgb` 取出颜色的RGB分量。
        *   `half3(*brightness)` 创建一个三维向量，其每个分量都等于 `*brightness`（解引用指针获取亮度值）。
        *   将输入颜色的RGB分量与亮度值相加。
        *   保持原始的 alpha (透明度) 值 `inColor.a` 不变。
        *   最终得到调整亮度后的颜色 `outColor`。
    *   `outputTexture.write(outColor, grid);`: 将计算得到的 `outColor` 写入到输出纹理的相应位置 (`grid`)。

这个例子清晰地展示了 Swift 代码如何定义滤镜的参数和类型，并通过 `factors` 和内核名称将其与 Metal着色器代码连接起来。Metal 着色器则负责在 GPU 上高效地执行实际的像素操作。

### 4. 项目和包结构

`Harbeth` 项目的组织结构清晰，便于理解和扩展。以下是主要目录和文件的说明：

#### 主要目录结构概览

*   **`.github/`**: 包含 GitHub 相关配置，如 issue 模板、FUNDING.yml 等。
*   **`Demo/`**: 包含示例应用程序，展示了如何在不同平台（iOS, macOS, SwiftUI）上使用 `Harbeth` 框架。
    *   `Harbeth-Demo.xcodeproj`: 针对 UIKit (iOS) 的示例项目。
    *   `Harbeth-SwiftUI-Demo/`: 针对 SwiftUI 的示例项目。
    *   `Harbeth-iOS-Demo/`: 另一个 iOS 示例，可能侧重于特定功能或更复杂的用例。
    *   `Harbeth-macOS-Demo/`: 针对 macOS 的示例项目。
    这些 Demo 对于理解 `Harbeth` 的实际用法非常有帮助。
*   **`Document/`**: 包含项目相关的文档，例如 `Metal.pdf` 和 `Shader.pdf`，可能是关于 Metal 和着色器编程的参考资料。
*   **`Harbeth.podspec`**: CocoaPods 的配置文件，用于将 `Harbeth` 作为 Pod 集成到其他项目中。
*   **`Harbeth.xcodeproj/`**: Xcode 项目文件，主要用于框架本身的开发和构建。
*   **`Language/`**: 包含一些 `.metal` 文件，如 `Language.metal` 和 `Metal.metal`。这些可能不是核心滤镜的一部分，而是用于特定语言处理、测试或特殊效果的着色器。
*   **`LICENSE`**: 项目的开源许可证文件 (MIT License)。
*   **`Package.swift`**: Swift Package Manager (SPM) 的配置文件。这是定义库、其目标、依赖项和构建设置的关键文件。
*   **`README.md` / `README_CN.md`**: 项目的说明文档，分别提供英文和中文版本。
*   **`Screenshot/`**: 包含展示各种滤镜效果的截图和GIF动图。
*   **`Sources/`**: **框架的核心代码所在地。**

#### `Sources/` 目录详解

`Sources/` 目录是 `Harbeth` 框架的灵魂，其内部结构如下：

*   **`Basic/`**: 包含框架的基础和核心组件。
    *   `Core/`: 核心的 Metal 交互逻辑，如 `Device.swift` (设备和命令队列管理)、`Filtering.swift` (核心滤镜协议 `C7FilterProtocol` 的定义)、`Rendering.swift` (渲染管线相关)、`TextureLoader.swift` (纹理加载和创建)。
    *   `Extensions/`: 对各种系统类型（如 `UIImage`, `CGImage`, `MTLTexture`, `CIImage` 等）的扩展，提供了方便的转换方法和实用功能。
    *   `Matrix/`: 包含自定义的矩阵（`Matrix3x3`, `Matrix4x4`）和向量（`Vector3`, `Vector4`）类型，用于图形变换和颜色计算。
    *   `Outputs/`: 定义了输入输出的主要接口，如 `HarbethIO.swift`，以及与渲染视图相关的组件如 `RenderImageView.swift`。
    *   `Setup/`: 包含各种辅助类型、枚举（如 `PixelFormat`, `ResizingMode`）和工具，用于配置和参数化滤镜。

*   **`Compute/`**: 这是数量最多的滤镜所在之处，主要基于 Metal Compute Shaders。
    *   每个子目录通常代表一类滤镜效果，例如：
        *   `Blend/`: 混合模式滤镜 (如 Overlay, Multiply, Screen)。
        *   `Blur/`: 模糊效果 (如 Gaussian Blur, Motion Blur)。
        *   `Combination/`: 组合滤镜，可能将多个效果合并为一个。
        *   `Coordinate/`: 基于坐标变换的滤镜 (如 Swirl, Bulge, Pixellate)。
        *   `Generator/`: 图像生成器 (如 SolidColor, Gradient)。
        *   `Lookup/`: 基于查找表 (LUT) 的颜色变换滤镜。
        *   `Matrix/`: 基于颜色矩阵的滤镜 (如 Sepia, ColorMatrix4x4)。
        *   `Pixel/`: 逐像素调整的滤镜 (如 Brightness, Contrast, Saturation, Exposure)。
        *   `Shape/`: 形状变换滤镜 (如 Crop, Resize, Rotate, Transform)。
    *   在这些子目录中，通常成对出现 `.swift` 文件（定义滤镜结构体和参数）和 `.metal` 文件（包含 Metal 着色器代码）。

*   **`CoreImage/`**: 包含对 `Core Image` 框架中 CIFilter 的封装和集成。这使得用户可以像使用 `Harbeth` 的原生 Metal 滤镜一样使用 `Core Image` 的滤镜。

*   **`Harbeth.h`**: Objective-C 的头文件，可能是为了支持 Objective-C 与 Swift 的混编，或者为了让框架的某些部分对 Objective-C 可见。

*   **`MPS/`**: 包含对 `Metal Performance Shaders` (MPS) 的封装。MPS 提供了一系列苹果优化的图像处理内核，使用它们可以获得很好的性能。例如 `MPSGaussianBlur.swift`。

*   **`SwiftUI/`**: 提供了与 SwiftUI 集成的组件，如 `HarbethView.swift`，使得在 SwiftUI 应用中可以方便地使用 `Harbeth` 进行图像处理和显示。

#### `Package.swift` 的作用

`Package.swift` 文件对于 `Harbeth` 作为 Swift Package 至关重要：

```swift
// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Harbeth",
    platforms: [ // 支持的平台和最低版本
        .iOS(.v10),
        .macOS(.v10_13),
        .tvOS(.v12),
        .watchOS(.v5)
    ],
    products: [ // 声明库产品
        .library(name: "Harbeth", targets: ["Harbeth"]),
    ],
    targets: [ // 定义目标 (Target)
        .target(
            name: "Harbeth", // 目标名称
            path: "Sources",  // 源代码路径
            resources: [      // 资源文件处理
                .process("Sources/Compute") // 关键点！
            ]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
```

*   **`name: "Harbeth"`**: 定义了包的名称。
*   **`platforms`**: 指定了框架支持的最低操作系统版本。
*   **`products`**: 声明了一个名为 "Harbeth" 的库，其他项目可以通过 SPM 依赖这个库。
*   **`targets`**: 定义了名为 "Harbeth" 的目标。
    *   `path: "Sources"`: 指明了该目标的源代码位于 `Sources` 目录下。
    *   **`resources: [.process("Sources/Compute")]`**: 这是非常重要的一行。它告诉 Swift Package Manager，`Sources/Compute` 目录（及其所有子目录）下的资源文件（在这里主要是 `.metal` 着色器文件）需要被处理并包含在最终的库产品中。这意味着 SPM 会确保这些 Metal 文件被正确编译（通常是编译成一个默认的 Metal Library `default.metallib`）并链接到框架中，使得 `Harbeth` 在运行时可以加载和使用这些着色器。如果缺少这一行或配置不当，Metal 滤镜将无法工作，因为框架找不到它们的着色器代码。

这种项目结构和 SPM 配置使得 `Harbeth` 既易于维护（通过模块化的 `Sources` 目录），也易于被其他开发者集成和使用（通过 CocoaPods 和 Swift Package Manager）。

### 5. 代码结构总结图 (Markdown 流程图)

以下是一个简化的流程图，展示了 `Harbeth` 框架中主要组件之间的交互关系：

```mermaid
graph LR
    A[用户代码/输入源
 (UIImage, CGImage, CVPixelBuffer等)] --> B{HarbethIO};
    B -- 使用 --> C[滤镜数组
 (遵守 C7FilterProtocol)];
    C -- 包含 --> F1[C7Brightness (Compute)];
    C -- 包含 --> F2[C7GaussianBlur (MPS)];
    C -- 包含 --> F3[CIExposureAdjust (CoreImage)];
    C -- 包含 --> F4[CustomRenderFilter (Render)];

    subgraph 滤镜处理流程
        B -- 1. 转换为MTLTexture --> D[MTLTexture (输入)];
        D -- 2. 应用滤镜1 (F1) --> E1[MTLTexture (中间)];
        F1 -- 调用 --> G1[Metal Compute Shader
 (C7Brightness.metal)];
        E1 -- 3. 应用滤镜2 (F2) --> E2[MTLTexture (中间)];
        F2 -- 调用 --> G2[MPSKernel
 (e.g., MPSImageGaussianBlur)];
        E2 -- 4. 应用滤镜3 (F3) --> E3[CIImage (中间)];
        F3 -- 调用 --> G3[CIFilter];
        E3 -- 转换为MTLTexture --> E4[MTLTexture (中间)];
        E4 -- 5. 应用滤镜4 (F4) --> E5[MTLTexture (输出)];
        F4 -- 调用 --> G4[Vertex & Fragment Shaders];
    end

    E5 -- 6. 转换回目标类型 --> H[最终输出
 (UIImage, CGImage等)];
    B --> H;

    subgraph 底层依赖
        G1 -- Metal API --> I[GPU];
        G2 -- Metal API --> I;
        G3 -- Core Image API --> J[CPU/GPU];
        G4 -- Metal API --> I;
        K[Device.swift
 (MTLDevice, MTLCommandQueue)] --> G1;
        K --> G2;
        K --> G4;
        L[TextureLoader.swift] --> D;
        L --> E3;
        L --> E5;
    end

    classDef user fill:#c9ffc9,stroke:#333,stroke-width:2px;
    classDef harbeth fill:#lightblue,stroke:#333,stroke-width:2px;
    classDef filter fill:#f9f,stroke:#333,stroke-width:2px;
    classDef texture fill:#ffc,stroke:#333,stroke-width:2px;
    classDef shader fill:#ff9,stroke:#333,stroke-width:2px;
    classDef gpu fill:#f66,stroke:#333,stroke-width:2px;
    classDef utility fill:#eee,stroke:#333,stroke-width:1px;

    class A user;
    class B harbeth;
    class C,F1,F2,F3,F4 filter;
    class D,E1,E2,E3,E4,E5 texture;
    class G1,G2,G3,G4 shader;
    class H user;
    class I,J gpu;
    class K,L utility;
```

**图表说明:**

1.  **用户代码/输入源**: 开发者提供各种类型的图像数据（如 `UIImage`, `CVPixelBuffer` 等）。
2.  **`HarbethIO`**: 作为主要的入口点，接收输入源和一组滤镜。
3.  **滤镜数组**: 用户定义的、遵守 `C7FilterProtocol` 的滤镜序列。这些滤镜可以是不同类型的（Compute, MPS, CoreImage, Render）。
4.  **滤镜处理流程**:
    *   `HarbethIO` 首先将输入源转换为内部统一的 `MTLTexture`。
    *   然后，它按顺序应用数组中的每个滤镜：
        *   对于 Compute 滤镜 (如 `C7Brightness`)，会调用相应的 `.metal` Compute Shader。
        *   对于 MPS 滤镜 (如 `C7GaussianBlur`)，会配置并运行相应的 `MPSKernel`。
        *   对于 CoreImage 滤镜 (如 `CIExposureAdjust`)，会通过 `CIFilter` 处理。如果后续是 Metal 滤镜，`CIImage` 输出可能需要再次转换为 `MTLTexture`。
        *   对于 Render 滤镜，会执行其顶点和片元着色器定义的渲染管线。
    *   每个滤镜的输出作为下一个滤镜的输入。
5.  **最终输出**: 最后一个滤镜处理完成的 `MTLTexture` 会被转换回用户期望的输出类型（例如 `UIImage`）。
6.  **底层依赖**:
    *   Metal Shaders (`.metal` 文件), MPS Kernels, 和 Render Shaders 直接在 GPU 上执行。Core Image 滤镜可能在 CPU 或 GPU 上执行。
    *   `Device.swift` 提供了对 `MTLDevice` 和 `MTLCommandQueue` 的全局访问，这是执行 Metal 命令的基础。
    *   `TextureLoader.swift` 负责在不同图像/纹理类型（如 `UIImage`, `CGImage`, `CVPixelBuffer`, `CIImage`, `MTLTexture`）之间进行转换。

这个图表旨在提供一个高层次的概览，展示了数据如何在框架中流动以及不同组件如何协同工作以实现最终的图像处理效果。
