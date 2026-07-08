//
//  PluginBoundaryAdapter.swift
//  Harbeth
//
//  Created by Condy on 2026/7/2.
//

import Foundation

/// Runtime 内部的插件边界适配器。
///
/// 对外能力只通过 `Plugin` 暴露；这里仅供 RenderGraph
/// 描述插件边界对 fusion、readback、cache 和低延迟帧流的影响。
protocol PluginBoundaryAdapter {
    var capability: PluginCapability { get }
    func render(input: RenderedFrame, context: PluginContext) throws -> RenderedFrame
}

extension PluginBoundaryAdapter {
    var kind: PluginBoundaryKind {
        capability.kind
    }
}
