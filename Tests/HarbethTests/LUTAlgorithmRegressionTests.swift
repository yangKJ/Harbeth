// 由 Condy 创建于 2026/11/16。
import Metal
import XCTest
@testable import Harbeth

final class LUTAlgorithmRegressionTests: XCTestCase {
    func testOneDimensionalLUTMatchesPiecewiseLinearReference() throws {
        let input = try NeighborhoodTestImage.make(width: 7, height: 1, values: [
            -0.5, 0, 1.5, 0.25, 0, 0.25, 1, 0.5, 0.25, 0.375, 0.75, 1,
            0.5, 0.75, 1, 0.5, 1, 0.5, 0, 1, 0.125, 0.875, 0.625, 0.75, 0, 0, 0, 0,
        ])
        let source = try NeighborhoodTestImage.read(input)
        for n in [1, 2, 4, 16, 256] {
            for nonlinear in [false, true] {
                var samples: [Float] = []
                for i in 0..<n {
                    let x = n == 1 ? Float(0.5) : Float(i) / Float(n - 1)
                    samples += nonlinear ? [x * x, 1 - x, x * x * x, 1] : [x, x, x, 1]
                }
                let lut = try NeighborhoodTestImage.make(width: n, height: 1, values: samples)
                let knots = try NeighborhoodTestImage.read(lut)
                for policy in [C7LookupTable1D.DomainPolicy.clampToEdge, .preserveOutsideDomain] {
                    for intensity: Float in [0, 0.5, 1] {
                        let filter = C7LookupTable1D(lookupTexture: lut, intensity: intensity, domainPolicy: policy)
                        let actual = try render(input, filter)
                        var expected = source
                        for i in stride(from: 0, to: source.count, by: 4) {
                            for c in 0..<3 {
                                let x = Double(source[i + c])
                                if policy == .preserveOutsideDomain && (x < 0 || x > 1) { continue }
                                let position = min(max(x, 0), 1) * Double(n - 1)
                                let lower = Int(position), upper = min(lower + 1, n - 1), t = position - Double(lower)
                                let mapped = Double(knots[lower * 4 + c]) * (1 - t) + Double(knots[upper * 4 + c]) * t
                                expected[i + c] = Float(x + Double(intensity) * (mapped - x))
                            }
                        }
                        assertPixels(actual, expected, tolerance: 0.0015)
                    }
                }
            }
        }
    }

    func testPacked512LUTPreservesLayoutInterpolationAndSourceAlpha() throws {
        let input = try NeighborhoodTestImage.make(width: 8, height: 1, values: [
            0, 0, 0, 0, 0.25, 0.375, 0.75, 0.5, 1, 1, 1, 1, 0.5, 0.25, 0.5, 0.25,
            0.125, 0.75, 15.5 / 31, 0.75, 0.875, 0.125, 30.5 / 31, 1, -0.5, 1.5, 0.5, 0.5, 1, 0, 1, 1,
        ])
        let source = try NeighborhoodTestImage.read(input)
        for nonlinear in [false, true] {
            let logical = cubeValues(32, nonlinear: nonlinear).map { Float(Float16($0)) }
            // 未使用区域保留哨兵色，错误跨切片会立即偏离数学参考。
            var packed = [Float](repeating: 0.9, count: 512 * 512 * 4)
            for z in 0..<32 { for y in 0..<32 { for x in 0..<32 {
                let src = ((z * 32 + y) * 32 + x) * 4
                let dst = (((z / 16) * 32 + y) * 512 + (z % 16) * 32 + x) * 4
                for c in 0..<4 { packed[dst + c] = logical[src + c] }
            } } }
            let lut = try NeighborhoodTestImage.make(width: 512, height: 512, values: packed)
            for intensity: Float in [0, 0.5, 1] {
                let actual = try render(input, C7ColorLookup512x512(lookupTexture: lut, intensity: intensity))
                var expected = source
                for i in stride(from: 0, to: source.count, by: 4) {
                    let color = SIMD3<Double>(Double(source[i]), Double(source[i + 1]), Double(source[i + 2]))
                    let mapped = cubeReference(logical, n: 32, color: color, tetrahedral: false)
                    for c in 0..<3 { expected[i + c] = source[i + c] + intensity * (Float(mapped[c]) - source[i + c]) }
                }
                assertPixels(actual, expected, tolerance: 0.002)
            }
        }
    }

