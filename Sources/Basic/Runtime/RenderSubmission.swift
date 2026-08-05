//
//  RenderSubmission.swift
//  Harbeth
//
//  Created by Condy on 2026/8/2.
//

import Foundation

/// Control the relationship between asynchronous rendering submission and existing work in the same range.
public enum RenderSubmissionBehavior: String, Sendable, Codable, Equatable, Hashable {
    /// Each time it is submitted for independent delivery, do not actively replace other work.
    case independent
    /// New submissions replace old work that has not been delivered within the same range.
    case latestOnly
}

public struct RenderSubmissionPolicy: Sendable, Codable, Equatable, Hashable {
    public let behavior: RenderSubmissionBehavior
    public let scopeIdentifier: String?

    public static let independent = RenderSubmissionPolicy(behavior: .independent, scopeIdentifier: nil)

    public init(behavior: RenderSubmissionBehavior, scopeIdentifier: String? = nil) {
        self.behavior = behavior
        self.scopeIdentifier = scopeIdentifier
    }

    public static func latestOnly(scopeIdentifier: String) -> RenderSubmissionPolicy {
        RenderSubmissionPolicy(behavior: .latestOnly, scopeIdentifier: scopeIdentifier)
    }

    var resolvedScopeIdentifier: String? {
        guard behavior == .latestOnly else { return nil }
        let scope = scopeIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return scope.isEmpty ? nil : scope
    }
}

public enum RenderSubmissionState: String, Sendable, Codable, Equatable, Hashable {
    case queued
    case executing
    case completed
    case cancelled
    case discarded
}

public enum RenderSubmissionDiscardReason: String, Sendable, Codable, Equatable, Hashable {
    case callerCancelled
    case superseded
    case executionRecovery
}

public struct RenderSubmissionSnapshot: Sendable, Codable, Equatable, Hashable {
    public let identifier: String
    public let sourceIdentifier: String
    public let executionGeneration: UInt64?
    public let policy: RenderSubmissionPolicy
    public let state: RenderSubmissionState
    public let discardReason: RenderSubmissionDiscardReason?
}

public final class RenderSubmissionHandle: @unchecked Sendable {
    private let state: RenderSubmissionStateStorage
    private let cancellation: @Sendable () -> Void

    init(state: RenderSubmissionStateStorage, cancellation: @escaping @Sendable () -> Void) {
        self.state = state
        self.cancellation = cancellation
    }

    public var snapshot: RenderSubmissionSnapshot {
        state.snapshot
    }

    /// Request cancellation; the final state request maintains power equal.
    public func cancel() {
        cancellation()
    }

    static func completed(sourceIdentifier: String, policy: RenderSubmissionPolicy) -> RenderSubmissionHandle {
        let state = RenderSubmissionStateStorage(
            identifier: UUID().uuidString,
            sourceIdentifier: sourceIdentifier,
            executionGeneration: nil,
            policy: policy,
            state: .completed
        )
        return RenderSubmissionHandle(state: state, cancellation: {})
    }
}

final class RenderSubmissionStateStorage: @unchecked Sendable {
    private let lock = NSLock()
    private let identifier: String
    private let sourceIdentifier: String
    private let executionGeneration: UInt64?
    private let policy: RenderSubmissionPolicy
    private var state: RenderSubmissionState
    private var discardReason: RenderSubmissionDiscardReason?

    init(
        identifier: String,
        sourceIdentifier: String,
        executionGeneration: UInt64?,
        policy: RenderSubmissionPolicy,
        state: RenderSubmissionState = .queued
    ) {
        self.identifier = identifier
        self.sourceIdentifier = sourceIdentifier
        self.executionGeneration = executionGeneration
        self.policy = policy
        self.state = state
    }

    var snapshot: RenderSubmissionSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return RenderSubmissionSnapshot(
            identifier: identifier,
            sourceIdentifier: sourceIdentifier,
            executionGeneration: executionGeneration,
            policy: policy,
            state: state,
            discardReason: discardReason
        )
    }

    func update(state: RenderSubmissionState, discardReason: RenderSubmissionDiscardReason? = nil) {
        lock.lock()
        self.state = state
        self.discardReason = discardReason
        lock.unlock()
    }
}

final class RenderSubmissionContext: @unchecked Sendable {
    let identifier: String
    private weak var scheduler: ExecutionScheduler?

    init(identifier: String, scheduler: ExecutionScheduler) {
        self.identifier = identifier
        self.scheduler = scheduler
    }

    var isActive: Bool {
        scheduler?.isSubmissionActive(identifier: identifier) ?? false
    }

    func makeCommandBuffer() -> MTLCommandBuffer? {
        scheduler?.makeCommandBuffer(identifier: identifier)
    }

    func claimCommit() -> Bool {
        scheduler?.claimCommit(identifier: identifier) ?? false
    }

    @discardableResult
    func deliver(_ body: @escaping @Sendable () -> Void) -> Bool {
        scheduler?.completeSubmission(identifier: identifier, delivery: body) ?? false
    }
}

final class RenderSubmissionCancellationRelay: @unchecked Sendable {
    private let lock = NSLock()
    private var handle: RenderSubmissionHandle?
    private var cancellationRequested = false

    func store(_ handle: RenderSubmissionHandle) {
        lock.lock()
        self.handle = handle
        let shouldCancel = cancellationRequested
        lock.unlock()
        if shouldCancel { handle.cancel() }
    }

    func cancel() {
        lock.lock()
        cancellationRequested = true
        let handle = self.handle
        lock.unlock()
        handle?.cancel()
    }
}
