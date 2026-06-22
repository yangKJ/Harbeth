//
//  CommandBufferPool.swift
//  Harbeth
//
//  Created by Condy on 2026/3/23.
//

import Foundation
import Metal

/// Command buffer pool for reusing command buffers
final class CommandBufferPool {
    private let queue = DispatchQueue(label: "com.harbeth.commandbuffer.pool")
    private var pool: [MTLCommandBuffer] = []
    private let maxSize: Int
    private weak var commandQueue: MTLCommandQueue?
    
    init(maxSize: Int = 4, commandQueue: MTLCommandQueue) {
        self.maxSize = maxSize
        self.commandQueue = commandQueue
        prewarm()
    }
    
    private func prewarm() {
        for _ in 0..<maxSize {
            if let buffer = commandQueue?.makeCommandBuffer() {
                pool.append(buffer)
            }
        }
    }
    
    func get() -> MTLCommandBuffer? {
        return queue.sync {
            if !pool.isEmpty {
                return pool.removeFirst()
            }
            // If pool is empty, create a new command buffer
            return commandQueue?.makeCommandBuffer()
        }
    }
    
    func put(_ buffer: MTLCommandBuffer) {
        queue.sync {
            // Only return command buffers that are not enqueued
            if buffer.status == .notEnqueued && pool.count < maxSize {
                pool.append(buffer)
            }
        }
    }
}
