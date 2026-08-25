//
//  MaskCommandBuffer.swift
//  Harbeth
//
//  Created by Condy on 2026/8/25.
//

import Metal

/// Mask 内部同步 pass 的 command buffer 选择：Harbeth 自有 device 复用 shared context，
/// 外部 device 保留隔离 queue，避免把外部资源提交到错误的 device。
@inline(__always)
func makeMaskCommandBuffer(for device: MTLDevice) -> MTLCommandBuffer? {
    if device === HarbethContext.shared.device {
        return HarbethContext.shared.makeCommandBuffer()
    }
    return device.makeCommandQueue()?.makeCommandBuffer()
}
