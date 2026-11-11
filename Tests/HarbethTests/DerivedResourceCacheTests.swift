//
//  DerivedResourceCacheTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/7/28.
//

import XCTest
import Metal
@testable import Harbeth

final class DerivedResourceCacheTests: XCTestCase {
    private var store: DerivedResourceStore!
    private let namespace = "DerivedResourceCacheTests"

    override func setUp() {
        super.setUp()
        store = DerivedResourceStore(
            configuration: DerivedResourceCacheConfiguration(byteLimit: 4 * 1024 * 1024, countLimit: 2)
        )
        store.setNamespace(namespace)
    }

    func testLRUEvictionHonorsCountAndByteAccounting() throws {
        let firstIdentity = identity(.outputContract, "first")
        let secondIdentity = identity(.mask, "second")
        let thirdIdentity = identity(.lookupTable, "third")
        let first = try makeTexture(label: "first")
        let second = try makeTexture(label: "second")
        let third = try makeTexture(label: "third")

        XCTAssertTrue(store.insert(first as AnyObject, byteCost: first.allocatedSize, for: firstIdentity))
        XCTAssertTrue(store.insert(second as AnyObject, byteCost: second.allocatedSize, for: secondIdentity))
        XCTAssertTrue(store.value(for: firstIdentity) === first as AnyObject)
        XCTAssertTrue(store.insert(third as AnyObject, byteCost: third.allocatedSize, for: thirdIdentity))

        XCTAssertNil(store.value(for: secondIdentity))
        XCTAssertTrue(store.value(for: firstIdentity) === first as AnyObject)
        XCTAssertTrue(store.value(for: thirdIdentity) === third as AnyObject)
        let snapshot = store.snapshot()
        XCTAssertEqual(snapshot.entryCount, 2)
        XCTAssertGreaterThan(snapshot.byteCount, 0)
        XCTAssertLessThanOrEqual(snapshot.byteCount, snapshot.byteLimit)
        XCTAssertGreaterThanOrEqual(snapshot.evictionCount, 1)
    }

    func testInvalidationRejectsStaleInFlightInsertion() throws {
        let staleIdentity = identity(.outputContract, "stale")
        store.invalidate(domain: .outputContract, namespace: namespace)

        XCTAssertFalse(
            store.insert(
                try makeTexture(label: "stale") as AnyObject,
                byteCost: 1,
                for: staleIdentity
            )
        )
        XCTAssertNil(store.value(for: staleIdentity))
        XCTAssertGreaterThanOrEqual(store.snapshot().rejectedInsertionCount, 1)
    }

    func testRepeatedNewestHitsAndReplacementKeepEvictionOrderAndCounts() {
        let first = identity(.mask, String(repeating: "first", count: 100))
        let second = identity(.mask, "second")
        let third = identity(.mask, "third")
        let value = NSObject()
        XCTAssertTrue(store.insert(NSObject(), byteCost: 10, for: first))
        XCTAssertTrue(store.insert(value, byteCost: 20, for: second))
        for _ in 0..<20 { XCTAssertTrue(store.value(for: second) === value) }
        XCTAssertEqual(store.snapshot().hitCount, 20)
        // 替换较旧条目必须同时更新字节成本并将其移到最新位置。
        XCTAssertTrue(store.insert(value, byteCost: 30, for: first))
        XCTAssertTrue(store.insert(NSObject(), byteCost: 40, for: third))
        XCTAssertNil(store.value(for: second))
        XCTAssertTrue(store.value(for: first) === value)
        let snapshot = store.snapshot()
        XCTAssertEqual(snapshot.entryCount, 2)
        XCTAssertEqual(snapshot.byteCount, 70)
        XCTAssertEqual(snapshot.evictionCount, 1)
        XCTAssertEqual(snapshot.hitCount, 21)
        XCTAssertEqual(snapshot.missCount, 1)
    }

    func testOversizedResourceIsRejectedWithoutDisplacingCachedValue() {
        let identity = identity(.mask, "oversized")
        let cached = NSObject()
        XCTAssertTrue(store.insert(cached, byteCost: 128, for: identity))

        XCTAssertFalse(store.insert(NSObject(), byteCost: 8 * 1024 * 1024, for: identity))

        XCTAssertTrue(store.value(for: identity) === cached)
        XCTAssertEqual(store.snapshot().entryCount, 1)
    }

