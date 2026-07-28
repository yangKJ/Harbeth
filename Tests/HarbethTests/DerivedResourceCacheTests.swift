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

    private func identity(_ domain: DerivedResourceDomain, _ fingerprint: String) -> DerivedResourceIdentity {
        store.makeIdentity(domain: domain, namespace: namespace, fingerprint: fingerprint)
    }

    private func makeTexture(label: String) throws -> MTLTexture {
        try TextureLoader.makeTexture(width: 8, height: 8, identifier: "DerivedResourceCacheTests.\(label)")
    }
}
