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
    private var released = false
    private let lock = NSLock()

    public init(texture: MTLTexture, logicalExtent: C7Size? = nil, releaseHandler: (() -> Void)? = nil) {
        self.texture = texture
        self.logicalExtent = logicalExtent ?? C7Size(texture: texture)
        self.releaseHandler = releaseHandler
    }

    deinit { release() }

    public func release() {
        lock.lock()
        defer { lock.unlock() }
        guard released == false else { return }
        released = true
        releaseHandler?()
    }
}
