// 由 Condy 创建于 2026/11/17。
import Metal
import XCTest
@testable import Harbeth

final class RoundSixFilterContractsTests: XCTestCase {
    func testMultiZoneParametersAndContinuousWeightsReachGPU() throws {
        let tables = try [Float(0), 0.5, 1].map { try NeighborhoodTestImage.make(width: 1, height: 1, values: [$0,$0,$0,1]) }
        for (shadow, highlight, width): (Float,Float,Float) in [(0.3,0.7,0), (0.3,0.7,0.1), (0.3,0.7,0.5), (0.8,0.2,0.1), (0.5,0.5,0.1)] {
            let filter = C7MultiZoneLookup(shadowThreshold: shadow, highlightThreshold: highlight, transitionWidth: width,
                shadowLookupTexture: tables[0], midtoneLookupTexture: tables[1], highlightLookupTexture: tables[2])
            let values: [Float] = [0,0.299,0.301,0.399,0.401,0.5,0.599,0.601,0.699,0.701,1]
            let input = try NeighborhoodTestImage.make(width: values.count, height: 1, values: values.flatMap { [$0,$0,$0,1] }, format: .rgba32Float)
            let actual = try pixels(input, filter)
            for i in values.indices {
                let lo = min(Double(shadow), Double(highlight) - 0.01), hi = max(Double(highlight), lo + 0.01)
                let w = min(Double(width), (hi - lo) * 0.5), luma = Double(values[i])
                let expected: Double
                if luma <= lo { expected = 0 }
                else if luma >= hi { expected = 1 }
                else if w > 0 && luma < lo + w { expected = 0.5 * (luma - lo) / w }
                else if w > 0 && luma > hi - w { expected = 0.5 + 0.5 * (luma - (hi - w)) / w }
                else { expected = 0.5 }
                XCTAssertEqual(actual[i * 4], Float(expected), accuracy: 0.0001)
                XCTAssertEqual(actual[i * 4 + 3], 1)
            }
        }
    }

    func testMultiZoneEachTableUsesTrueCurveKnotsAndRetainsAlpha() throws {
        for n in [1, 4, 256] {
            var knots: [Float] = []
            for i in 0..<n {
                let x = n == 1 ? Float(0.5) : Float(i) / Float(n - 1)
                knots += [x*x, x, 1-x, 1]
            }
            let table = try NeighborhoodTestImage.make(width: n, height: 1, values: knots)
            let stored = try NeighborhoodTestImage.read(table)
            let filter = C7MultiZoneLookup(shadowLookupTexture: table, midtoneLookupTexture: table, highlightLookupTexture: table)
            let input = try NeighborhoodTestImage.make(width: 4, height: 1, values: [0.1,0.1,0.1,0.25, 0.25,0.375,0.75,0.5, 0.8,0.9,1,1, 0,0,0,0])
            let source = try NeighborhoodTestImage.read(input), actual = try pixels(input, filter)
            for i in stride(from: 0, to: source.count, by: 4) {
                XCTAssertEqual(actual[i + 3], source[i + 3])
                for c in 0..<3 {
                    let position = Double(source[i + c]) * Double(n - 1), lower = Int(position), upper = min(lower + 1, n - 1)
                    let fraction = position - Double(lower)
                    let expected = Double(stored[lower * 4 + c]) * (1 - fraction) + Double(stored[upper * 4 + c]) * fraction
                    XCTAssertEqual(actual[i + c], Float(expected), accuracy: 0.001)
                }
            }
        }
    }

    func testMultiZoneInvalidParametersNormalizeWithoutTrap() throws {
        let t = try NeighborhoodTestImage.make(width: 1, height: 1, values: [0.5,0.5,0.5,1])
        let filter = C7MultiZoneLookup(shadowThreshold: .nan, highlightThreshold: .nan, transitionWidth: .nan,
            shadowLookupTexture: t, midtoneLookupTexture: t, highlightLookupTexture: t)
        XCTAssertTrue(filter.factors.allSatisfy(\.isFinite))
        XCTAssertEqual(try pixels(t, filter), [0.5,0.5,0.5,1])
    }

