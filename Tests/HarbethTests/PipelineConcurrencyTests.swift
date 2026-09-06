//
//  PipelineConcurrencyTests.swift
//  Harbeth
//
//  Created by Condy on 2026/9/6.
//

import Foundation
import XCTest
@preconcurrency import Metal
@testable import Harbeth

final class PipelineConcurrencyTests: XCTestCase {
    func testColdComputePipelineLookupIsSharedAcrossConcurrentCallers() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("当前环境没有 Metal 设备。")
        }

        let context = HarbethContext.shared
        let identity = KernelFunctionIdentity(kind: .compute, primaryName: "C7Brightness")
        let start = DispatchSemaphore(value: 0)
        let group = DispatchGroup()
        let results = PipelineLookupRecorder()
        let requestCount = 16
        context.resetCaches()
        let startedAt = DispatchTime.now().uptimeNanoseconds

        for _ in 0..<requestCount {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                start.wait()
                defer { group.leave() }
                do {
                    let pipeline = try Compute.makeComputePipelineState(with: identity)
                    results.record(pipeline)
                } catch {
                    results.record(error)
                }
            }
        }
        for _ in 0..<requestCount { start.signal() }

        let waitResult = group.wait(timeout: .now() + 10)
        let elapsedMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000_000
        guard waitResult == .success else {
            XCTFail("并发冷启动不得无限等待。")
            return
        }
        let coldPipelines = results.pipelines
        let coldIDs = Set(coldPipelines.map(ObjectIdentifier.init))
        XCTAssertTrue(results.error == nil, "并发 pipeline 创建不应失败：\(String(describing: results.error))")
        print("[PipelineColdProbe] requests=\(requestCount) uniqueStates=\(coldIDs.count) elapsedMs=\(elapsedMilliseconds)")
        XCTAssertEqual(coldIDs.count, 1, "同一 identity 的冷启动应共享一个 pipeline state。")

        let warmPipeline = try Compute.makeComputePipelineState(with: identity)
        XCTAssertEqual(ObjectIdentifier(warmPipeline), coldIDs.first)
    }

    func testResetDuringPipelineCreationDoesNotPopulateNewGeneration() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "当前环境没有 Metal 设备。")
        let resources = HarbethUncheckedTransfer(value: (
            device: Device(),
            old: try Compute.makeComputePipelineState(with: "C7Brightness"),
            new: try Compute.makeComputePipelineState(with: "C7Contrast")
        ))
        let identity = KernelFunctionIdentity(kind: .compute, primaryName: "reset-probe")
        let started = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let finished = DispatchGroup()
        let results = PipelineLookupRecorder()
        defer { release.signal() }
        finished.enter()
        DispatchQueue.global().async {
            defer { finished.leave() }
            do {
                let pipeline = try resources.value.device.makePipelineState(for: identity) {
                    started.signal()
                    guard release.wait(timeout: .now() + 5) == .success else {
                        throw HarbethError.configurationInvalid("旧创建等待超时。")
                    }
                    return resources.value.old
                }
                results.record(pipeline)
            } catch { results.record(error) }
        }
        guard started.wait(timeout: .now() + 5) == .success else {
            return XCTFail("旧创建未启动。")
        }
        resources.value.device.removePipelineStates()
        let replacement = try resources.value.device.makePipelineState(for: identity) { resources.value.new }
        release.signal()
        XCTAssertEqual(finished.wait(timeout: .now() + 5), .success)
        XCTAssertNil(results.error)
        XCTAssertTrue(results.pipelines.first === resources.value.old)
        XCTAssertTrue(resources.value.device.pipelineState(for: identity) === replacement)
        XCTAssertEqual(resources.value.device.pipelineCount, 1)
    }

    func testFailedPipelineCreationCanBeRetried() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "当前环境没有 Metal 设备。")
        let device = Device()
        let identity = KernelFunctionIdentity(kind: .compute, primaryName: "retry-probe")
        XCTAssertThrowsError(try device.makePipelineState(for: identity) {
            throw HarbethError.configurationInvalid("创建失败探针。")
        })
        XCTAssertNil(device.pipelineState(for: identity))
        let pipeline = try Compute.makeComputePipelineState(with: "C7Brightness")
        let retried = try device.makePipelineState(for: identity) { pipeline }
        XCTAssertTrue(retried === pipeline)
        XCTAssertEqual(device.pipelineCount, 1)
    }

    func testRecursivePipelineCreationFailsWithoutDeadlock() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "当前环境没有 Metal 设备。")
        let device = Device()
        let identity = KernelFunctionIdentity(kind: .compute, primaryName: "recursive-probe")
        XCTAssertThrowsError(try device.makePipelineState(for: identity) {
            try device.makePipelineState(for: identity) {
                XCTFail("不应执行递归工厂。")
                throw HarbethError.commandBuffer
            }
        }) { error in
            guard case .configurationInvalid = error as? HarbethError else {
                return XCTFail("递归创建必须明确报错：\(error)")
            }
        }
        XCTAssertEqual(device.pipelineCount, 0)
    }

    func testDifferentPipelineCreationDoesNotWaitOnSlowIdentity() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "当前环境没有 Metal 设备。")
        let resources = HarbethUncheckedTransfer(value: (
            device: Device(), pipeline: try Compute.makeComputePipelineState(with: "C7Brightness")
        ))
        let slow = KernelFunctionIdentity(kind: .compute, primaryName: "slow-probe")
        let fast = KernelFunctionIdentity(kind: .compute, primaryName: "fast-probe")
        let started = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let slowFinished = DispatchGroup()
        let fastFinished = DispatchGroup()
        let results = PipelineLookupRecorder()
        defer { release.signal() }
        slowFinished.enter()
        DispatchQueue.global().async {
            defer { slowFinished.leave() }
            do {
                results.record(try resources.value.device.makePipelineState(for: slow) {
                    started.signal()
                    guard release.wait(timeout: .now() + 5) == .success else {
                        throw HarbethError.configurationInvalid("慢创建等待超时。")
                    }
                    return resources.value.pipeline
                })
            } catch { results.record(error) }
        }
        guard started.wait(timeout: .now() + 5) == .success else {
            return XCTFail("慢创建未启动。")
        }
        fastFinished.enter()
        DispatchQueue.global().async {
            defer { fastFinished.leave() }
            do {
                results.record(try resources.value.device.makePipelineState(for: fast) { resources.value.pipeline })
            } catch { results.record(error) }
        }
        XCTAssertEqual(fastFinished.wait(timeout: .now() + 2), .success, "不同 identity 不应等待慢创建。")
        release.signal()
        XCTAssertEqual(slowFinished.wait(timeout: .now() + 5), .success)
        XCTAssertNil(results.error)
        XCTAssertEqual(results.pipelines.count, 2)
    }

    func testFailedCreationWakesEveryWaitingCaller() {
        let creation = HarbethUncheckedTransfer(value: ComputePipelineCreation())
        let finished = DispatchGroup()
        let results = PipelineLookupRecorder()
        for _ in 0..<8 {
            finished.enter()
            DispatchQueue.global().async {
                defer { finished.leave() }
                do { results.record(try creation.value.waitForResult()) }
                catch { results.record(error) }
            }
        }
        creation.value.complete(.failure(HarbethError.configurationInvalid("创建失败探针。")))
        XCTAssertEqual(finished.wait(timeout: .now() + 5), .success)
        XCTAssertTrue(results.pipelines.isEmpty)
        guard case .configurationInvalid = results.error as? HarbethError else {
            return XCTFail("所有等待者应收到创建失败。")
        }
    }

}

private final class PipelineLookupRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedPipelines: [MTLComputePipelineState] = []
    private var storedError: Error?

    func record(_ pipeline: MTLComputePipelineState) {
        lock.withLock {
            storedPipelines.append(pipeline)
        }
    }

    func record(_ error: Error) {
        lock.withLock {
            if storedError == nil { storedError = error }
        }
    }

    var pipelines: [MTLComputePipelineState] { lock.withLock { storedPipelines } }
    var error: Error? { lock.withLock { storedError } }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
