//
//  PrimitiveBenefitBenchmarkTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/11/11.
//

import Foundation
import Metal
import QuartzCore
import XCTest
@testable import Harbeth

#if targetEnvironment(macCatalyst)
private typealias BenefitHalf = Float
#else
private typealias BenefitHalf = Float16
#endif

/// Opt-in, paired Release measurements of the pre-migration and current implementations.
/// The baseline code is frozen test evidence, not a production fallback.
final class PrimitiveBenefitBenchmarkTests: XCTestCase {
    func testReductionAndGridBenefits() throws {
        guard ProcessInfo.processInfo.environment["HARBETH_RUN_PRIMITIVE_BENCHMARKS"] == "1" else {
            throw XCTSkip("Set HARBETH_RUN_PRIMITIVE_BENCHMARKS=1 to run paired benchmarks.")
        }
        #if DEBUG
        throw XCTSkip("Use a Release build for benefit measurements.")
        #else
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("Metal is unavailable.") }
        var rows: [[String: Any]] = []
        for edge in [16, 64, 256, 1024] {
            for storage in [MTLStorageMode.shared, .private] {
                for flat in [false, true] {
                    let source = try fixture(edge: edge, storage: storage, flat: flat, mask: false)
                    let mask = try fixture(edge: edge, storage: storage, flat: flat, mask: true)
                    let label: [String: Any] = ["edge": edge, "storage": storage == .shared ? "shared" : "private",
                                               "pattern": flat ? "flat" : "varied"]
                    let expectedBounds = try legacyAlphaBounds(source)
                    XCTAssertEqual(try source.c7.alphaCoverageBounds(), expectedBounds)
                    rows.append(try pair(name: "alphaBounds", label: label,
                        baselineBytes: edge * edge * 8, currentBytes: -1,
                        baseline: { try self.legacyAlphaBounds(source).map { Double($0.width + $0.height) } ?? 0 },
                        current: { try source.c7.alphaCoverageBounds().map { Double($0.width + $0.height) } ?? 0 }))
                    for coverage in [nil, mask] as [MTLTexture?] {
                        let expected = try legacyHistogram(source, coverage: coverage)
                        let actual = try source.c7.makeWeightedColorHistogram(coverage: coverage).channels
                        let total = max(expected[0].reduce(0, +), 1)
                        let error = zip(expected.flatMap { $0 }, actual.flatMap { $0 }).map { abs($0 - $1) / total }.max() ?? 0
                        XCTAssertLessThan(error, 0.00002)
                        var metadata = label
                        metadata["coverage"] = coverage != nil
                        metadata["maximumNormalizedBinError"] = error
                        let blocks = ((edge + 31) / 32) * ((edge + 31) / 32)
                        rows.append(try pair(name: "weightedHistogram", label: metadata,
                            baselineBytes: edge * edge * 8 * (coverage == nil ? 1 : 2), currentBytes: blocks * 768 * 4 + 4,
                            baseline: { try self.legacyHistogram(source, coverage: coverage)[0].reduce(0, +) },
                            current: { try source.c7.makeWeightedColorHistogram(coverage: coverage).channels[0].reduce(0, +) }))
                    }
                }
            }
        }
        let points = (0..<(65 * 65)).map { CGPoint(x: CGFloat($0 % 65) / 64, y: CGFloat($0 / 65) / 64) }
        let prepared = try InverseCoordinateGrid(width: 65, height: 65, points: points)
        let old = try legacyField(points)
        let current = try prepared.makeTexture()
        XCTAssertEqual(old.c7.rawBytes(maximumBytes: 65 * 65 * 8), current.c7.rawBytes(maximumBytes: 65 * 65 * 8))
        rows.append(try pair(name: "coordinateFieldReconstructed", label: ["dimension": 65], baselineBytes: 0, currentBytes: 0,
            baseline: { Double(try self.legacyField(points).width) },
            current: {
                Double(try InverseCoordinateGrid.makeTexture(width: 65, height: 65, identifier: "Benefit.ProducerRevision.v1") {
                    points.map { CGPoint(x: $0.x, y: $0.y) }
                }.width)
            }))
        rows.append(try pair(name: "coordinateFieldReusedValue", label: ["dimension": 65], baselineBytes: 0, currentBytes: 0,
            baseline: { Double(try self.legacyField(points).width) }, current: { Double(try prepared.makeTexture().width) }))
        let extent = CGRect(x: 17, y: 31, width: 12_000, height: 8_000)
        let region = CGRect(x: 5000, y: 3000, width: 256, height: 256)
        rows.append(try pair(name: "coordinateROI", label: ["dimension": 65], baselineBytes: 0, currentBytes: 0,
            baseline: { Double(self.legacyROI(points, rect: region, extent: extent).width) },
            current: {
                Double(InverseCoordinateGrid.sourceRegion(for: region, extent: extent, width: 65, height: 65) { points[$0] }.width)
            }))
        try write(rows)
        #endif
    }

    private func pair(
        name: String,
        label: [String: Any],
        baselineBytes: Int,
        currentBytes: Int,
        baseline: () throws -> Double,
        current: () throws -> Double
    ) throws -> [String: Any] {
        var checksum = 0.0
        for _ in 0..<3 {
            checksum += try autoreleasepool(invoking: baseline)
            checksum += try autoreleasepool(invoking: current)
        }
        var before: [Double] = [], after: [Double] = []
        func sample(_ operation: () throws -> Double) throws -> Double {
            let start = CACurrentMediaTime()
            let result = try autoreleasepool(invoking: operation)
            let elapsed = (CACurrentMediaTime() - start) * 1000
            checksum += result
            return elapsed
        }
        for index in 0..<15 {
            if index.isMultiple(of: 2) {
                before.append(try sample(baseline))
                after.append(try sample(current))
            } else {
                after.append(try sample(current))
                before.append(try sample(baseline))
            }
        }
        before.sort()
        after.sort()
        var row = label
        row["name"] = name
        row["iterations"] = before.count
        row["baselineP50Ms"] = before[before.count / 2]
        row["currentP50Ms"] = after[after.count / 2]
        row["baselineP95Ms"] = before[before.count - 1]
        row["currentP95Ms"] = after[after.count - 1]
        row["currentOverBaseline"] = after[after.count / 2] / max(before[before.count / 2], 0.000001)
        row["baselineCPUVisibleBytes"] = baselineBytes
        row["currentCPUVisibleBytes"] = currentBytes >= 0 ? currentBytes as Any : NSNull()
        if currentBytes < 0 { row["currentReadbackPolicy"] = "bounded small-input CPU path or 24-byte GPU summary" }
        row["checksum"] = checksum
        print("[PrimitiveBenefit] \(name) \(label) old=\(before[before.count / 2]) new=\(after[after.count / 2]) ms")
        return row
    }

    private func write(_ rows: [[String: Any]]) throws {
        let directory = ProcessInfo.processInfo.environment["HARBETH_BENCHMARK_OUTPUT_DIR"] ?? NSTemporaryDirectory()
        let target = URL(fileURLWithPath: directory).appendingPathComponent("primitive-benefits.json")
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        let report: [String: Any] = ["schemaVersion": 1, "configuration": "release", "device": HarbethContext.shared.device.name,
            "os": ProcessInfo.processInfo.operatingSystemVersionString, "measurement": "offscreen synchronous CPU wall clock",
            "cachePolicy": "Both routes warmed; alternating order; 3 warmups and 15 samples. Driver and framework caches retained.",
            "baseline": "pre-migration implementation", "samples": rows]
        try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted]).write(to: target, options: .atomic)
        print("[PrimitiveBenefitReport] \(target.path)")
    }

    private func fixture(edge: Int, storage: MTLStorageMode, flat: Bool, mask: Bool) throws -> MTLTexture {
        let device = HarbethContext.shared.device
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: edge, height: edge, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared
        let shared = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        var values = [UInt16](repeating: 0, count: edge * edge * 4)
        for index in 0..<(edge * edge) {
            let alpha: Float = flat ? 1 : Float((index % 11) + 1) / 11
            let color = mask ? SIMD4<Float>(repeating: flat ? 0.5 : Float(index % 7) / 7)
                : SIMD4(Float((index * 3) % 251) / 251 * alpha, Float((index * 5) % 251) / 251 * alpha,
                        Float((index * 7) % 251) / 251 * alpha, alpha)
            let pixel = flat && !mask ? SIMD4<Float>(0.25, 0.5, 0.75, 1) : color
            for channel in 0..<4 { values[index * 4 + channel] = Float16(pixel[channel]).bitPattern }
        }
        values.withUnsafeBytes {
            shared.replace(region: MTLRegionMake2D(0, 0, edge, edge), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: edge * 8)
        }
        guard storage == .private else { return shared }
        descriptor.storageMode = .private
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let command = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
        let blit = try XCTUnwrap(command.makeBlitCommandEncoder())
        blit.copy(from: shared, to: texture)
        blit.endEncoding()
        command.commit()
        command.waitUntilCompleted()
        XCTAssertNil(command.error)
        return texture
    }

    private func legacyAlphaBounds(_ texture: MTLTexture) throws -> MaskCoverageBounds? {
        try Task.checkCancellation()
        let bytes = try XCTUnwrap(texture.c7.rawBytes(maximumBytes: texture.width * texture.height * 8))
        var left = texture.width, top = texture.height, right = -1, bottom = -1
        try bytes.withUnsafeBytes { raw in
            let values = raw.bindMemory(to: UInt8.self)
            for y in 0..<texture.height {
                if y.isMultiple(of: 32) { try Task.checkCancellation() }
                for x in 0..<texture.width {
                    let index = (y * texture.width + x) * 8 + 6
                    let bits = UInt16(values[index]) | (UInt16(values[index + 1]) << 8)
                    guard bits & 0x7C00 != 0x7C00 else { throw HarbethError.source2Texture }
                    if bits & 0x8000 == 0 && bits & 0x7FFF != 0 {
                        left = min(left, x)
                        top = min(top, y)
                        right = max(right, x)
                        bottom = max(bottom, y)
                    }
                }
            }
        }
        try Task.checkCancellation()
        return right >= left ? MaskCoverageBounds(x: left, y: top, width: right - left + 1, height: bottom - top + 1) : nil
    }

    private func legacyHistogram(_ texture: MTLTexture, coverage: MTLTexture?) throws -> [[Double]] {
        let pixels = try legacyHistogramPixels(texture)
        let mask = try coverage.map(legacyHistogramPixels)
        var bins = Array(repeating: Array(repeating: 0.0, count: 256), count: 3)
        for y in 0..<texture.height {
            if y.isMultiple(of: 32) { try Task.checkCancellation() }
            for x in 0..<texture.width {
                let index = (y * texture.width + x) * 4
                let alpha = Float(pixels[index + 3])
                guard alpha.isFinite else { throw HarbethError.source2Texture }
                guard alpha > 0 else { continue }
                let clip = mask.map { Float($0[index]) } ?? 1
                guard clip.isFinite else { throw HarbethError.source2Texture }
                let weight = Double(min(1, alpha) * min(1, max(0, clip)))
                guard weight > 0 else { continue }
                for channel in 0..<3 {
                    let value = Float(pixels[index + channel]) / alpha
                    guard value.isFinite else { throw HarbethError.source2Texture }
                    bins[channel][Int((min(1, max(0, value)) * 255).rounded())] += weight
                }
            }
        }
        return bins
    }

    private func legacyHistogramPixels(_ texture: MTLTexture) throws -> [BenefitHalf] {
        let count = texture.width * texture.height * 4
        let buffer = try XCTUnwrap(texture.device.makeBuffer(length: count * 2, options: .storageModeShared))
        let command = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
        let blit = try XCTUnwrap(command.makeBlitCommandEncoder())
        blit.copy(from: texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                  sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1), to: buffer,
                  destinationOffset: 0, destinationBytesPerRow: texture.width * 8, destinationBytesPerImage: count * 2)
        blit.endEncoding()
        command.commit()
        command.waitUntilCompleted()
        if let error = command.error { throw error }
        #if targetEnvironment(macCatalyst)
        return try HalfFloatConversion.decode(Array(UnsafeBufferPointer(start: buffer.contents().bindMemory(to: UInt16.self, capacity: count), count: count)))
        #else
        return Array(UnsafeBufferPointer(start: buffer.contents().bindMemory(to: Float16.self, capacity: count), count: count))
        #endif
    }

    private func legacyROI(_ points: [CGPoint], rect: CGRect, extent: CGRect) -> CGRect {
        let region = rect.intersection(extent)
        let left = max(0, Int(floor((region.minX - extent.minX) / extent.width * 64)))
        let right = min(64, Int(ceil((region.maxX - extent.minX) / extent.width * 64)))
        let top = max(0, Int(floor((1 - (region.maxY - extent.minY) / extent.height) * 64)))
        let bottom = min(64, Int(ceil((1 - (region.minY - extent.minY) / extent.height) * 64)))
        var minX = CGFloat.greatestFiniteMagnitude, minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        for y in top...max(top, bottom) {
            for x in left...max(left, right) {
                let point = points[y * 65 + x]
                minX = min(minX, point.x)
                maxX = max(maxX, point.x)
                minY = min(minY, point.y)
                maxY = max(maxY, point.y)
            }
        }
        return CGRect(x: extent.minX + minX * extent.width, y: extent.minY + (1 - maxY) * extent.height,
                      width: (maxX - minX) * extent.width, height: (maxY - minY) * extent.height)
            .insetBy(dx: -2, dy: -2).integral.intersection(extent)
    }

    private func legacyField(_ points: [CGPoint]) throws -> MTLTexture {
        let texture = try TextureLoader.makeTexture(width: 65, height: 65,
            options: [.texturePixelFormat: MTLPixelFormat.rg32Float], identifier: "Benefit.LegacyField")
        let values = points.flatMap { [Float($0.x), Float($0.y)] }
        values.withUnsafeBytes {
            texture.replace(region: MTLRegionMake2D(0, 0, 65, 65), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 65 * 8)
        }
        return texture
    }
}