    func testDilationAllChannelsMatchSignedClampedReference() throws {
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            var values: [Float] = []
            for i in 0..<63 { values += [Float(i % 7) / 6 - 1, Float(i % 9) / 8, Float(i % 5) / 4 - 0.75, Float(i % 4) / 3] }
            let input = try NeighborhoodTestImage.make(width: 9, height: 7, values: values, format: format)
            let source = try NeighborhoodTestImage.read(input)
            for radius in [0, -3, 3, 63, Int.min, Int.max] { for vertical in [false,true] {
                var filter = C7RGBADilation(pixelRadius: radius); filter.vertical = vertical
                let r = Int(min(radius.magnitude, UInt(vertical ? 6 : 8)))
                let actual = try pixels(input, filter)
                for y in 0..<7 { for x in 0..<9 { for c in 0..<4 {
                    let expected = (-r...r).map { offset -> Float in
                        let sx = min(max(x + (vertical ? 0 : offset), 0), 8), sy = min(max(y + (vertical ? offset : 0), 0), 6)
                        return source[(sy * 9 + sx) * 4 + c]
                    }.max()!
                    XCTAssertEqual(actual[(y * 9 + x) * 4 + c], expected)
                } } }
            } }
        }
    }

    func testAreaMaximumMatchesForcedDirectAndContextCacheInvalidation() throws {
        let runtime = HarbethContext.shared, namespace = "harbeth.rgba-dilation.area-max"
        defer { runtime.invalidateDerivedResources(domain: .mask, namespace: namespace) }
        for format in [MTLPixelFormat.rgba8Unorm, .bgra8Unorm, .rgba16Float, .rgba32Float] {
            let input: MTLTexture
            if format == .bgra8Unorm {
                let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: 1024, height: 1024, mipmapped: false)
                d.storageMode = .shared; d.usage = [.shaderRead, .shaderWrite]
                input = try XCTUnwrap(runtime.device.makeTexture(descriptor: d))
                var bytes = [UInt8](repeating: 255, count: 1024 * 1024 * 4)
                for i in 0..<(1024 * 1024) { bytes[i * 4] = UInt8(i % 251); bytes[i * 4 + 1] = UInt8((i * 7) % 239); bytes[i * 4 + 2] = UInt8((i * 13) % 241) }
                bytes.withUnsafeBytes { input.replace(region: MTLRegionMake2D(0,0,1024,1024), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 4096) }
            } else { input = try NeighborhoodTestImage(width: 1024, height: 1024, format: format).texture }
            for vertical in [false,true] {
                runtime.invalidateDerivedResources(domain: .mask, namespace: namespace)
                var filter = C7RGBADilation(pixelRadius: 63); filter.vertical = vertical
                let expected = try forced(input, filter, limit: 0)
                let actual: MTLTexture = try HarbethIO(element: input, filter: filter).output()
                XCTAssertEqual(actual.c7.rawBytes(maximumBytes: 1024 * 1024 * 16), expected.c7.rawBytes(maximumBytes: 1024 * 1024 * 16))
                let identity = runtime.makeDerivedResourceIdentity(domain: .mask, namespace: namespace,
                    fingerprint: "\(ObjectIdentifier(runtime.device))|63|\(vertical)")
                if format == .rgba32Float { XCTAssertNil(runtime.cachedDerivedObject(for: identity)); continue }
                let old = try XCTUnwrap(runtime.cachedDerivedObject(for: identity))
                _ = try HarbethIO(element: input, filter: filter).output()
                XCTAssertTrue(runtime.cachedDerivedObject(for: identity) === old)
                runtime.invalidateDerivedResources(domain: .mask, namespace: namespace)
                XCTAssertNil(runtime.cachedDerivedObject(for: identity))
            }
        }
    }

    func testDilationBudgetAndUnsubmittedLifetime() throws {
        let runtime = HarbethContext.shared, bytes = 1024 * 1024 * 16
        let source = try NeighborhoodTestImage(width: 1024, height: 1024, format: .rgba16Float)
        let destination = try NeighborhoodTestImage(width: 1024, height: 1024, format: .rgba16Float)
        let filter = C7RGBADilation(pixelRadius: 63), budget = runtime.morphologyScratchBudget
        try autoreleasepool {
            let command = try XCTUnwrap(runtime.makeCommandBuffer())
            let context = try MetalCommandEncodingContext(commandBuffer: command, textures: [destination.texture, source.texture])
            _ = try filter.encode(context: context, maximumTemporaryBytes: bytes)
            XCTAssertFalse(budget.reserve(1, limit: bytes))
            runtime.invalidateDerivedResources(domain: .mask, namespace: "harbeth.rgba-dilation.area-max")
            XCTAssertFalse(budget.reserve(1, limit: bytes))
        }
        XCTAssertTrue(budget.reserve(bytes, limit: bytes))
        let actual = try forced(source.texture, filter, limit: bytes)
        budget.release(bytes)
        let direct = try forced(source.texture, filter, limit: 0)
        XCTAssertEqual(actual.c7.rawBytes(maximumBytes: 1024 * 1024 * 8), direct.c7.rawBytes(maximumBytes: 1024 * 1024 * 8))
        XCTAssertFalse(C7RGBADilation.prefersMPS(width: 17, height: 13, radius: 63, maximumTemporaryBytes: bytes))
        XCTAssertFalse(C7RGBADilation.prefersMPS(width: 1024, height: 1024, radius: 3, maximumTemporaryBytes: bytes))
        XCTAssertFalse(C7RGBADilation.prefersMPS(width: 1024, height: 1024, radius: 63, maximumTemporaryBytes: 1))
    }

    func testNoiseReductionPreservesWhiteWithVariableCoverageAndTransparentZeros() throws {
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            var values = Array(repeating: [Float](repeating: 0.5, count: 4), count: 25).flatMap { $0 }
            for c in 0..<4 { values[c] = 0.25 }
            let input = try NeighborhoodTestImage.make(width: 5, height: 5, values: values, format: format)
            let expected = try NeighborhoodTestImage.read(input)
            for preservation: Float in [0,0.8,1] {
                let actual = try pixels(input, C7NoiseReduction(radius: 2, amount: 1, edgePreservation: preservation))
                for i in actual.indices { XCTAssertEqual(actual[i], expected[i], accuracy: 0.001) }
            }
            var sparse = [Float](repeating: 0, count: 100)
            for c in 0..<4 { sparse[48 + c] = 0.5 }
            let texture = try NeighborhoodTestImage.make(width: 5, height: 5, values: sparse, format: format)
            let actual = try pixels(texture, C7NoiseReduction(radius: 2, amount: 1, edgePreservation: 0))
            for i in stride(from: 0, to: actual.count, by: 4) {
                XCTAssertEqual(actual[i + 3], sparse[i + 3])
                for c in 0..<3 { XCTAssertEqual(actual[i + c], sparse[i + c], accuracy: 0.001) }
            }
        }
    }

    func testNoiseReductionMatchesDoubleReferenceIncludingImpulseFallback() throws {
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            let input = try NeighborhoodTestImage(width: 7, height: 5, format: format)
            let actual = try pixels(input.texture, C7NoiseReduction(radius: 2, amount: 0.7, edgePreservation: 0.4))
            let sigma = 0.35 + (0.08 - 0.35) * Double(Float(0.4))
            let amount = Double(Float(0.7)), preservation = Double(Float(0.4))
            func luma(_ i: Int) -> Double { (Double(input.values[i]) * 0.299 + Double(input.values[i + 1]) * 0.587 + Double(input.values[i + 2]) * 0.114) / Double(input.values[i + 3]) }
            for y in 0..<5 { for x in 0..<7 {
                let i = (y * 7 + x) * 4, alpha = Double(input.values[i + 3])
                if alpha == 0 { XCTAssertEqual(Array(actual[i..<i+4]), [0,0,0,0]); continue }
                var sum = [Double](repeating: 0, count: 4), spatial = sum
                for dy in -2...2 { for dx in -2...2 {
                    let n = (min(max(y + dy, 0), 4) * 7 + min(max(x + dx, 0), 6)) * 4
                    guard input.values[n + 3] > 0 else { continue }
                    let w = exp(-Double(dx * dx + dy * dy) / 4)
                    let delta = luma(n) - luma(i), range = exp(-delta * delta / (sigma * sigma))
                    for c in 0..<4 { sum[c] += Double(input.values[n + c]) * w * range; spatial[c] += Double(input.values[n + c]) * w }
                } }
                let spatialLuma = (spatial[0] * 0.299 + spatial[1] * 0.587 + spatial[2] * 0.114) / spatial[3]
                let impulse = min(max((abs(luma(i) - spatialLuma) - sigma * 0.5) / (1 - sigma * 0.5), 0), 1)
                let strength = amount * impulse * (0.45 + 0.35 * (1 - preservation))
                for c in 0..<3 {
                    let denoised = sum[c] / sum[3] + (spatial[c] / spatial[3] - sum[c] / sum[3]) * strength
                    let centre = Double(input.values[i + c]) / alpha
                    let expected = Float((centre + (denoised - centre) * amount) * alpha)
                    XCTAssertEqual(actual[i + c], expected, accuracy: format == .rgba16Float ? 0.001 : 0.00001)
                }
                XCTAssertEqual(actual[i + 3], input.values[i + 3])
            } }
        }
    }

    private func forced(_ source: MTLTexture, _ filter: C7RGBADilation, limit: Int) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: source.pixelFormat, width: source.width, height: source.height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.shaderRead, .shaderWrite]
        let destination = try XCTUnwrap(HarbethContext.shared.device.makeTexture(descriptor: descriptor))
        let command = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
        let context = try MetalCommandEncodingContext(commandBuffer: command, textures: [destination, source])
        _ = try filter.encode(context: context, maximumTemporaryBytes: limit)
        command.commit(); command.waitUntilCompleted()
        XCTAssertEqual(command.status, .completed)
        return destination
    }
    private func pixels(_ source: MTLTexture, _ filter: any C7FilterProtocol) throws -> [Float] {
        let out: MTLTexture = try HarbethIO(element: source, filter: filter).output()
        return try NeighborhoodTestImage.read(out)
    }
}
