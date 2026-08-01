//
//  ExecutionScheduler.swift
//  Harbeth
//
//  Created by Condy on 2026/8/1.
//

import Foundation
@preconcurrency import Metal

final class ExecutionScheduler: @unchecked Sendable {
    private let device: MTLDevice
    private let lock = NSLock()
    private var commandQueueStorage: MTLCommandQueue
    private var operationQueueStorage: OperationQueue
    private var generationStorage: UInt64 = 0

    init(device: MTLDevice) {
        self.device = device
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Could not create command queue")
        }
        self.commandQueueStorage = commandQueue
        self.operationQueueStorage = Self.makeOperationQueue()
    }

    var commandQueue: MTLCommandQueue {
        lock.withLock { commandQueueStorage }
    }

    var operationQueue: OperationQueue {
        lock.withLock { operationQueueStorage }
    }

    var generation: UInt64 {
        lock.withLock { generationStorage }
    }

    var maxConcurrentOperationCount: Int {
        get { operationQueue.maxConcurrentOperationCount }
        set { operationQueue.maxConcurrentOperationCount = max(newValue, 1) }
    }

    func makeCommandBuffer() -> MTLCommandBuffer? {
        commandQueue.makeCommandBuffer()
    }

    @discardableResult
    func recover() -> UInt64 {
        guard let replacementQueue = device.makeCommandQueue() else {
            return generation
        }
        let replacementOperations = Self.makeOperationQueue(maxConcurrentOperationCount)
        return lock.withLock {
            operationQueueStorage.cancelAllOperations()
            commandQueueStorage = replacementQueue
            operationQueueStorage = replacementOperations
            generationStorage &+= 1
            return generationStorage
        }
    }

    private static func makeOperationQueue(_ maxConcurrentOperationCount: Int = 4) -> OperationQueue {
        let queue = OperationQueue()
        queue.name = "com.harbeth.render.operation"
        queue.qualityOfService = .userInteractive
        queue.maxConcurrentOperationCount = max(maxConcurrentOperationCount, 1)
        return queue
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