    func testDomainInvalidationDoesNotDiscardUnrelatedResources() throws {
        let outputIdentity = identity(.outputContract, "output")
        let lookupIdentity = identity(.lookupTable, "lookup")
        let output = try makeTexture(label: "output")
        let lookup = try makeTexture(label: "lookup")
        store.insert(output as AnyObject, byteCost: output.allocatedSize, for: outputIdentity)
        store.insert(lookup as AnyObject, byteCost: lookup.allocatedSize, for: lookupIdentity)

        store.invalidate(domain: .outputContract, namespace: namespace)

        XCTAssertNil(store.value(for: outputIdentity))
        XCTAssertTrue(store.value(for: lookupIdentity) === lookup as AnyObject)
        XCTAssertEqual(store.snapshot().entriesByDomain[DerivedResourceDomain.lookupTable.rawValue], 1)
    }

    func testCombinedInvalidationKeepsSurvivorOrderAccountingAndGeneration() {
        store.configure(.init(byteLimit: 1000, countLimit: 4))
        let removed = store.makeIdentity(domain: .mask, namespace: "target", fingerprint: "removed")
        let newest = store.makeIdentity(domain: .lookupTable, namespace: "target", fingerprint: "newest")
        let oldest = store.makeIdentity(domain: .mask, namespace: "other", fingerprint: "oldest")
        let retained = store.makeIdentity(domain: .lookupTable, namespace: "other", fingerprint: "retained")
        let value = NSObject()
        for (identity, cost) in [(removed, 10), (newest, 20), (oldest, 30), (retained, 40)] {
            XCTAssertTrue(store.insert(value, byteCost: cost, for: identity))
        }
        XCTAssertTrue(store.value(for: newest) === value)
        let before = store.snapshot()
        store.invalidate(domain: .mask, namespace: "target")
        let after = store.snapshot()
        XCTAssertEqual(after.entryCount, 3)
        XCTAssertEqual(after.byteCount, 90)
        XCTAssertEqual(after.hitCount, before.hitCount)
        XCTAssertEqual(after.missCount, before.missCount)
        XCTAssertEqual(after.evictionCount, before.evictionCount)
        XCTAssertFalse(store.insert(value, byteCost: 10, for: removed))

        XCTAssertTrue(store.insert(value, byteCost: 50, for: identity(.mask, "new-a")))
        XCTAssertTrue(store.insert(value, byteCost: 60, for: identity(.mask, "new-b")))
        XCTAssertNil(store.value(for: oldest))
        XCTAssertTrue(store.value(for: retained) === value)
        XCTAssertTrue(store.value(for: newest) === value)
        XCTAssertEqual(store.snapshot().byteCount, 170)
        XCTAssertEqual(store.snapshot().evictionCount, 1)
        XCTAssertEqual(store.snapshot().rejectedInsertionCount, 1)
        let fresh = store.makeIdentity(domain: .mask, namespace: "target", fingerprint: "removed")
        XCTAssertNotEqual(fresh.generation, removed.generation)
    }

    func testInvalidationAdvancesEmptyScopesAndLeavesUnmatchedStateUntouched() {
        let stale = store.makeIdentity(domain: .mask, namespace: "empty", fingerprint: "pending")
        let unrelated = store.makeIdentity(domain: .mask, namespace: "other", fingerprint: "pending")
        store.invalidate(domain: .mask, namespace: "empty")
        let fresh = store.makeIdentity(domain: .mask, namespace: "empty", fingerprint: "pending")
        XCTAssertNotEqual(fresh.generation, stale.generation)
        XCTAssertFalse(store.insert(NSObject(), byteCost: 1, for: stale))
        XCTAssertTrue(store.insert(NSObject(), byteCost: 1, for: unrelated))
        XCTAssertTrue(store.insert(NSObject(), byteCost: 1, for: fresh))
        let before = store.snapshot()
        store.invalidate(domain: .lookupTable, namespace: "missing")
        XCTAssertEqual(store.snapshot(), before)
        store.invalidate()
        XCTAssertEqual(store.snapshot().entryCount, 0)
        XCTAssertEqual(store.snapshot().byteCount, 0)
        XCTAssertEqual(store.snapshot().evictionCount, before.evictionCount)
        XCTAssertFalse(store.insert(NSObject(), byteCost: 1, for: unrelated))
    }

