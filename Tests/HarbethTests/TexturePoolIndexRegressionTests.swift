//
//  TexturePoolIndexRegressionTests.metal
//  Harbeth
//
//  Created by Condy on 2026/11/16.
//

import XCTest
import Metal
@testable import Harbeth

final class TexturePoolIndexRegressionTests: XCTestCase {
    func testFullDescriptorContractAndToleranceBoundaries() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let pool = TexturePool(device: device, maxMemoryUsage: 8 * 1024 * 1024)
        let source = try makeTexture(device: device, width: 16, height: 16)
        pool.enqueueTextureSync(source)
        XCTAssertNil(pool.dequeueTexture(matching: descriptor(device: device, width: 16, height: 16, usage: .renderTarget), allowsSizeTolerance: false))
        XCTAssertNil(pool.dequeueTexture(matching: descriptor(device: device, width: 16, height: 16, mipmapped: true), allowsSizeTolerance: false))
        let formatMismatch = descriptor(device: device, width: 16, height: 16); formatMismatch.pixelFormat = .bgra8Unorm
        let storageMismatch = descriptor(device: device, width: 16, height: 16); storageMismatch.storageMode = .private
        let hazardMismatch = descriptor(device: device, width: 16, height: 16); hazardMismatch.hazardTrackingMode = .untracked
        for mismatch in [formatMismatch, storageMismatch, hazardMismatch] {
            XCTAssertNil(pool.dequeueTexture(matching: mismatch, allowsSizeTolerance: true))
            XCTAssertTrue(pool.dequeueTexture(matching: source.c7.descriptor, allowsSizeTolerance: false) === source)
            pool.enqueueTextureSync(source)
        }
        XCTAssertTrue(pool.dequeueTexture(matching: source.c7.descriptor, allowsSizeTolerance: true) === source)
        let edge = try makeTexture(device: device, width: 24, height: 24)
        pool.enqueueTextureSync(edge)
        XCTAssertNil(pool.dequeueTexture(matching: descriptor(device: device, width: 15, height: 16), allowsSizeTolerance: true))
        XCTAssertNil(pool.dequeueTexture(matching: descriptor(device: device, width: 16, height: 15), allowsSizeTolerance: true))
        XCTAssertTrue(pool.dequeueTexture(matching: descriptor(device: device, width: 16, height: 16), allowsSizeTolerance: true) === edge)
    }

    func testDuplicateEnqueueAndLastTextureReenqueueAreIdempotent() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let pool = TexturePool(device: device)
        let texture = try makeTexture(device: device, width: 8, height: 8)
        pool.enqueueTextureSync(texture); pool.enqueueTextureSync(texture)
        XCTAssertEqual(pool.statistics.currentTextureCount, 1)
        XCTAssertTrue(pool.dequeueExactTexture(width: 8, height: 8, pixelFormat: .rgba8Unorm) === texture)
        XCTAssertNil(pool.dequeueExactTexture(width: 8, height: 8, pixelFormat: .rgba8Unorm))
        pool.enqueueTextureSync(texture)
        XCTAssertTrue(pool.dequeueExactTexture(width: 8, height: 8, pixelFormat: .rgba8Unorm) === texture)
    }

    func testMultipleTexturesAndBudgetEvictionKeepStatisticsConservative() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let pool = TexturePool(device: device, maxMemoryUsage: 1024)
        let textures = try (0..<3).map { _ in try makeTexture(device: device, width: 8, height: 8) }
        pool.enqueueTexturesSync(textures)
        XCTAssertLessThanOrEqual(pool.statistics.currentMemoryUsage, 1024)
        var reused = 0
        while pool.dequeueExactTexture(width: 8, height: 8, pixelFormat: .rgba8Unorm) != nil { reused += 1 }
        XCTAssertGreaterThan(reused, 0)
        XCTAssertEqual(pool.statistics.currentTextureCount, 0)
        XCTAssertEqual(pool.statistics.currentMemoryUsage, 0)
    }

    func testBudgetEvictionRotatesSameKeyAndPreservesRemainingIdentity() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let a1 = try makeTexture(device: device, width: 8, height: 8)
        let a2 = try makeTexture(device: device, width: 8, height: 8)
        let bDescriptor = descriptor(device: device, width: 8, height: 8); bDescriptor.pixelFormat = .bgra8Unorm
        let cDescriptor = descriptor(device: device, width: 8, height: 8, usage: .shaderRead)
        let dDescriptor = descriptor(device: device, width: 8, height: 8); dDescriptor.storageMode = .private
        let b = try XCTUnwrap(device.makeTexture(descriptor: bDescriptor))
        let c = try XCTUnwrap(device.makeTexture(descriptor: cDescriptor))
        let d = try XCTUnwrap(device.makeTexture(descriptor: dDescriptor))
        // 使用合同中的逻辑字节数，避免硬件分配对齐掩盖驱逐。
        let pool = TexturePool(device: device, maxMemoryUsage: 3 * 8 * 8 * 4)
        pool.enqueueTexturesSync([a1, a2, b])
        pool.enqueueTextureSync(c)
        XCTAssertEqual(pool.statistics.currentTextureCount, 3)
        pool.enqueueTextureSync(d)
        XCTAssertEqual(pool.statistics.currentTextureCount, 3)
        XCTAssertEqual(pool.statistics.currentMemoryUsage, 768)
        XCTAssertNil(pool.dequeueTexture(matching: bDescriptor, allowsSizeTolerance: false))
        XCTAssertTrue(pool.dequeueTexture(matching: a1.c7.descriptor, allowsSizeTolerance: false) === a1)
        XCTAssertNil(pool.dequeueTexture(matching: a1.c7.descriptor, allowsSizeTolerance: false))
        XCTAssertTrue(pool.dequeueTexture(matching: cDescriptor, allowsSizeTolerance: false) === c)
        XCTAssertTrue(pool.dequeueTexture(matching: dDescriptor, allowsSizeTolerance: false) === d)
        XCTAssertEqual(pool.statistics.currentMemoryUsage, 0)
        XCTAssertEqual(pool.statistics.currentTextureCount, 0)
    }

    func testExactMatchWinsBeforeToleranceCandidates() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let exact = try makeTexture(device: device, width: 16, height: 16)
        let tolerant = try makeTexture(device: device, width: 15, height: 16)
        let pool = TexturePool(device: device)
        pool.enqueueTexturesSync([tolerant, exact])
        let result = pool.dequeueTexture(matching: exact.c7.descriptor, allowsSizeTolerance: true)
        XCTAssertTrue(result === exact)
        XCTAssertNotNil(pool.dequeueTexture(matching: tolerant.c7.descriptor, allowsSizeTolerance: false))
    }

    func testIndependentLeasesReturnAtMostOnceUnderConcurrency() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let pool = TexturePool(device: device)
        let textures = try (0..<8).map { _ in try makeTexture(device: device, width: 4, height: 4) }
        let leases = textures.map { pool.makeLease(for: $0) }
        let group = DispatchGroup()
        for lease in leases { group.enter(); DispatchQueue.global().async { lease.release(); lease.release(); group.leave() } }
        group.wait()
        XCTAssertEqual(pool.statistics.currentTextureCount, 8)
    }

    func testRandomizedPoolOperationsMatchIndependentLRUModel() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let shapes = [(8,8), (16,4), (4,16), (32,2), (2,32), (64,1)]
        let textures = try (0..<12).map { i in
            try makeTexture(device: device, width: shapes[i % 6].0, height: shapes[i % 6].1)
        }
        let pool = TexturePool(device: device, maxMemoryUsage: 1024)
        var free: [Int: [Int]] = [:], order: [Int] = [], seed: UInt64 = 7
        func random() -> Int { seed = seed &* 6364136223846793005 &+ 1; return Int(seed >> 32) }
        func pop(_ key: Int) -> Int? {
            guard var entries = free[key], let id = entries.popLast() else { return nil }
            order.removeAll { $0 == key }
            if entries.isEmpty { free[key] = nil } else { free[key] = entries; order.append(key) }
            return id
        }
        for step in 0..<500 {
            if step % 9 == 0 {
                let key = random() % 6
                let query = descriptor(device: device, width: shapes[key].0 + 1, height: shapes[key].1)
                let actual = pool.dequeueTexture(matching: query, allowsSizeTolerance: true)
                if let actual {
                    let id = try XCTUnwrap(textures.firstIndex { $0 === actual })
                    XCTAssertEqual(pop(id % 6), id)
                    XCTAssertLessThanOrEqual(abs(actual.width - query.width), 8)
                    XCTAssertLessThanOrEqual(abs(actual.height - query.height), 8)
                } else {
                    XCTAssertTrue(free.keys.allSatisfy { abs(shapes[$0].0 - query.width) > 8 || abs(shapes[$0].1 - query.height) > 8 })
                }
            } else if random() % 2 == 0 {
                let id = random() % textures.count, key = id % 6
                if free.values.contains(where: { $0.contains(id) }) == false {
                    while free.values.reduce(0, { $0 + $1.count }) >= 4 { _ = pop(order[0]) }
                    if free[key] == nil { order.append(key) }
                    free[key, default: []].append(id)
                }
                pool.enqueueTextureSync(textures[id])
            } else {
                let key = random() % 6, expected = pop(key)
                let actual = pool.dequeueTexture(matching: textures[key].c7.descriptor, allowsSizeTolerance: false)
                XCTAssertEqual(actual.map { ObjectIdentifier($0) }, expected.map { ObjectIdentifier(textures[$0]) })
            }
            let count = free.values.reduce(0) { $0 + $1.count }
            XCTAssertEqual(pool.statistics.currentTextureCount, count)
            XCTAssertEqual(pool.statistics.currentMemoryUsage, count * 256)
        }
        pool.purgeAllTexturesSync()
        XCTAssertEqual(pool.statistics.currentTextureCount, 0)
        XCTAssertNil(pool.dequeueTexture(matching: textures[0].c7.descriptor, allowsSizeTolerance: true))
        pool.enqueueTextureSync(textures[0])
        XCTAssertTrue(pool.dequeueTexture(matching: textures[0].c7.descriptor, allowsSizeTolerance: true) === textures[0])
    }

    private func descriptor(device: MTLDevice, width: Int, height: Int, usage: MTLTextureUsage = [.shaderRead, .shaderWrite], mipmapped: Bool = false) -> MTLTextureDescriptor {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: mipmapped)
        d.usage = usage; d.storageMode = .shared; return d
    }

    private func makeTexture(device: MTLDevice, width: Int, height: Int) throws -> MTLTexture {
        try XCTUnwrap(device.makeTexture(descriptor: descriptor(device: device, width: width, height: height)))
    }
}
