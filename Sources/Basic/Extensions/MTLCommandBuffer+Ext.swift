//
//  MTLCommandBuffer+Ext.swift
//  Harbeth
//
//  Created by Condy on 2023/8/8.
//

import Foundation
import MetalKit

extension MTLCommandBuffer {
    
    /// Asynchronous submission of texture drawing.
    /// - Parameters:
    ///   - texture: Metal texture.
    ///   - complete: Success or failure callback.
    func asyncCommit(texture: MTLTexture, complete: @escaping (Result<MTLTexture, CustomError>) -> Void) {
        self.addCompletedHandler { (buffer) in
            switch buffer.status {
            case .completed:
                complete(.success(texture))
            case .error where buffer.error != nil:
                complete(.failure(.error(buffer.error!)))
            default:
                break
            }
        }
        self.commit()
    }
    
    func commitAndWaitUntilCompleted() {
        // Commit a command buffer so it can be executed as soon as possible.
        self.commit()
        // Wait to make sure that output texture contains new data.
        self.waitUntilCompleted()
    }
}