    func testCapacityShrinkHonorsBothLimitsWithoutInvalidatingSurvivorIdentities() {
        store.configure(.init(byteLimit: 1000, countLimit: 6))
        let identities = (0..<6).map { identity(.mask, "shrink-\($0)") }
        for (index, identity) in identities.enumerated() {
            XCTAssertTrue(store.insert(NSObject(), byteCost: (index + 1) * 10, for: identity))
        }
        XCTAssertNotNil(store.value(for: identities[1]))
        store.configure(.init(byteLimit: 70, countLimit: 2))
        XCTAssertEqual(store.snapshot().entryCount, 1)
        XCTAssertEqual(store.snapshot().byteCount, 20)
        XCTAssertEqual(store.snapshot().evictionCount, 5)
        for index in [0, 2, 3, 4, 5] { XCTAssertNil(store.value(for: identities[index])) }
        XCTAssertNotNil(store.value(for: identities[1]))
        XCTAssertEqual(identity(.mask, "shrink-0"), identities[0])
        XCTAssertTrue(store.insert(NSObject(), byteCost: 10, for: identities[0]))
        store.configure(.init(byteLimit: 0, countLimit: 0))
        XCTAssertEqual(store.snapshot().entryCount, 0)
        XCTAssertEqual(store.snapshot().byteCount, 0)
        XCTAssertEqual(store.snapshot().byteLimit, 1)
        XCTAssertEqual(store.snapshot().countLimit, 1)
        XCTAssertEqual(store.snapshot().evictionCount, 7)
        XCTAssertTrue(store.insert(NSObject(), byteCost: 1, for: identities[0]))
    }

    func testMoreExpensiveReplacementEvictsOnlyOlderPrefixAndRejectsOversizedReplacement() {
        store.configure(.init(byteLimit: 100, countLimit: 5))
        let identities = (0..<5).map { identity(.lookupTable, "replacement-\($0)") }
        for identity in identities { XCTAssertTrue(store.insert(NSObject(), byteCost: 10, for: identity)) }
        let replacement = NSObject()
        XCTAssertTrue(store.insert(replacement, byteCost: 90, for: identities[0]))
        XCTAssertEqual(store.snapshot().entryCount, 2)
        XCTAssertEqual(store.snapshot().byteCount, 100)
        XCTAssertEqual(store.snapshot().evictionCount, 3)
        for index in 1...3 { XCTAssertNil(store.value(for: identities[index])) }
        XCTAssertNotNil(store.value(for: identities[4]))
        XCTAssertFalse(store.insert(NSObject(), byteCost: 101, for: identities[0]))
        XCTAssertTrue(store.value(for: identities[0]) === replacement)
        XCTAssertEqual(store.snapshot().evictionCount, 3)
        XCTAssertEqual(store.snapshot().rejectedInsertionCount, 1)
    }

    func testNamespaceSeparatesEquivalentFingerprints() throws {
        let firstIdentity = identity(.mask, "shared")
        let first = try makeTexture(label: "namespace-a")
        store.insert(first as AnyObject, byteCost: first.allocatedSize, for: firstIdentity)

        let secondIdentity = store.makeIdentity(domain: .mask, namespace: "second", fingerprint: "shared")

        XCTAssertNil(store.value(for: secondIdentity))
        XCTAssertTrue(store.value(for: firstIdentity) === first as AnyObject)
    }

    func testContextSurfaceStoresAndInvalidatesTexture() throws {
        let context = HarbethContext.shared
        let contextNamespace = "DerivedResourceCacheTests-\(UUID().uuidString)"
        let identity = context.makeDerivedResourceIdentity(
            domain: .mask,
            namespace: contextNamespace,
            fingerprint: "context"
        )
        let texture = try makeTexture(label: "context")
        defer { context.invalidateDerivedResources(namespace: contextNamespace) }

        XCTAssertTrue(context.storeDerivedTexture(texture, for: identity))
        XCTAssertTrue(context.cachedDerivedTexture(for: identity) === texture)
        context.invalidateDerivedResources(domain: .mask, namespace: contextNamespace)
        XCTAssertNil(context.cachedDerivedTexture(for: identity))
    }

