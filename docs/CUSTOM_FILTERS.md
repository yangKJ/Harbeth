# Custom Filter Guide / 自定义滤镜指南

Harbeth 的滤镜开发面优先使用普通叶子滤镜、组合滤镜和 Render/MPS/Blit 标准合同。只有标准合同无法表达资源图或特殊 pipeline 时，才由滤镜接管 Metal command 编码。普通 App 接入仍从 `HarbethIO` 或 `ImageNode` 消费这些滤镜；本页只面向需要编写新滤镜或接入自有 Metal library 的开发者。

## 1. 先选择最小合同

| 需求 | 使用合同 |
| --- | --- |
| 一个 Compute kernel 完成处理 | `C7FilterProtocol` + `.compute(kernel:)` |
| 多个普通滤镜并行或串行，再执行最终合成 | `C7FilterPipelineProtocol` |
| 自定义 vertex/fragment 与 render pass | `RenderProtocol` |
| 直接封装 Metal Performance Shaders | `MPSKernelProtocol` |
| Copy、crop、mipmap 等 blit encoder | `BlitProtocol` |
| 外部 library 或 function constants 的单个 Compute kernel | `C7FilterProtocol` + `computeKernelLibrarySource` / `computeKernelFunctionConstants` |
| 需要共享 `MTLBuffer`、mesh/object shader 或特殊命令资源图 | `C7MetalCommandEncodingProtocol` |

多 pass 本身不是升级理由：texture-in / texture-out 的多个标准 pass 继续使用 `C7FilterPipelineProtocol`。只有现有原子滤镜和 pipeline 无法完整声明资源与执行行为时，才使用 command encoding escape hatch。

## 2. 最小 Compute 滤镜

Swift 类型负责声明 kernel、参数和访问模式：

```swift
public struct BrandToneFilter: C7FilterProtocol {
    @ZeroOneRange public var intensity: Float = 1.0

    public var modifier: ModifierEnum {
        .compute(kernel: "brandToneKernel")
    }

    public var factors: [Float] {
        [intensity]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public init(intensity: Float = 1.0) {
        self.intensity = intensity
    }
}
```

对应 Metal kernel 的基础 ABI 是：输出纹理位于 `texture(0)`，输入纹理位于 `texture(1)`，额外输入从 `texture(2)` 开始；`factors` 默认按顺序绑定到 `buffer(0...)`。

```metal
#include <metal_stdlib>
using namespace metal;

kernel void brandToneKernel(
    texture2d<half, access::write> output [[texture(0)]],
    texture2d<half, access::read> input [[texture(1)]],
    constant float &intensity [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }

    half4 color = input.read(gid);
    half3 toned = pow(max(color.rgb, half3(0.0h)), half3(0.96h));
    color.rgb = mix(color.rgb, toned, half(clamp(intensity, 0.0f, 1.0f)));
    output.write(color, gid);
}
```

使用方式与内置滤镜一致：

```swift
let image = try HarbethIO(
    element: inputImage,
    filters: [BrandToneFilter(intensity: 0.7)]
).output()
```

## 3. 参数、尺寸与纹理合同

- 只有少量 `Float` 参数时使用 `factors`。
- 参数需要名字、类型、矩阵、颜色、布尔或明确 buffer index 时，使用 `kernelParameterBindings`。
- 同一滤镜选择一个主要参数路径，不同时重复表达 `factors` 与 `kernelParameterBindings`。
- 改变输出尺寸时实现 `resize(input:)`，不要让 shader 写出目标纹理边界。
- 需要指定目标纹理 usage、storage mode 或输入输出别名策略时，实现 `destinationTextureContract`；这些要求属于所有滤镜，不属于特殊命令编码专有能力。
- Compute/MPS/Blit 或 command encoding 需要声明输出 pixel format、色彩空间或 alpha 时，实现 `kernelOutputContract`。
- 双纹理或多纹理 kernel 通过 `otherInputTextures` 声明额外输入，并把 `memoryAccessPattern` 标成 `.dualTexture` 或 `.multiTexture`。
- 邻域采样滤镜使用 `.neighborhood`，逐像素滤镜使用 `.point`，让 runtime 选择更合适的 threadgroup。
- Harbeth 会在 `buffer(30)` 提供共享 region context；普通全图 kernel 可以忽略它，区域执行 kernel 应按对应 contract 消费。

