//
//  ExecutionScheduler.swift
//  Harbeth
//
//  Created by Condy on 2026/8/1.
//

import Foundation
@preconcurrency import Metal

final class ExecutionScheduler: @unchecked Sendable {
    private final class SubmissionRecord: @unchecked Sendable {
        enum Phase {
            case queued
            case executing
            case commitClaimed
        }

        let state: RenderSubmissionStateStorage
        let operation: BlockOperation
        let executionGeneration: UInt64
        let commandQueue: MTLCommandQueue
        let scopeIdentifier: String?
        let onDiscard: @Sendable (RenderSubmissionDiscardReason) -> Void
        var phase: Phase = .queued

        init(
            state: RenderSubmissionStateStorage,
            operation: BlockOperation,
            executionGeneration: UInt64,
            commandQueue: MTLCommandQueue,
            scopeIdentifier: String?,
            onDiscard: @escaping @Sendable (RenderSubmissionDiscardReason) -> Void
        ) {
            self.state = state
            self.operation = operation
            self.executionGeneration = executionGeneration
            self.commandQueue = commandQueue
            self.scopeIdentifier = scopeIdentifier
            self.onDiscard = onDiscard
        }
    }

    private let device: MTLDevice
    private let lock = NSLock()
    private var commandQueueStorage: MTLCommandQueue
    private var operationQueueStorage: OperationQueue
    private var generationStorage: UInt64 = 0
    private var submissions: [String: SubmissionRecord] = [:]
    private var latestSubmissionByScope: [String: String] = [:]

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
    func submit(
        sourceIdentifier: String,
        policy: RenderSubmissionPolicy,
        execute: @escaping @Sendable (RenderSubmissionContext) -> Void,
        onDiscard: @escaping @Sendable (RenderSubmissionDiscardReason) -> Void
    ) -> RenderSubmissionHandle {
        let identifier = UUID().uuidString
        let executionSnapshot = lock.withLock {
            (generation: generationStorage, commandQueue: commandQueueStorage, operationQueue: operationQueueStorage)
        }
        let generation = executionSnapshot.generation
        let state = RenderSubmissionStateStorage(
            identifier: identifier,
            sourceIdentifier: sourceIdentifier,
            executionGeneration: generation,
            policy: policy
        )
        let context = RenderSubmissionContext(identifier: identifier, scheduler: self)
        let operation = BlockOperation { [weak self] in
            guard self?.beginSubmission(identifier: identifier) == true else { return }
            execute(context)
        }
        let scopeIdentifier = policy.behavior == .latestOnly ? policy.resolvedScopeIdentifier ?? sourceIdentifier : nil
        let record = SubmissionRecord(
            state: state,
            operation: operation,
            executionGeneration: generation,
            commandQueue: executionSnapshot.commandQueue,
            scopeIdentifier: scopeIdentifier,
            onDiscard: onDiscard
        )

        let registration = lock.withLock { () -> (OperationQueue?, String?, Bool) in
            guard generation == generationStorage,
                  executionSnapshot.commandQueue === commandQueueStorage,
                  executionSnapshot.operationQueue === operationQueueStorage else {
                return (nil, nil, true)
            }
            let supersededIdentifier = scopeIdentifier.flatMap { latestSubmissionByScope[$0] }
            submissions[identifier] = record
            if let scopeIdentifier {
                latestSubmissionByScope[scopeIdentifier] = identifier
            }
            return (executionSnapshot.operationQueue, supersededIdentifier, false)
        }

        let handle = RenderSubmissionHandle(state: state) { [weak self] in
            self?.discardSubmission(identifier: identifier, reason: .callerCancelled)
        }

        if registration.2 {
            state.update(state: .discarded, discardReason: .executionRecovery)
            onDiscard(.executionRecovery)
            return handle
        }

        if let supersededIdentifier = registration.1 {
            discardSubmission(identifier: supersededIdentifier, reason: .superseded)
        }
        registration.0?.addOperation(operation)

        return handle
    }

    private func beginSubmission(identifier: String) -> Bool {
        let result = lock.withLock { () -> (Bool, SubmissionRecord?) in
            guard let record = submissions[identifier] else { return (false, nil) }
            guard record.executionGeneration == generationStorage else {
                return (false, record)
            }
            record.phase = .executing
            record.state.update(state: .executing)
            return (true, nil)
        }
        if let staleRecord = result.1 {
            discardSubmission(record: staleRecord, identifier: identifier, reason: .executionRecovery)
        }
        return result.0
    }

    func isSubmissionActive(identifier: String) -> Bool {
        lock.withLock { submissions[identifier] != nil }
    }

    func makeCommandBuffer(identifier: String) -> MTLCommandBuffer? {
        lock.withLock {
            guard let record = submissions[identifier],
                  record.phase == .executing else {
                return nil
            }
            return record.commandQueue.makeCommandBuffer()
        }
    }

    /// 原子地把活跃提交转入已认领提交权的阶段。
    /// 此后的替换或恢复只能抑制交付，不能伪装成已同步取消 Metal 工作。
    func claimCommit(identifier: String) -> Bool {
        lock.withLock {
            guard let record = submissions[identifier],
                  record.phase == .executing else {
                return false
            }
            record.phase = .commitClaimed
            return true
        }
    }

    @discardableResult
    func completeSubmission(identifier: String, delivery: @escaping @Sendable () -> Void) -> Bool {
        let record = lock.withLock { () -> SubmissionRecord? in
            guard let record = submissions.removeValue(forKey: identifier) else { return nil }
            if let scopeIdentifier = record.scopeIdentifier,
               latestSubmissionByScope[scopeIdentifier] == identifier {
                latestSubmissionByScope.removeValue(forKey: scopeIdentifier)
            }
            record.state.update(state: .completed)
            return record
        }
        guard record != nil else { return false }
        delivery()
        return true
    }

    private func discardSubmission(identifier: String, reason: RenderSubmissionDiscardReason) {
        let record = lock.withLock { submissions[identifier] }
        guard let record else { return }
        discardSubmission(record: record, identifier: identifier, reason: reason)
    }

    private func discardSubmission(
        record: SubmissionRecord,
        identifier: String,
        reason: RenderSubmissionDiscardReason
    ) {
        let removed = lock.withLock { () -> Bool in
            guard submissions.removeValue(forKey: identifier) != nil else { return false }
            if let scopeIdentifier = record.scopeIdentifier,
               latestSubmissionByScope[scopeIdentifier] == identifier {
                latestSubmissionByScope.removeValue(forKey: scopeIdentifier)
            }
            let state: RenderSubmissionState = reason == .callerCancelled ? .cancelled : .discarded
            record.state.update(state: state, discardReason: reason)
            record.operation.cancel()
            return true
        }
        if removed { record.onDiscard(reason) }
    }

    @discardableResult
    func recover() -> UInt64 {
        guard let replacementQueue = device.makeCommandQueue() else {
            return generation
        }
        let replacementOperations = Self.makeOperationQueue(maxConcurrentOperationCount)
        let recovery = lock.withLock { () -> (UInt64, [SubmissionRecord]) in
            operationQueueStorage.cancelAllOperations()
            let activeSubmissions = Array(submissions.values)
            submissions.removeAll()
            latestSubmissionByScope.removeAll()
            commandQueueStorage = replacementQueue
            operationQueueStorage = replacementOperations
            generationStorage &+= 1
            return (generationStorage, activeSubmissions)
        }
        recovery.1.forEach { record in
            record.state.update(state: .discarded, discardReason: .executionRecovery)
            record.operation.cancel()
            record.onDiscard(.executionRecovery)
        }
        return recovery.0
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
