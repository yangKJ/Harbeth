# Maintaining Harbeth

Harbeth 的维护目标是保持 Apple 多平台 GPU 图像与帧处理核心稳定、轻量并且可验证。普通使用入口固定为 `HarbethIO` 与 `ImageNode`，runtime、graph、kernel、analysis 和 preview substrate 是两条路线的支撑能力。

## 本地最小验证

```bash
env CLANG_MODULE_CACHE_PATH=.build/ModuleCache xcrun swift build
env CLANG_MODULE_CACHE_PATH=.build/ModuleCache xcrun swift test
xcodebuild build \
  -workspace Harbeth.xcworkspace \
  -scheme Harbeth \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

Swift 代码以现有排版和可读性为先：函数或方法的声明、调用在参数不超过 3 个且单行仍清晰时保持单行；参数超过 3 个默认采用结构化多行，复杂闭包、条件、集合与明显超长表达式也应主动分行。`.swift-format` 只用于本次触及文件的辅助检查，不递归重排全仓。Swift 或 Metal 核心逻辑至少运行 SwiftPM build/test；平台条件、资源打包、公开 API 或 preview surface 改动还应运行对应的 Xcode build。CocoaPods 发布前另行运行 `pod lib lint Harbeth.podspec`。

## CI 门禁

`.github/workflows/ci.yml` 在 `master` push 与 pull request 上执行：

1. SwiftPM build；runner 有 Metal 设备时执行全量测试，否则编译并枚举完整测试 inventory，同时输出显式 warning；
2. iOS、macOS、tvOS framework build；
3. UIKit、SwiftUI、AppKit Demo build；
4. DocC build 与 CocoaPods lint。

CI 证明的是编译、测试与基础资源链路，不替代真机相机/视频性能、HDR/EDR 视觉质量、CocoaPods resource bundle 或全部 Apple 平台运行时验证。

## 版本演进原则

- Harbeth 3.0 以当前底座定位作为新的公开基线，不为历史 typo alias、旧 runtime facade 或已退出的平台继续叠加兼容层。
- `Sources/Compute/Combination/` 的既有组合滤镜继续作为公开能力维护；新的私有 look、preset 和商业资源不回灌到 Harbeth。
- `RenderView`、`SampleBufferPreviewHost` 与 PreviewHost contract 属于 Harbeth 的核心 texture/frame preview substrate；camera、player、recorder、timeline 和 export 编排属于上层媒体引擎或宿主。
- 通用 mask、geometry、optics、transition 和 post-render analysis 属于 Harbeth primitive；模型、审美策略、产品任务编排与私有资产不属于 Harbeth。
- `HarbethIO.output()` 是文档、Demo 和新接入的标准错误可观察入口。
- `HarbethIO.transmitOutput(...)` 是对应的核心异步入口；有滤镜时进入 render operation queue，回调线程不保证，空滤镜路径允许同步完成。
- 重大定位调整在 major release 直接形成清晰的新表面，不为不再成立的历史形态背包袱。

## 事实口径

- 性能结论必须附带设备、分辨率、pixel format、滤镜链、预热状态、帧数和分位数，不能从单一桌面测试外推真机结果。
- HDR 需要分别验证 transfer conversion、gamut、pixel precision、tone mapping、metadata 和最终显示/导出；存在 HDR contract 不等于完整色彩管理已经完成。
- allocator、cache、graph optimizer 和 diagnostics 只按真实执行能力描述；规划或 capability label 不能包装成尚未实现的 runtime。
- 平台支持以 SwiftPM、CocoaPods、Xcode target、SwiftUI/MPS availability 和实际验证矩阵共同判断，不能只读取一个 deployment target。

## CHANGELOG 边界

`CHANGELOG.md` 面向升级 Harbeth 的使用者，不用于复制 commit 历史。

- 功能链路完成时，如果包含公开 API、可观察行为、输出正确性、性能/资源特征、平台或依赖要求、弃用/移除、安全性、重要用户可见 bug 修复，就在同一功能提交中加入 `Unreleased`。
- 纯内部重构、测试补充、CI/维护规则、格式或错别字不记录，除非它们实际改变了使用、兼容或发布合同。
- 正式发版时，把已经交付的 `Unreleased` 条目归入带日期版本章节，更新 compare link，并保留新的空 `Unreleased`。
- CHANGELOG 描述使用者得到的结果和迁移影响，不按 commit 数量拆分过程步骤。

## 发布检查

1. 复核 `CHANGELOG.md` 的 `Unreleased`，只保留本次版本实际交付且使用者需要知道的条目；
2. 运行 SwiftPM build/test；
3. 构建 iOS、macOS、tvOS framework 与 UIKit、SwiftUI、AppKit Demo；
4. 验证 Metal library 与新增 kernel 可加载；
5. 运行 DocC build 与 CocoaPods lint，或明确记录未验证项；
6. 核对 README、Package.swift、podspec 与 release tag 的版本和平台口径；
7. 确认本地维护文件、Agent 规则和临时证据没有进入提交。
