//
//  RenderPipelineConcurrencyTests.swift
//  Harbeth
//
//  Created by Condy on 2026/10/07.
//

import Foundation
import XCTest
@preconcurrency import Metal
@testable import Harbeth

final class RenderPipelineConcurrencyTests: XCTestCase {
    override func tearDownWithError() throws {
        try HarbethContext.shared.configurePipelineBinaryArchive(.disabled)
        HarbethContext.shared.resetCaches()
        try super.tearDownWithError()
    }

    func testFailureWakesAllWaitersAndAllowsFactoryRetry() throws {
        let creation = HarbethUncheckedTransfer(value: RenderPipelineCreation())
        let recorder = RenderPipelineConcurrencyRecorder()
        let group = DispatchGroup()
        for _ in 0..<8 {
            group.enter()
            DispatchQueue.global().async {
                defer { group.leave() }
                recorder.record(Result { try creation.value.waitForResult() })
            }
        }
        creation.value.complete(.failure(HarbethError.commandBuffer))
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(recorder.results.count, 8)
        XCTAssertTrue(recorder.results.allSatisfy { if case .failure = $0 { return true }; return false })

        let context = HarbethContext.shared
        let key = RenderPipelineCacheKey(vertex: "retry-v", fragment: "retry-f", renderPass: "retry")
        XCTAssertThrowsError(try context.makeRenderPipelineState(for: key) { throw HarbethError.commandBuffer })
        let expected = try Rendering.makeRenderPipelineState(with: "basicVertex", fragment: "basicFragment", pixelFormat: .rgba8Unorm)
        XCTAssertTrue((try context.makeRenderPipelineState(for: key) { expected }) === expected)
    }

