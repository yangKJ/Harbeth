// 由 Condy 创建于 2026/11/16。
import XCTest

@testable import Harbeth

final class DerivedResourceIdentityLRUTests: XCTestCase {
    func testNamespaceSeparatorsCannotAliasDifferentIdentities() {
        let store = DerivedResourceStore(configuration: .init(byteLimit: 1000, countLimit: 4))
        let first = store.makeIdentity(domain: .mask, namespace: "a", fingerprint: "b||2||c")
        let second = store.makeIdentity(domain: .mask, namespace: "a||1||b", fingerprint: "c")
        XCTAssertEqual(first.generation, 1)
        XCTAssertEqual(second.generation, 2)
        let a = NSObject()
        let b = NSObject()
        XCTAssertTrue(store.insert(a, byteCost: 10, for: first))
        XCTAssertTrue(store.insert(b, byteCost: 20, for: second))
        XCTAssertTrue(store.value(for: first) === a)
        XCTAssertTrue(store.value(for: second) === b)
        XCTAssertEqual(store.snapshot().entryCount, 2)
        XCTAssertEqual(store.snapshot().byteCount, 30)
        store.invalidate(domain: .mask, namespace: "a")
        XCTAssertNil(store.value(for: first))
        XCTAssertTrue(store.value(for: second) === b)
    }

    func testRandomizedLRUReplacementAndEvictionMatchIndependentModel() {
        let store = DerivedResourceStore(configuration: .init(byteLimit: 7, countLimit: 7))
        let ids = (0..<16).map { store.makeIdentity(domain: .lookupTable, namespace: "test", fingerprint: "\($0)") }
        let objects = (0..<16).map { _ in NSObject() }
        var model: [Int] = []
        var seed: UInt64 = 19
        func random() -> Int {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1
            return Int(seed >> 32)
        }
        for _ in 0..<1000 {
            let i = random() % ids.count
            if random() % 3 == 0 {
                model.removeAll { $0 == i }
                model.append(i)
                if model.count > 7 { model.removeFirst() }
                XCTAssertTrue(store.insert(objects[i], byteCost: 1, for: ids[i]))
            } else {
                let hit = model.contains(i)
                XCTAssertEqual(store.value(for: ids[i]) === objects[i], hit)
                if hit {
                    model.removeAll { $0 == i }
                    model.append(i)
                }
            }
            XCTAssertEqual(store.snapshot().entryCount, model.count)
            XCTAssertEqual(store.snapshot().byteCount, model.count)
        }
        store.invalidate()
        XCTAssertEqual(store.snapshot().entryCount, 0)
        XCTAssertFalse(store.insert(objects[0], byteCost: 1, for: ids[0]))
    }
}
