//
//  TextureLease.swift
//  Harbeth
//
//  Created by Condy on 2026/7/2.
//

import Foundation
@preconcurrency import Metal

/// 纹理租约：用于把资源归还和 command buffer 生命周期绑定。
public final class TextureLease: @unchecked Sendable {
    public let texture: MTLTexture
    public let logicalExtent: C7Size
    private let releaseHandler: (() -> Void)?
    private let lock = NSLock()
    private var releaseRequested = false
    private var released = false
    private var inFlightUseCount = 0

    public init(texture: MTLTexture, logicalExtent: C7Size? = nil, releaseHandler: (() -> Void)? = nil) {
        self.texture = texture
        self.logicalExtent = logicalExtent ?? C7Size(texture: texture)
        self.releaseHandler = releaseHandler
    }

    deinit { release() }

    public func release() {
        let handler: (() -> Void)?
        lock.lock()
        releaseRequested = true
        handler = takeReleaseHandlerIfReadyLocked()
        lock.unlock()
        handler?()
    }

    /// 命令缓冲区仍在引用纹理时，即使调用方提前释放，也不把纹理归还池中。
    func retainUntilCompleted(by commandBuffer: MTLCommandBuffer) {
        lock.lock()
        guard released == false, releaseRequested == false else {
            lock.unlock()
            return
        }
        inFlightUseCount += 1
        lock.unlock()

        commandBuffer.addCompletedHandler { [self] _ in
            completeInFlightUse()
        }
    }

    private func completeInFlightUse() {
        let handler: (() -> Void)?
        lock.lock()
        inFlightUseCount = max(inFlightUseCount - 1, 0)
        handler = takeReleaseHandlerIfReadyLocked()
        lock.unlock()
        handler?()
    }

    private func takeReleaseHandlerIfReadyLocked() -> (() -> Void)? {
        guard releaseRequested, inFlightUseCount == 0, released == false else {
            return nil
        }
        released = true
        return releaseHandler
    }
}