    func testWarmHitDoesNotExecuteFactory() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "当前环境没有 Metal 设备。")
        let context = HarbethContext.shared
        context.resetCaches()
        let key = RenderPipelineCacheKey(vertex: "warm-v", fragment: "warm-f", renderPass: "warm")
        let pipeline = try Rendering.makeRenderPipelineState(with: "basicVertex", fragment: "basicFragment", pixelFormat: .rgba8Unorm)
        var count = 0
        _ = try context.makeRenderPipelineState(for: key) { count += 1; return pipeline }
        _ = try context.makeRenderPipelineState(for: key) { count += 1; return pipeline }
        XCTAssertEqual(count, 1)
    }

    func testDifferentKeyDoesNotWaitOnSlowCreation() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "当前环境没有 Metal 设备。")
        let context = HarbethContext.shared
        context.resetCaches()
        let pipeline = try Rendering.makeRenderPipelineState(with: "basicVertex", fragment: "basicFragment", pixelFormat: .rgba8Unorm)
        let slow = RenderPipelineCacheKey(vertex: "slow-v", fragment: "slow-f", renderPass: "slow")
        let fast = RenderPipelineCacheKey(vertex: "fast-v", fragment: "fast-f", renderPass: "fast")
        let started = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let slowGroup = DispatchGroup()
        slowGroup.enter()
        DispatchQueue.global().async {
            defer { slowGroup.leave() }
            do {
                _ = try context.makeRenderPipelineState(for: slow) {
                    started.signal()
                    _ = release.wait(timeout: .now() + 5)
                    return pipeline
                }
            } catch {
                XCTFail("慢创建失败：\(error)")
            }
        }
        XCTAssertEqual(started.wait(timeout: .now() + 5), .success)
        let fastGroup = DispatchGroup()
        fastGroup.enter()
        DispatchQueue.global().async {
            defer { fastGroup.leave() }
            do { _ = try context.makeRenderPipelineState(for: fast) { pipeline } }
            catch { XCTFail("快创建失败：\(error)") }
        }
        XCTAssertEqual(fastGroup.wait(timeout: .now() + 2), .success)
        release.signal()
        XCTAssertEqual(slowGroup.wait(timeout: .now() + 5), .success)
    }

    func testRecursiveCreationFailsWithoutDeadlock() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "当前环境没有 Metal 设备。")
        let context = HarbethContext.shared
        context.resetCaches()
        let key = RenderPipelineCacheKey(vertex: "recursive-v", fragment: "recursive-f", renderPass: "recursive")
        XCTAssertThrowsError(try context.makeRenderPipelineState(for: key) {
            try context.makeRenderPipelineState(for: key) { XCTFail("不应执行递归 factory"); throw HarbethError.commandBuffer }
        }) { error in
            guard case .configurationInvalid = error as? HarbethError else { XCTFail("应报告递归创建错误：\(error)"); return }
        }
    }

    func testInvalidArchiveReconfigurationKeepsExistingCacheContract() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "当前环境没有 Metal 设备。")
        let context = HarbethContext.shared
        context.resetCaches()
        let key = RenderPipelineCacheKey(vertex: "archive-v", fragment: "archive-f", renderPass: "archive")
        let pipeline = try Rendering.makeRenderPipelineState(with: "basicVertex", fragment: "basicFragment", pixelFormat: .rgba8Unorm)
        _ = try context.makeRenderPipelineState(for: key) { pipeline }
        let countBefore = context.debugCacheSnapshot().renderPipelineCount
        XCTAssertThrowsError(try context.configurePipelineBinaryArchive(.persistent(at: URL(string: "https://invalid.example/archive")!)))
        XCTAssertEqual(context.debugCacheSnapshot().renderPipelineCount, countBefore)
        XCTAssertTrue((try context.makeRenderPipelineState(for: key) { throw HarbethError.configurationInvalid("缓存命中不应执行 factory") }) === pipeline)
    }

    func testResetDuringCreationRejectsStaleResult() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "当前环境没有 Metal 设备。")
        let context = HarbethContext.shared
        context.resetCaches()
        let old = try Rendering.makeRenderPipelineState(with: "basicVertex", fragment: "basicFragment", pixelFormat: .rgba8Unorm)
        let replacement = try Rendering.makeRenderPipelineState(with: "basicVertex", fragment: "basicFragment", pixelFormat: .bgra8Unorm)
        let key = RenderPipelineCacheKey(vertex: "reset-v", fragment: "reset-f", renderPass: "reset")
        let started = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let result = RenderPipelineConcurrencyRecorder()
        let group = DispatchGroup(); group.enter()
        DispatchQueue.global().async {
            defer { group.leave() }
            do { result.record(try context.makeRenderPipelineState(for: key) { started.signal(); _ = release.wait(timeout: .now() + 5); return old }) }
            catch { result.record(error) }
        }
        XCTAssertEqual(started.wait(timeout: .now() + 5), .success)
        context.resetCaches()
        let fresh = try context.makeRenderPipelineState(for: key) { replacement }
        release.signal()
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        XCTAssertTrue(result.pipelines.first === old)
        XCTAssertTrue(fresh === replacement)
        XCTAssertFalse(old === replacement)
        let cached = try context.makeRenderPipelineState(for: key) { throw HarbethError.configurationInvalid("新 generation cache miss") }
        XCTAssertTrue(cached === replacement)
    }

    func testArchiveReconfigurationDuringCreationRejectsStaleResult() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "当前环境没有 Metal 设备。")
        let context = HarbethContext.shared
        context.resetCaches()
        let old = try Rendering.makeRenderPipelineState(with: "basicVertex", fragment: "basicFragment", pixelFormat: .rgba8Unorm)
        let replacement = try Rendering.makeRenderPipelineState(with: "basicVertex", fragment: "basicFragment", pixelFormat: .bgra8Unorm)
        let key = RenderPipelineCacheKey(vertex: "archive-race-v", fragment: "archive-race-f", renderPass: "archive-race")
        let started = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let result = RenderPipelineConcurrencyRecorder()
        let group = DispatchGroup(); group.enter()
        DispatchQueue.global().async {
            defer { group.leave() }
            do { result.record(try context.makeRenderPipelineState(for: key) { started.signal(); _ = release.wait(timeout: .now() + 5); return old }) }
            catch { result.record(error) }
        }
        XCTAssertEqual(started.wait(timeout: .now() + 5), .success)
        try context.configurePipelineBinaryArchive(.memoryOnly)
        let fresh = try context.makeRenderPipelineState(for: key) { replacement }
        release.signal()
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        XCTAssertTrue(result.pipelines.first === old)
        XCTAssertTrue(fresh === replacement)
        XCTAssertFalse(old === replacement)
        XCTAssertTrue((try context.makeRenderPipelineState(for: key) { throw HarbethError.configurationInvalid("新 archive generation cache miss") }) === replacement)
    }

    func testRealColdSixteenConcurrentCallersShareState() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "当前环境没有 Metal 设备。")
        HarbethContext.shared.resetCaches()
        let start = DispatchSemaphore(value: 0)
        let group = DispatchGroup()
        let recorder = RenderPipelineConcurrencyRecorder()
        for _ in 0..<16 {
            group.enter()
            DispatchQueue.global().async {
                start.wait()
                defer { group.leave() }
                do { recorder.record(try Rendering.makeRenderPipelineState(with: "basicVertex", fragment: "basicFragment", pixelFormat: .rgba8Unorm)) }
                catch { recorder.record(error) }
            }
        }
        for _ in 0..<16 { start.signal() }
        XCTAssertEqual(group.wait(timeout: .now() + 10), .success)
        XCTAssertNil(recorder.error)
        XCTAssertEqual(Set(recorder.pipelines.map(ObjectIdentifier.init)).count, 1)
    }

    func testColdRenderPipelineLookupUsesSingleFactory() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "当前环境没有 Metal 设备。")
        let context = HarbethContext.shared
        context.resetCaches()
        let key = RenderPipelineCacheKey(vertex: "cold-vertex", fragment: "cold-fragment", renderPass: "rgba8Unorm")
        let recorder = RenderPipelineConcurrencyRecorder()
        let startedAt = DispatchTime.now().uptimeNanoseconds
        let start = DispatchSemaphore(value: 0)
        let factoryStarted = DispatchSemaphore(value: 0)
        let releaseFactory = DispatchSemaphore(value: 0)
        let group = DispatchGroup()
        for _ in 0..<16 {
            group.enter()
            DispatchQueue.global().async {
                start.wait()
                defer { group.leave() }
                let result = Result { try context.makeRenderPipelineState(for: key) {
                    recorder.recordFactory()
                    factoryStarted.signal()
                    _ = releaseFactory.wait(timeout: .now() + 5)
                    return try Rendering.makeRenderPipelineState(with: "basicVertex", fragment: "basicFragment", pixelFormat: .rgba8Unorm)
                } }
                recorder.record(result)
            }
        }
        for _ in 0..<16 { start.signal() }
        XCTAssertEqual(factoryStarted.wait(timeout: .now() + 5), .success)
        releaseFactory.signal()
        XCTAssertEqual(group.wait(timeout: .now() + 10), .success)
        XCTAssertEqual(recorder.factoryCount, 1)
        print("[RenderPipelineColdProbe] requests=16 factoryCount=\(recorder.factoryCount) elapsedMs=\(Double(DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000_000)")
        XCTAssertEqual(recorder.results.count, 16)
        XCTAssertTrue(recorder.results.allSatisfy { if case .success = $0 { return true }; return false })
    }
}

private final class RenderPipelineConcurrencyRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var factoryCount = 0
    private(set) var results: [Result<MTLRenderPipelineState, Error>] = []
    private(set) var pipelines: [MTLRenderPipelineState] = []
    private(set) var error: Error?

    func recordFactory() {
        lock.lock()
        factoryCount += 1
        lock.unlock()
    }

    func record(_ result: Result<MTLRenderPipelineState, Error>) {
        lock.lock()
        results.append(result)
        lock.unlock()
    }

    func record(_ pipeline: MTLRenderPipelineState) {
        lock.lock()
        pipelines.append(pipeline)
        lock.unlock()
    }

    func record(_ error: Error) {
        lock.lock()
        if self.error == nil { self.error = error }
        lock.unlock()
    }
}
