# Troubleshooting / 故障排查

本页按用户最常遇到的现象给出检查顺序。Harbeth 默认静默，标准处理入口通过 `HarbethError` 暴露失败；不要先把失败改成返回原图。

## 1. 没有输出或抛出 Metal function 错误

先保留真实错误：

```swift
do {
    let output = try HarbethIO(element: image, filters: filters).output()
} catch {
    print(error)
}
```

若错误指向 Metal function：

- 确认 SwiftPM/CocoaPods resource bundle 已包含对应 `.metal` / `.metallib`。
- 自有 library 使用 `Device.registerExternalLibraryProvider(...)` 显式注册。
- 检查 Swift `modifier` 中的 kernel 名与 Metal function 名完全一致。
- 使用 `Device.externalLibraryRegistryDebugDescription()` 查看外部 library 是否进入候选源。
- Debug 环境下缺失函数会明确抛错，不应依赖静默 fallback。

## 2. 异步调用仍像是“同步”

`transmitOutput(...)` 的合同分两种情况：

- 有滤镜任务：编码工作进入 Harbeth render operation queue；默认 profile 在 GPU 完成后回调。
- 空滤镜快速路径：没有异步渲染工作，允许在当前调用栈内直接完成。

回调线程不固定。更新 UI 时显式切回主线程：

```swift
HarbethIO(element: image, filters: filters).transmitOutput { result in
    Task { @MainActor in
        imageView.image = try? result.get()
    }
}
```

`await transmitOutput()` 会挂起调用任务，但不会承诺结果恢复在哪个线程；UI 隔离仍由调用方的 actor 负责。

## 3. 实时纹理偶尔看见未完成内容

`.interactiveLatency` 的 texture-first 路线可以在 command buffer 已 scheduled、尚未 completed 时交付纹理，这是低延迟合同的一部分。消费方必须把纹理继续交给同一 GPU 依赖链或预览宿主，不能立即做未同步的 CPU readback。

需要确定 GPU 已完成时使用：

- `.stablePreview`：稳定复用预览。
- `.exportQuality`：导出质量与完成语义。
- `.readbackQuality`：CPU 读取或检查。

图片与 pixel buffer 输出在 CPU 读回前仍会等待 GPU 完成。

## 4. 图片发黑、透明、颜色偏移或 HDR 不正确

按顺序检查：

1. 输入 `pixelFormat` 与滤镜预期是否一致。
2. Alpha 是 straight、premultiplied 还是 opaque；必要时使用 `C7PremultiplyAlpha`、`C7UnpremultiplyAlpha` 或 `C7ForceOpaqueAlpha`。
3. `ImageColorSpaceContract`、transfer function 与 gamut 是否匹配输入。
4. PixelBuffer/SampleBuffer 的 YCbCr range、matrix 与 attachments 是否完整。
5. HDR 输出是保留 PQ/HLG，还是已通过 tone-mapping contract 转为 Display P3/SDR。
6. CPU readback 使用的 color space 是否与纹理合同一致。

存在 HDR preset 不代表任意显示器、输入 metadata 与导出容器都自动正确。视觉验收仍应覆盖真实设备、真实 EDR/HDR 显示和最终保存链路。

## 5. 输出尺寸或方向不对

- 普通尺寸变换检查滤镜的 `resize(input:)`。
- `ImageNode` 检查 `ImageTransformRecipe`、`ImageDerivativeSpec` 与 `RenderedFrame` 的 `sourcePixelSize`、`textureSize`、`displaySize`。
- SampleBuffer 检查 orientation attachment；不要只按纹理宽高推断展示方向。
- `RenderView` 通过 `resizingMode` 控制 `.aspectFit` / `.aspectFill` 等展示策略，展示尺寸不应反向修改渲染结果合同。

## 6. 相机帧或视频帧卡顿

Harbeth 只负责逐帧 GPU 处理；采集、播放器、帧丢弃、时间线、录制和导出调度由宿主媒体链路负责。底座侧重点检查：

- 高频链路是否保持 texture-first，避免每帧转 `UIImage` / `NSImage`。
- 是否使用与目标一致的 `RenderProfile`。
- 是否每帧重复创建大纹理、LUT 或 Metal library。
- 滤镜链是否包含 CPU readback、analysis 或只适合最终导出的重操作。
- 设备、分辨率、pixel format、预热状态、滤镜链与 P50/P95/P99 是否一并记录。

不要用单次桌面耗时外推所有 Apple 设备的实时性能。

## 7. Preview 不更新或恢复后黑屏

- `RenderView` / `HarbethRenderView` 应接收仍然有效的 `RenderedFrame` 或 texture。
- 确认 view 当前可见，visibility pause/resume 没有被宿主生命周期长期压住。
- SampleBuffer preview 可能根据 metadata 和可用性选择不同 host strategy；检查 `currentPreviewHostStrategy` 与 execution report。
- SwiftUI 如果需要 texture-first 展示，使用 `HarbethRenderView`；`HarbethView` 会把结果读回为 SwiftUI `Image`。
- UI 状态更新必须发生在 `MainActor`。

## 8. 内存上涨

- 确认调用方没有长期持有不再使用的 `RenderedFrame`、texture 或大图 source。
- 高频场景复用 node、filter 资源、LUT 和稳定 cache identity。
- 把 analysis/readback 限制在确实需要的帧，而不是每帧执行。
- 区分 texture pool 的可复用驻留与真实泄漏；结合 Instruments 和 Harbeth performance metrics 判断。
- 大图 tile runtime、修复编排和重策略任务不属于开源 Harbeth Core 的普通整图链路。

## 9. 提交 Issue 前收集什么

最小复现应包含：

- 输入类型、像素尺寸、pixel format、Alpha 和色彩空间信息。
- 最小滤镜链及参数。
- 使用 `HarbethIO` 还是 `ImageNode`，同步、callback 或 async 哪条执行面。
- 平台、系统、设备与 Harbeth 版本。
- 预期结果和实际结果；视觉问题附原图/结果图时先移除隐私内容。

生成不包含图片和用户数据的环境摘要：

```swift
let supportJSON = try HarbethSupportSnapshot.capture().json()
```

Bug 使用 GitHub Issue 表单；接入取舍和设计讨论使用 [Discussions](https://github.com/yangKJ/Harbeth/discussions)。