    func testCubeInterpolationsMatchIndependentDoublePrecisionReference() throws {
        let coordinates: [SIMD3<Float>] = [
            .init(0.8, 0.5, 0.2), .init(0.8, 0.2, 0.5), .init(0.5, 0.2, 0.8),
            .init(0.2, 0.5, 0.8), .init(0.2, 0.8, 0.5), .init(0.5, 0.8, 0.2),
            .init(repeating: 0.5), .zero, .init(repeating: 1), .init(0, 0.5, 1), .init(-0.25, 0.4, 1.25),
        ]
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            let pixels = coordinates.enumerated().flatMap { i, p in [p.x, p.y, p.z, Float(i % 4) / 3] }
            let input = try NeighborhoodTestImage.make(width: coordinates.count, height: 1, values: pixels, format: format)
            let source = try NeighborhoodTestImage.read(input)
            for n in [2, 3, 17, 65] {
                let values = cubeValues(n, nonlinear: true)
                let resource = C7ColorCube.Resource(dimension: n, data: data(values))
                for interpolation in [C7ColorCube.Interpolation.trilinear, .tetrahedral] {
                    for policy in [C7ColorCube.DomainPolicy.clampToDomain, .preserveOutsideDomain] {
                        for intensity: Float in [0, 0.5, 1] {
                            let filter = C7ColorCube(cubeResource: resource, intensity: intensity, interpolation: interpolation, domainPolicy: policy)
                            let actual = try render(input, filter)
                            var expected = source
                            for i in stride(from: 0, to: source.count, by: 4) {
                                let color = SIMD3<Double>(Double(source[i]), Double(source[i + 1]), Double(source[i + 2]))
                                if policy == .preserveOutsideDomain && (0..<3).contains(where: { color[$0] < 0 || color[$0] > 1 }) { continue }
                                let mapped = cubeReference(values, n: n, color: color, tetrahedral: interpolation == .tetrahedral)
                                for c in 0..<3 { expected[i + c] = source[i + c] + intensity * (Float(mapped[c]) - source[i + c]) }
                            }
                            assertPixels(actual, expected, tolerance: format == .rgba16Float ? 0.0015 : 0.000005)
                        }
                    }
                }
            }
        }
    }

    func testCubeNormalTinyWideAndPerAxisDomains() throws {
        let unit = data(cubeValues(2, nonlinear: false))
        let ranges: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = [
            (.zero, .init(repeating: 1), .init(repeating: 0.5), .init(repeating: 0.5)),
            (.zero, .init(repeating: 1 / 8388608), .init(repeating: 1 / 16777216), .init(repeating: 0.5)),
            (.init(repeating: -Float.greatestFiniteMagnitude), .init(repeating: Float.greatestFiniteMagnitude), .zero, .init(repeating: 0.5)),
            (.init(-1, 2, -8), .init(3, 6, -4), .init(0, 4, -5), .init(0.25, 0.5, 0.75)),
        ]
        for (minimum, maximum, value, expected) in ranges {
            for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
                let input = try NeighborhoodTestImage.make(width: 1, height: 1, values: [value.x, value.y, value.z, 0.5], format: format)
                for interpolation in [C7ColorCube.Interpolation.trilinear, .tetrahedral] {
                    let resource = C7ColorCube.Resource(dimension: 2, data: unit, domainMinimum: minimum, domainMaximum: maximum)
                    for policy in [C7ColorCube.DomainPolicy.clampToDomain, .preserveOutsideDomain] {
                        assertPixels(try render(input, C7ColorCube(cubeResource: resource, interpolation: interpolation, domainPolicy: policy)),
                                     [expected.x, expected.y, expected.z, 0.5], tolerance: 0.0005)
                    }
                }
            }
        }
    }

    func testCubeOutsideDomainAndZeroIntensityPreserveFloat32Bits() throws {
        let resource = C7ColorCube.Resource(dimension: 2, data: data(cubeValues(2, nonlinear: true)))
        let input = try NeighborhoodTestImage.make(width: 2, height: 1, values: [
            Float(1).nextUp, 0.1234567, 0.654321, 0.3333333, -0.00000001, 0.9, 0.6, 0.1234567,
        ], format: .rgba32Float)
        let expected = input.c7.rawBytes(maximumBytes: 32)
        for filter in [C7ColorCube(cubeResource: resource, intensity: 0),
                       C7ColorCube(cubeResource: resource, domainPolicy: .preserveOutsideDomain)] {
            let output: MTLTexture = try HarbethIO(element: input, filter: filter).output()
            XCTAssertEqual(output.c7.rawBytes(maximumBytes: 32), expected)
            let node = try ImageNode.texture(input).applying(filter).makeTexture()
            XCTAssertEqual(node.c7.rawBytes(maximumBytes: 32), expected)
        }
    }

    func testExplicitHalfOutputRoundingDoesNotNarrowFloat32() throws {
        let value: Float = 0.5003
        let resource = C7ColorCube.Resource(dimension: 2, data: data(Array(repeating: [value, value, value, 1], count: 8).flatMap { $0 }))
        let filter = C7ColorCube(cubeResource: resource)
        let input = try NeighborhoodTestImage.make(width: 1, height: 1, values: [0.25, 0.5, 0.75, 1], format: .rgba32Float)
        for candidate: any C7FilterProtocol in [filter, ForwardedAlgorithmFilter(base: filter)] {
            assertPixels(try render(input, candidate), [value, value, value, 1], tolerance: 0.0000001)
            let destination = try NeighborhoodTestImage.make(width: 1, height: 1, values: [0, 0, 0, 0])
            let command = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
            _ = try candidate.encode(input: input, destination: destination, commandBuffer: command)
            command.commit(); command.waitUntilCompleted()
            XCTAssertEqual(command.status, .completed)
            let rounded = Float(Float16(value))
            XCTAssertEqual(try NeighborhoodTestImage.read(destination), [rounded, rounded, rounded, 1])
        }
    }

    func testInvalidCubeResourcesFailBeforeEncodingAcrossEntryPoints() throws {
        let valid = cubeValues(2, nonlinear: false), unit = data(valid)
        var resources: [C7ColorCube.Resource] = []
        for dimension in [Int.min, -1, 0, 1, 66, Int.max] { resources.append(.init(dimension: dimension, data: unit)) }
        resources.append(.init(dimension: 2, data: unit.dropLast()))
        for (lo, hi): (Float, Float) in [(1, 0), (1, 1), (.nan, 1), (0, .infinity), (-.infinity, 1)] {
            resources.append(.init(dimension: 2, data: unit, domainMinimum: .init(lo, 0, 0), domainMaximum: .init(hi, 1, 1)))
        }
        for value: Float in [.nan, .infinity, -.infinity] {
            var invalid = valid; invalid[0] = value
            resources.append(.init(dimension: 2, data: data(invalid)))
        }
        let input = try NeighborhoodTestImage.make(width: 1, height: 1, values: [0.25, 0.5, 0.75, 1])
        for resource in resources {
            let filter = C7ColorCube(cubeResource: resource)
            XCTAssertTrue(filter.otherInputTextures.isEmpty)
            XCTAssertNil(filter.resourceIdentity)
            assertCubeError(filter.resourceLoadError)
            XCTAssertThrowsError(try render(input, filter)) { self.assertCubeError($0) }
            XCTAssertThrowsError(try ImageNode.texture(input).applying(filter).makeTexture()) { self.assertCubeError($0) }
            let commandBuffer = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
            let destination = try NeighborhoodTestImage.make(width: 1, height: 1, values: [0, 0, 0, 0])
            XCTAssertThrowsError(try filter.encode(input: input, destination: destination, commandBuffer: commandBuffer)) { self.assertCubeError($0) }
            let updated = C7ColorCube(cubeResource: .init(dimension: 2, data: unit)).updateCubeResource(resource)
            assertCubeError(updated.resourceLoadError)
            XCTAssertTrue(updated.otherInputTextures.isEmpty)
        }
        let raw = C7ColorCube(cubeData: data([.nan] + Array(valid.dropFirst())), dimension: 2)
        assertCubeError(raw.resourceLoadError)
        let recovered = raw.updateCubeResource(.init(dimension: 2, data: unit))
        XCTAssertNil(recovered.resourceLoadError)
        XCTAssertEqual(recovered.otherInputTextures.count, 1)
        XCTAssertNil(recovered.updateCubeResource(nil).resourceLoadError)
    }

    func testUnalignedCubeDataAndConcurrentTextureCreation() throws {
        let values = data(cubeValues(65, nonlinear: true))
        let unaligned = (Data([0]) + values).dropFirst()
        let resource = C7ColorCube.Resource(dimension: 65, data: unaligned)
        let context = HarbethContext.shared
        context.invalidateDerivedResources(domain: .lookupTable, namespace: "harbeth.lookup-table")
        defer { context.invalidateDerivedResources(domain: .lookupTable, namespace: "harbeth.lookup-table") }
        let collector = TextureCollector()
        let group = DispatchGroup(), gate = DispatchSemaphore(value: 0)
        for _ in 0..<8 {
            group.enter()
            DispatchQueue.global().async {
                gate.wait()
                collector.append(C7ColorCube(cubeResource: resource).otherInputTextures.first)
                group.leave()
            }
        }
        for _ in 0..<8 { gate.signal() }
        XCTAssertEqual(group.wait(timeout: .now() + 10), .success)
        let textures = collector.values
        XCTAssertEqual(textures.count, 8)
        XCTAssertEqual(Set(textures.map { ObjectIdentifier($0) }).count, 1)
        let old = try XCTUnwrap(textures.first)
        XCTAssertEqual(old.width, 65); XCTAssertEqual(old.height, 65); XCTAssertEqual(old.depth, 65)
        context.invalidateDerivedResources(domain: .lookupTable, namespace: "harbeth.lookup-table")
        let fresh = try XCTUnwrap(C7ColorCube(cubeResource: resource).otherInputTextures.first)
        XCTAssertFalse(fresh === old)
        let input = try NeighborhoodTestImage.make(width: 1, height: 1, values: [0.125, 0.25, 0.5, 1])
        let expected = cubeReference(cubeValues(65, nonlinear: true), n: 65, color: .init(0.125, 0.25, 0.5), tetrahedral: true)
        assertPixels(try render(input, C7ColorCube(cubeResource: resource)), [Float(expected.x), Float(expected.y), Float(expected.z), 1], tolerance: 0.0015)
    }

    private func render(_ input: MTLTexture, _ filter: any C7FilterProtocol) throws -> [Float] {
        let output: MTLTexture = try HarbethIO(element: input, filter: filter).output()
        return try NeighborhoodTestImage.read(output)
    }

    private func data(_ values: [Float]) -> Data { values.withUnsafeBufferPointer { Data(buffer: $0) } }

    private func cubeValues(_ n: Int, nonlinear: Bool) -> [Float] {
        var result: [Float] = []
        for z in 0..<n { for y in 0..<n { for x in 0..<n {
            if nonlinear {
                result += [Float((x * 17 + y * 7 + z * 29) % 101) / 100,
                           Float((x * 13 + y * 23 + z * 3) % 103) / 102,
                           Float((x * 5 + y * 11 + z * 31) % 107) / 106, 1]
            } else { result += [Float(x) / Float(n - 1), Float(y) / Float(n - 1), Float(z) / Float(n - 1), 1] }
        } } }
        return result
    }

    private func cubeReference(_ values: [Float], n: Int, color: SIMD3<Double>, tetrahedral: Bool) -> SIMD3<Double> {
        let p = (0..<3).map { min(max(color[$0], 0), 1) * Double(n - 1) }
        let base = p.map { Int(floor($0)) }, f = (0..<3).map { p[$0] - Double(base[$0]) }
        func read(_ offset: [Int]) -> SIMD3<Double> {
            let xyz = (0..<3).map { min(base[$0] + offset[$0], n - 1) }
            let i = ((xyz[2] * n + xyz[1]) * n + xyz[0]) * 4
            return .init(Double(values[i]), Double(values[i + 1]), Double(values[i + 2]))
        }
        var result = SIMD3<Double>.zero
        if tetrahedral {
            // 通过排序后的重心权重求和，独立于 shader 的六分支差分表达式。
            let axes = (0..<3).sorted { f[$0] > f[$1] }
            let weights = [1 - f[axes[0]], f[axes[0]] - f[axes[1]], f[axes[1]] - f[axes[2]], f[axes[2]]]
            var offset = [0, 0, 0]
            for vertex in 0..<4 {
                result += read(offset) * weights[vertex]
                if vertex < 3 { offset[axes[vertex]] = 1 }
            }
        } else {
            for z in 0...1 { for y in 0...1 { for x in 0...1 {
                let weight = (x == 0 ? 1 - f[0] : f[0]) * (y == 0 ? 1 - f[1] : f[1]) * (z == 0 ? 1 - f[2] : f[2])
                result += read([x, y, z]) * weight
            } } }
        }
        return result
    }

    private func assertPixels(_ actual: [Float], _ expected: [Float], tolerance: Float, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for i in expected.indices {
            guard actual[i].isFinite, abs(actual[i] - expected[i]) <= tolerance else {
                XCTFail("分量 \(i)：实际 \(actual[i])，期望 \(expected[i])", file: file, line: line)
                return
            }
        }
    }

    private func assertCubeError(_ error: Error?, file: StaticString = #filePath, line: UInt = #line) {
        guard case .some(.cubeResource) = error as? HarbethError else {
            return XCTFail("期望 cubeResource，实际 \(String(describing: error))", file: file, line: line)
        }
    }
}

