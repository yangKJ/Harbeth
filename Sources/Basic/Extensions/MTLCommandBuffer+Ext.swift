//
//  MTLCommandBuffer+Ext.swift
//  Harbeth
//
//  Created by Condy on 2023/8/8.
//

import Foundation
import MetalKit

extension MTLCommandBuffer {
    
    func commitAndWaitUntilCompleted(identifier: String) {
        if Shared.shared.enablePerformanceMonitor {
            let startTime = CACurrentMediaTime()
            
            // Commit a command buffer so it can be executed as soon as possible.
            self.commit()
            // Wait to make sure that output texture contains new data.
            self.waitUntilCompleted()
            
            let endTime = CACurrentMediaTime()
            let gpuTimeNanoseconds = UInt64((endTime - startTime) * 1e9)
            Shared.shared.performanceMonitor?.recordGPUTime(identifier, nanoseconds: gpuTimeNanoseconds)
        } else {
            // Commit a command buffer so it can be executed as soon as possible.
            self.commit()
            // Wait to make sure that output texture contains new data.
            self.waitUntilCompleted()
        }
    }
    
    /// Asynchronous submission of texture drawing with GPU time recording.
    func asyncCommit(identifier: String, complete: @escaping (Result<Void, HarbethError>) -> Void) {
        if Shared.shared.enablePerformanceMonitor {
            let startTime = CACurrentMediaTime()
            self.addCompletedHandler { (buffer) in
                let endTime = CACurrentMediaTime()
                let gpuTimeNanoseconds = UInt64((endTime - startTime) * 1e9)
                Shared.shared.performanceMonitor?.recordGPUTime(identifier, nanoseconds: gpuTimeNanoseconds)
                
                switch buffer.status {
                case .completed:
                    complete(.success(()))
                case .error where buffer.error != nil:
                    complete(.failure(.error(buffer.error!)))
                default:
                    complete(.failure(.commandBufferAsyncCommit(buffer.status)))
                }
            }
        } else {
            self.addCompletedHandler { (buffer) in
                switch buffer.status {
                case .completed:
                    complete(.success(()))
                case .error where buffer.error != nil:
                    complete(.failure(.error(buffer.error!)))
                default:
                    complete(.failure(.commandBufferAsyncCommit(buffer.status)))
                }
            }
        }
        self.commit()
    }
}
