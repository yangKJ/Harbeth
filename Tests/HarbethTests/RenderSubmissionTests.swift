//
//  RenderSubmissionTests.swift
//  Harbeth
//
//  Created by Condy on 2026/8/2.
//

import Foundation
import XCTest
@preconcurrency import Metal
@testable import Harbeth

final class RenderSubmissionTests: XCTestCase {

    func testRenderSubmissionPolicyRoundTripsCodableFields() throws {
        let policy = RenderSubmissionPolicy(
            behavior: .latestOnly,
            scopeIdentifier: "editor.preview"
        )

        XCTAssertEqual(policy.behavior, .latestOnly)
        XCTAssertEqual(policy.scopeIdentifier, "editor.preview")
        XCTAssertEqual(RenderSubmissionPolicy.independent.behavior, .independent)
        XCTAssertNil(RenderSubmissionPolicy.independent.scopeIdentifier)

        let data = try JSONEncoder().encode(policy)
        let decoded = try JSONDecoder().decode(RenderSubmissionPolicy.self, from: data)
        XCTAssertEqual(decoded, policy)
    }

    func testQueuedSubmissionCallerCancelIsExactlyOnce() throws {
        let (context, queue) = try makeSuspendedContext()
        defer {
            queue.isSuspended = false
            context.recoverExecution()
        }

        let discards = DiscardRecorder()
        let handle = context.submitRenderOperation(
            sourceIdentifier: "caller-cancel",
            policy: .independent,
            execute: { _ in },
            onDiscard: { discards.record($0) }
        )

        XCTAssertEqual(handle.snapshot.state, .queued)
        handle.cancel()
        handle.cancel()

        XCTAssertEqual(discards.reasons, [.callerCancelled])
        XCTAssertEqual(handle.snapshot.state, .cancelled)
        XCTAssertEqual(handle.snapshot.discardReason, .callerCancelled)
    }

    func testLatestOnlySupersedesQueuedSubmissionAndDeliversLatest() async throws {
        let (context, queue) = try makeSuspendedContext()
        defer {
            queue.isSuspended = false
            context.recoverExecution()
        }

        let firstDiscards = DiscardRecorder()
        let secondDiscards = DiscardRecorder()
        let secondDelivery = expectation(description: "latest submission delivery")
        let firstExecution = ExecutionRecorder()

        let first = context.submitRenderOperation(
            sourceIdentifier: "latest-first",
            policy: .latestOnly(scopeIdentifier: "editor.preview"),
            execute: { _ in firstExecution.record() },
            onDiscard: { firstDiscards.record($0) }
        )
        let second = context.submitRenderOperation(
            sourceIdentifier: "latest-second",
            policy: .latestOnly(scopeIdentifier: "editor.preview"),
            execute: { submission in
                _ = submission.deliver { secondDelivery.fulfill() }
            },
            onDiscard: { secondDiscards.record($0) }
        )

        XCTAssertEqual(firstDiscards.reasons, [.superseded])
        XCTAssertEqual(first.snapshot.state, .discarded)
        XCTAssertEqual(first.snapshot.discardReason, .superseded)
        XCTAssertEqual(second.snapshot.state, .queued)

        queue.isSuspended = false
        await fulfillment(of: [secondDelivery], timeout: 2.0)

        XCTAssertEqual(firstExecution.count, 0)
        XCTAssertEqual(secondDiscards.reasons, [])
        XCTAssertEqual(second.snapshot.state, .completed)
        XCTAssertNil(second.snapshot.discardReason)
    }

    func testLatestOnlyScopesDoNotCancelEachOther() async throws {
        let (context, queue) = try makeSuspendedContext()
        defer {
            queue.isSuspended = false
            context.recoverExecution()
        }

        let firstDiscards = DiscardRecorder()
        let secondDiscards = DiscardRecorder()
        let firstDelivery = expectation(description: "first scope delivery")
        let secondDelivery = expectation(description: "second scope delivery")

        let first = context.submitRenderOperation(
            sourceIdentifier: "scope-a",
            policy: .latestOnly(scopeIdentifier: "scope-a"),
            execute: { submission in
                _ = submission.deliver { firstDelivery.fulfill() }
            },
            onDiscard: { firstDiscards.record($0) }
        )
        let second = context.submitRenderOperation(
            sourceIdentifier: "scope-b",
            policy: .latestOnly(scopeIdentifier: "scope-b"),
            execute: { submission in
                _ = submission.deliver { secondDelivery.fulfill() }
            },
            onDiscard: { secondDiscards.record($0) }
        )

        XCTAssertEqual(first.snapshot.state, .queued)
        XCTAssertEqual(second.snapshot.state, .queued)
        XCTAssertEqual(firstDiscards.reasons, [])
        XCTAssertEqual(secondDiscards.reasons, [])

        queue.isSuspended = false
        await fulfillment(of: [firstDelivery, secondDelivery], timeout: 2.0)

        XCTAssertEqual(first.snapshot.state, .completed)
        XCTAssertEqual(second.snapshot.state, .completed)
        XCTAssertEqual(firstDiscards.reasons, [])
        XCTAssertEqual(secondDiscards.reasons, [])
    }

