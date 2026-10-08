//
//  RenderPipelineCreation.swift
//  Harbeth
//
//  Created by Condy on 2026/10/07.
//

import Foundation
import Metal

/// 仅保留一次在途 render pipeline 创建的结果，失败会广播给全部等待者。
final class RenderPipelineCreation {
    private let condition = NSCondition()
    private let owner = Thread.current
    private var result: Result<MTLRenderPipelineState, Error>?

    func waitForResult() throws -> MTLRenderPipelineState {
        guard Thread.current !== owner else {
            throw HarbethError.configurationInvalid("同一线程不能递归创建正在等待的 render pipeline。")
        }
        condition.lock()
        while result == nil { condition.wait() }
        let completed = result!
        condition.unlock()
        return try completed.get()
    }

    func complete(_ result: Result<MTLRenderPipelineState, Error>) {
        condition.lock()
        self.result = result
        condition.broadcast()
        condition.unlock()
    }
}