    func testConcurrentAccessKeepsCacheBoundedAndRejectsStaleInsertion() {
        let store = store!
        DispatchQueue.concurrentPerform(iterations: 128) { index in
            let identity = store.makeIdentity(
                domain: .mask,
                fingerprint: "concurrent-\(index % 8)"
            )
            _ = store.value(for: identity)
            _ = store.insert(NSObject(), byteCost: 1, for: identity)
            _ = store.value(for: identity)
        }

        let snapshot = store.snapshot()
        XCTAssertLessThanOrEqual(snapshot.entryCount, snapshot.countLimit)
        XCTAssertLessThanOrEqual(snapshot.byteCount, snapshot.byteLimit)

        let staleIdentity = identity(.mask, "stale-concurrent")
        store.invalidate(domain: .mask, namespace: namespace)
        XCTAssertFalse(store.insert(NSObject(), byteCost: 1, for: staleIdentity))
    }

    private func identity(_ domain: DerivedResourceDomain, _ fingerprint: String) -> DerivedResourceIdentity {
        store.makeIdentity(domain: domain, namespace: namespace, fingerprint: fingerprint)
    }

    private func makeTexture(label: String) throws -> MTLTexture {
        try TextureLoader.makeTexture(width: 8, height: 8, identifier: "DerivedResourceCacheTests.\(label)")
    }
}

extension DerivedResourceCacheTests {
    func testTextureCreationIsCoalescedAndReusedAcrossThreads() throws {
        let texture = HarbethUncheckedTransfer(value: try makeTexture(label: "coalesced"))
        let store = self.store!
        let identity = identity(.lookupTable, "coalesced")
        let recorder = DerivedTextureTestRecorder()
        DispatchQueue.concurrentPerform(iterations: 16) { _ in
            do {
                let result = try store.texture(for: identity) {
                    recorder.created()
                    Thread.sleep(forTimeInterval: 0.01)
                    return texture.value
                }
                recorder.received(result)
            } catch { recorder.failed(error) }
        }
        XCTAssertEqual(recorder.creationCount, 1)
        XCTAssertEqual(recorder.textures.count, 16)
        XCTAssertTrue(recorder.textures.allSatisfy { $0 === texture.value })
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testInvalidationDuringCreationCannotRepopulateStaleIdentity() throws {
        let identity = identity(.coordinateField, "stale-creation")
        let texture = try makeTexture(label: "stale-creation")
        let result = try store.texture(for: identity) {
            store.invalidate(domain: .coordinateField, namespace: namespace)
            return texture
        }
        XCTAssertTrue(result === texture)
        XCTAssertNil(store.value(for: identity))
        XCTAssertGreaterThan(store.snapshot().rejectedInsertionCount, 0)
    }

    func testFailedOrRecursiveTextureCreationCanBeRetried() throws {
        let identity = identity(.lookupTable, "retry")
        XCTAssertThrowsError(try store.texture(for: identity) { throw HarbethError.source2Texture })
        XCTAssertThrowsError(try store.texture(for: identity) {
            try store.texture(for: identity) { throw HarbethError.source2Texture }
        })
        let texture = try makeTexture(label: "retry")
        XCTAssertTrue(try store.texture(for: identity) { texture } === texture)
    }
}

private final class DerivedTextureTestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedCreationCount = 0
    private var storedTextures: [MTLTexture] = []
    private var storedErrors: [String] = []

    func created() { lock.withLock { storedCreationCount += 1 } }
    func received(_ texture: MTLTexture) { lock.withLock { storedTextures.append(texture) } }
    func failed(_ error: Error) { lock.withLock { storedErrors.append(String(describing: error)) } }
    var creationCount: Int { lock.withLock { storedCreationCount } }
    var textures: [MTLTexture] { lock.withLock { storedTextures } }
    var errors: [String] { lock.withLock { storedErrors } }
}