final class TextureCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var textures: [MTLTexture] = []
    func append(_ texture: MTLTexture?) {
        lock.lock(); defer { lock.unlock() }
        if let texture { textures.append(texture) }
    }
    var values: [MTLTexture] { lock.lock(); defer { lock.unlock() }; return textures }
}

extension NeighborhoodTestImage {
    static func make(width: Int, height: Int, values: [Float], format: MTLPixelFormat = .rgba16Float) throws -> MTLTexture {
        XCTAssertEqual(values.count, width * height * 4)
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        if format == .rgba16Float {
            let half = values.map { Float16($0) }
            half.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 8) }
        } else if format == .rgba8Unorm {
            let bytes = values.map { UInt8((min(max($0, 0), 1) * 255).rounded()) }
            bytes.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 4) }
        } else {
            values.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 16) }
        }
        return texture
    }
}

// 模拟仅转发公开合同的区域/宿主包装，不依赖内部类型能力。
struct ForwardedAlgorithmFilter: C7FilterProtocol {
    let base: any C7FilterProtocol
    var modifier: ModifierEnum { base.modifier }
    var factors: [Float] { base.factors }
    var kernelParameterBindings: [KernelParameterBinding] { base.kernelParameterBindings }
    var otherInputTextures: C7InputTextures { base.otherInputTextures }
    var kernelPixelContract: KernelPixelContract { base.kernelPixelContract }
    var memoryAccessPattern: MemoryAccessPattern { base.memoryAccessPattern }
}