    func testRecoverExecutionDiscardsQueuedSubmissionExactlyOnce() throws {
        let (context, queue) = try makeSuspendedContext()
        defer {
            queue.isSuspended = false
            context.recoverExecution()
        }

        let discards = DiscardRecorder()
        let execution = ExecutionRecorder()
        let handle = context.submitRenderOperation(
            sourceIdentifier: "execution-recovery",
            policy: .independent,
            execute: { _ in execution.record() },
            onDiscard: { discards.record($0) }
        )

        XCTAssertEqual(handle.snapshot.state, .queued)
        context.recoverExecution()
        handle.cancel()

        XCTAssertEqual(execution.count, 0)
        XCTAssertEqual(discards.reasons, [.executionRecovery])
        XCTAssertEqual(handle.snapshot.state, .discarded)
        XCTAssertEqual(handle.snapshot.discardReason, .executionRecovery)
    }

    func testRecoveredExecutingSubmissionCannotCreateBufferFromReplacementQueue() async throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable in this environment.")
        }
        let scheduler = ExecutionScheduler(device: device)
        let started = HarbethUncheckedTransfer(value: expectation(description: "old generation started"))
        let finished = HarbethUncheckedTransfer(value: expectation(description: "old generation resumed"))
        let resumeExecution = DispatchSemaphore(value: 0)
        let bufferCreated = BoolRecorder()
        let discards = DiscardRecorder()

        let handle = scheduler.submit(
            sourceIdentifier: "old-generation-buffer",
            policy: .independent,
            execute: { submission in
                started.value.fulfill()
                _ = resumeExecution.wait(timeout: .now() + 2)
                bufferCreated.value = submission.makeCommandBuffer() != nil
                finished.value.fulfill()
            },
            onDiscard: { discards.record($0) }
        )

        await fulfillment(of: [started.value], timeout: 2.0)
        _ = scheduler.recover()
        resumeExecution.signal()
        await fulfillment(of: [finished.value], timeout: 2.0)

        XCTAssertFalse(bufferCreated.value, "恢复后的旧 submission 不得从 replacement queue 创建 command buffer。")
        XCTAssertEqual(handle.snapshot.state, .discarded)
        XCTAssertEqual(handle.snapshot.discardReason, .executionRecovery)
        XCTAssertEqual(discards.reasons, [.executionRecovery])
    }

    func testSupersedingCommitClaimedSubmissionSuppressesDeliveryExactlyOnce() async throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable in this environment.")
        }
        let scheduler = ExecutionScheduler(device: device)
        let firstClaimed = HarbethUncheckedTransfer(value: expectation(description: "first submission claimed commit"))
        let firstFinished = HarbethUncheckedTransfer(value: expectation(description: "first submission attempted delivery"))
        let secondDelivered = HarbethUncheckedTransfer(value: expectation(description: "second submission delivered"))
        let releaseFirstDelivery = DispatchSemaphore(value: 0)
        let firstDelivery = BoolRecorder()
        let firstDiscards = DiscardRecorder()

        let first = scheduler.submit(
            sourceIdentifier: "commit-claimed-first",
            policy: .latestOnly(scopeIdentifier: "commit-claimed"),
            execute: { submission in
                firstDelivery.value = submission.claimCommit()
                firstClaimed.value.fulfill()
                _ = releaseFirstDelivery.wait(timeout: .now() + 2)
                firstDelivery.deliverySucceeded = submission.deliver {}
                firstFinished.value.fulfill()
            },
            onDiscard: { firstDiscards.record($0) }
        )

        await fulfillment(of: [firstClaimed.value], timeout: 2.0)
        let second = scheduler.submit(
            sourceIdentifier: "commit-claimed-second",
            policy: .latestOnly(scopeIdentifier: "commit-claimed"),
            execute: { submission in
                _ = submission.deliver { secondDelivered.value.fulfill() }
            },
            onDiscard: { _ in XCTFail("最新 submission 不应被丢弃。") }
        )

        await fulfillment(of: [secondDelivered.value], timeout: 2.0)
        releaseFirstDelivery.signal()
        await fulfillment(of: [firstFinished.value], timeout: 2.0)
        first.cancel()

        XCTAssertTrue(firstDelivery.value, "首个 submission 必须在被替换前成功 claim commit。")
        XCTAssertFalse(firstDelivery.deliverySucceeded, "claim commit 后被 supersede 的 submission 只能抑制 delivery。")
        XCTAssertEqual(first.snapshot.state, .discarded)
        XCTAssertEqual(first.snapshot.discardReason, .superseded)
        XCTAssertEqual(firstDiscards.reasons, [.superseded])
        XCTAssertEqual(second.snapshot.state, .completed)
    }

    private func makeSuspendedContext() throws -> (HarbethContext, OperationQueue) {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")

        let context = HarbethContext.shared
        context.recoverExecution()
        let queue = context.renderOperationQueue
        queue.isSuspended = true
        return (context, queue)
    }
}

private final class DiscardRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [RenderSubmissionDiscardReason] = []

    func record(_ reason: RenderSubmissionDiscardReason) {
        lock.lock()
        storage.append(reason)
        lock.unlock()
    }

    var reasons: [RenderSubmissionDiscardReason] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private final class ExecutionRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    func record() {
        lock.lock()
        storage += 1
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private final class BoolRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = false
    private var storedDeliverySucceeded = false

    var value: Bool {
        get { lock.withLock { storedValue } }
        set { lock.withLock { storedValue = newValue } }
    }

    var deliverySucceeded: Bool {
        get { lock.withLock { storedDeliverySucceeded } }
        set { lock.withLock { storedDeliverySucceeded = newValue } }
    }
}
