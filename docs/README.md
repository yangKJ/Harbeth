# Harbeth Documentation / 文档导航

Harbeth 对普通调用方只有两条主路线：`HarbethIO` 用于直接处理，`ImageNode` 用于高级统一编辑与结果合同。下面按问题选择文档，不需要从 runtime 目录开始阅读。

## Start here / 从这里开始

| 你要解决的问题 | 文档 |
| --- | --- |
| 选择 `HarbethIO` 或 `ImageNode`，了解输入、输出和 supporting API | [公开 API 分层](API_SURFACE_CN.md) |
| 查看全部公开滤镜、组合滤镜、Blend、MPS、Blit 与 Render 类型 | [滤镜目录](FILTER_CATALOG.md) |
| 编写 Compute/Render/MPS/Blit/Combination 或接入自有 Metal library | [自定义滤镜指南](CUSTOM_FILTERS.md) |
| 理解源码目录、能力边界和两条路线的映射 | [能力地图](CAPABILITY_MAP_CN.md) |
| 处理黑屏、异步、颜色、HDR、方向、实时性能或内存问题 | [故障排查](TROUBLESHOOTING.md) |
| 做可复现性能测量与 profile 选择 | [性能治理指南](PERFORMANCE_GOVERNANCE_CN.md) |
| 从 2.x 升级、启用真实 MTLHeap 或核对 3.0 breaking changes | [3.0 迁移指南](MIGRATION_3_CN.md) |

## API reference / API 参考

- [DocC 首页](../Sources/Harbeth.docc/Harbeth.md)
- [HarbethIO](../Sources/Harbeth.docc/HarbethIO.md)
- [ImageNode](../Sources/Harbeth.docc/ImageNode.md)
- [Preview Hosting](../Sources/Harbeth.docc/PreviewHost.md)
- [Contracts and Diagnostics](../Sources/Harbeth.docc/ContractsAndDiagnostics.md)

## Maintenance / 维护与发布

- [维护与发布门禁](MAINTAINING.md)
- [CHANGELOG](../CHANGELOG.md)
- [Issue 表单](../.github/ISSUE_TEMPLATE/bug_report.yml)

文档描述必须以当前 checkout 的源码、Package.swift、podspec、Xcode targets 和验证结果为准。README 只保留 first-touch 信息；完整目录、滤镜开发、排错和维护细节由本目录承接。
