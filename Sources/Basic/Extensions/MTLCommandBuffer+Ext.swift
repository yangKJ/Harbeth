//
//  MTLCommandBuffer+Ext.swift
//  Harbeth
//
//  Created by Condy on 2023/8/8.
//

import Foundation
@preconcurrency import MetalKit

extension MTLCommandBuffer {
    
    func commitAndWaitUntilCompleted(identifier: String) throws {
        if HarbethContext.shared.enablePerformanceMonitor {
            HarbethContext.shared.performanceMonitor.beginGPUOperation(identifier)
            // Commit a command buffer so it can be executed as soon as possible.
            self.commit()
            // Wait to make sure that output texture contains new data.
            self.waitUntilCompleted()
            HarbethContext.shared.performanceMonitor.completeGPUOperation(identifier, commandBuffer: self)
        } else {
            // Commit a command buffer so it can be executed as soon as possible.
            self.commit()
            // Wait to make sure that output texture contains new data.
            self.waitUntilCompleted()
        }
        if let completionError = CommandBufferCompletionValidator.error(status: status, underlyingError: error) {
            throw completionError
        }
    }
    
    /// Asynchronous submission of texture drawing with GPU time recording.
    func asyncCommit(identifier: String, complete: @escaping @Sendable (Result<Void, HarbethError>) -> Void) {
        if HarbethContext.shared.enablePerformanceMonitor {
            HarbethContext.shared.performanceMonitor.beginGPUOperation(identifier)
            self.addCompletedHandler { (buffer) in
                HarbethContext.shared.performanceMonitor.completeGPUOperation(identifier, commandBuffer: buffer)
                switch buffer.status {
                case .completed: complete(.success(()))
                case .error where buffer.error != nil: complete(.failure(.error(buffer.error!)))
                default: complete(.failure(.commandBufferAsyncCommit(buffer.status)))
                }
            }
        } else {
            self.addCompletedHandler { (buffer) in
                switch buffer.status {
                case .completed: complete(.success(()))
                case .error where buffer.error != nil: complete(.failure(.error(buffer.error!)))
                default: complete(.failure(.commandBufferAsyncCommit(buffer.status)))
                }
            }
        }
        self.commit()
    }
    
    /// Real-time submission: commit and wait until scheduled, not completed.
    /// Used for low-latency frame scenarios like live capture and video playback.
    func realTimeCommit(identifier: String, complete: @escaping @Sendable () -> Void) {
        // 性能监控不能改变输出交付时机。
        if HarbethContext.shared.enablePerformanceMonitor {
            HarbethContext.shared.performanceMonitor.beginGPUOperation(identifier)
            self.addCompletedHandler { buffer in
                HarbethContext.shared.performanceMonitor.completeGPUOperation(identifier, commandBuffer: buffer)
            }
        }

        // 先提交并等到 scheduled，再以一致语义交付输出。
        self.commit()
        self.waitUntilScheduled()
        complete()
    }
}

enum CommandBufferCompletionValidator {
    static func error(status: MTLCommandBufferStatus, underlyingError: Error?) -> HarbethError? {
        switch status {
        case .completed:
            return nil
        case .error where underlyingError != nil:
            return .error(underlyingError!)
        default:
            return .commandBufferAsyncCommit(status)
        }
    }
}