## 4. 组合滤镜

Combination 继续是 Harbeth 的公开滤镜能力。新的组合类型通过 `C7FilterPipelineProtocol` 表达，不依赖继承基类。

下面的例子让两个分支都从原始输入执行，再由最终 kernel 合成：

```swift
private struct BrandLookFinalFilter: C7FilterProtocol {
    let branchTextures: C7InputTextures
    let intensity: Float

    var modifier: ModifierEnum {
        .compute(kernel: "brandLookFinalKernel")
    }

    var factors: [Float] {
        [intensity]
    }

    var otherInputTextures: C7InputTextures {
        branchTextures
    }

    var memoryAccessPattern: MemoryAccessPattern {
        .multiTexture
    }
}

public final class BrandLookFilter: C7FilterPipelineProtocol {
    @ZeroOneRange public var intensity: Float = 1.0

    public var pipelineExecutionStyle: FilterPipelineExecutionStyle {
        .parallelFromSource
    }

    public var pipelineFilters: [C7FilterProtocol] {
        [
            C7Contrast(contrast: 1.08),
            C7Saturation(saturation: 0.9)
        ]
    }

    public init(intensity: Float = 1.0) {
        self.intensity = intensity
    }

    public func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? {
        BrandLookFinalFilter(
            branchTextures: otherInputTextures ?? [],
            intensity: intensity
        )
    }
}
```

最终 kernel 的纹理顺序为：`texture(0)` 输出、`texture(1)` 原始输入、`texture(2...)` 各 branch 输出。`.sequential` 适合真正依次消费上一步结果的链；`.parallelFromSource` 适合多个分析或效果分支最后统一合成。

## 5. 自有 Metal library

Harbeth 会优先从已注册的 Metal library provider、宿主 default library 和 Harbeth framework library 中解析函数。多模块宿主应显式注册 provider，让函数归属可诊断：

```swift
import Metal
import Harbeth

final class AppMetalLibraryProvider: ExternalMTLLibraryProvider {
    let providerIdentifier = "com.example.app.metal"

    func provideLibrary(for device: MTLDevice) -> MTLLibrary? {
        try? device.makeDefaultLibrary(bundle: .main)
    }
}

HarbethContext.shared.registerExternalLibraryProvider(AppMetalLibraryProvider())
```

`providerIdentifier` 应保持稳定；重复注册同一 identifier 会被拒绝。调试时可读取：

```swift
HarbethContext.shared.externalLibraryProviderIdentifiers
HarbethContext.shared.externalLibraryRegistryDebugDescription()
```

如果使用 `KernelFunctionIdentity`，还可以通过 `KernelLibrarySource.externalProvider(identifier)`、`.metallibURL(path)` 或 `.harbethFramework` 显式约束函数来源。

## 6. 错误与验证

自定义滤镜至少验证以下场景：

1. kernel 能从预期 library 解析；缺失时抛出 `HarbethError.readFunction`，而不是静默返回原图。
2. 1 × 1、非 16 倍数尺寸和横竖极端比例不会越界。
3. 参数边界、默认值、NaN/Infinity 输入符合预期。
4. 输出尺寸、pixel format、Alpha 与色彩空间合同正确。
5. 多纹理输入数量不足时明确失败。
6. 同一滤镜在 `HarbethIO.output()` 与 `ImageNode.makeTexture()` 下结果一致。
7. 若使用 `C7MetalCommandEncodingProtocol`，unsupported device 会落到可验证的 fallback，实际路线在执行时记录；静态 capability label 不代表执行成功。

完整公开滤镜清单见[滤镜目录](FILTER_CATALOG.md)，失败排查见[故障排查](TROUBLESHOOTING.md)。
