//
//  PluginBoundaryAdapter.swift
//  Harbeth
//
//  Created by Condy on 2026/7/2.
//

import Foundation

/// Runtime 内部的插件边界适配器。
///
/// ImageNode 在建图前完成插件调用；图内只保留边界描述，不能把它当作执行节点。
protocol PluginBoundaryAdapter {
    var capability: PluginCapability { get }
}

extension PluginBoundaryAdapter {
    var kind: PluginBoundaryKind {
        capability.kind
    }
}

struct PluginOutputBoundary<P: Plugin>: PluginBoundaryAdapter {
    let plugin: P
    let capability: PluginCapability
    let identifier: String

    init(plugin: P) {
        self.plugin = plugin
        capability = plugin.capability
        identifier = plugin.pluginIdentifier
    }

    func validate(profile: RenderProfile) throws {
        guard !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HarbethError.configurationInvalid("插件标识不能为空。")
        }
        if profile == .interactiveLatency, !capability.supportsLowLatencyFrameFlow {
            throw HarbethError.configurationInvalid("插件未声明支持低延迟帧流。")
        }
    }

    func makeOutput(input: RenderedFrame, context: PluginContext) throws -> PluginOutput {
        let output = try plugin.makeOutput(frame: input, context: context)
        // 输入透传必须连同租约保留；单独持有 MTLTexture 不能阻止纹理归池。
        if case .texture(let texture) = output, texture === input.texture {
            return .frame(input)
        }
        if case .frame(let frame) = output, frame.texture === input.texture {
            return .frame(frame.retainingSourceFrame(input))
        }
        return output
    }
}
