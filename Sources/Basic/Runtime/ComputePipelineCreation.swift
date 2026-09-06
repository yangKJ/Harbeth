//
//  ComputePipelineCreation.swift
//  Harbeth
//
//  Created by Condy on 2026/09/06.
//

import Foundation
import Metal

/// 仅保留一次在途创建的结果。失败也交付所有等待者，后续调用可重新尝试。
final class ComputePipelineCreation {
    private let condition = NSCondition()
    private let owner = Thread.current
    private var result: Result<MTLComputePipelineState, Error>?

    func waitForResult() throws -> MTLComputePipelineState {
        guard Thread.current !== owner else {
            throw HarbethError.configurationInvalid("同一线程不能递归创建正在等待的 compute pipeline。")
        }
        condition.lock()
        while result == nil { condition.wait() }
        let completed = result!
        condition.unlock()
        return try completed.get()
    }

    func complete(_ result: Result<MTLComputePipelineState, Error>) {
        condition.lock()
        self.result = result
        condition.broadcast()
        condition.unlock()
    }
}
