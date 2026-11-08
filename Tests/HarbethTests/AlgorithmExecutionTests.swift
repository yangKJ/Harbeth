//
//  AlgorithmExecutionTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/11/8.
//

import Metal
import XCTest
@testable import Harbeth

final class AlgorithmExecutionTests: XCTestCase {
    func testSharedFingerprintPreservesTextEqualityAcrossDifferentSegmentations() {
        let prefix = ImageGraphFingerprint("源|e\u{301}")
        let shared = ImageGraphFingerprint(parts: [prefix, ImageGraphFingerprint("|末尾")])
        let flat = ImageGraphFingerprint("源|é|末尾")
        XCTAssertEqual(shared, flat)
        XCTAssertEqual(Set([shared, flat]).count, 1)
        var chain = ImageGraphFingerprint("")
        for _ in 0..<2_000 { chain = ImageGraphFingerprint(parts: [chain, ImageGraphFingerprint("x")]) }
        XCTAssertEqual(chain.value, String(repeating: "x", count: 2_000))
    }

    func testPointwiseSpecializationUsesOnlyTopologyAndKeepsGenericFallback() {
        let first = C7FusedPointOperations(operations: [.init(kind: .brightness, value: 0.1), .init(kind: .contrast, value: 1.2)])
        let second = C7FusedPointOperations(operations: [.init(kind: .brightness, value: 0.3), .init(kind: .contrast, value: 0.9)])
        XCTAssertEqual(first.computeKernelFunctionConstants, second.computeKernelFunctionConstants)
        XCTAssertNotEqual(first.kernelParameterBindings, second.kernelParameterBindings)
        XCTAssertTrue(first.usesSpecializedKernel)
        XCTAssertFalse(C7FusedPointOperations(operations: first.operations.reversed()).usesSpecializedKernel)
        XCTAssertFalse(C7FusedPointOperations(operations: [first.operations[0], first.operations[0]]).usesSpecializedKernel)
    }

    func testSpecializedPointwisePixelsMatchGenericHalfFloatExecution() throws {
        let source = try makeTexture(width: 37, height: 19)
        let sequences: [[C7FusedPointOperations.Operation]] = [
            [.init(kind: .brightness, value: 0.04), .init(kind: .contrast, value: 1.1)],
            [.init(kind: .saturation, value: 0.8), .init(kind: .exposure, value: 0.3)],
            [.init(kind: .brightness, value: 0.1), .init(kind: .contrast, value: 0.9),
             .init(kind: .saturation, value: 0.7), .init(kind: .exposure, value: 0.1),
             .init(kind: .gamma, value: 1.05), .init(kind: .opacity, value: 0.6)]
        ]
        for operations in sequences {
            let filter = C7FusedPointOperations(operations: operations)
            let actual = try render(filter, source: source).texture
            let expected = try render(GenericPointOperations(base: filter), source: source).texture
            XCTAssertEqual(read(actual), read(expected))
        }
    }

    func testBilateralSquaredDistancesMatchOriginalAcrossOddExtentsAndRadii() throws {
        try prepareBilateralReference()
        for (width, height) in [(1, 1), (3, 17), (35, 19)] {
            let source = try makeTexture(width: width, height: height)
            for (radius, space, color): (Float, Float, Float) in [
                (1, 5, 0.25), (3.5, 5, 0.25), (7, 5, 0.25), (16.9, 5, 0.25), (17, 5, 0.25),
                (7, 0.5, 0.01), (7, 15, 2)
            ] {
                let filter = C7BilateralBlur(sigmaSpace: space, sigmaColor: color, radius: radius)
                let actual = try render(filter, source: source).texture
                let expected = try render(OriginalBilateral(base: filter), source: source).texture
                XCTAssertEqual(read(actual), read(expected), "尺寸 \(width)x\(height)，半径 \(radius)")
            }
        }
    }

    func testGroupedCLAHECountsAndParallelLookupMatchSerialKernels() throws {
        for (width, height, columns, rows) in [(1, 1, 1, 1), (17, 19, 3, 5), (137, 91, 7, 3)] {
            let source = try makeTexture(width: width, height: height)
            for uniform in [false, true] {
                if uniform {
                    let values = [Float16](repeating: 0.5, count: width * height * 4)
                    values.withUnsafeBytes { source.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                        withBytes: $0.baseAddress!, bytesPerRow: width * 8) }
                }
                let serial = try histogram(source, columns: columns, rows: rows, grouped: false)
                let grouped = try histogram(source, columns: columns, rows: rows, grouped: true)
                XCTAssertEqual(bytes(serial.histogram), bytes(grouped.histogram))
                XCTAssertEqual(bytes(serial.counts), bytes(grouped.counts))
                for limit: Float in [0.25, 2, 16] {
                    let expected = try lookup(serial, columns: columns, rows: rows, limit: limit, parallel: false)
                    let actual = try lookup(grouped, columns: columns, rows: rows, limit: limit, parallel: true)
                    XCTAssertEqual(bytes(actual), bytes(expected), "网格 \(columns)x\(rows)，限制 \(limit)")
                }
            }
        }
    }

    func testAlgorithmBenchmarksWhenRequested() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["HARBETH_ALGORITHM_BENCHMARKS"] == "1", "按需运行算法微基准")
        try prepareBilateralReference()
        let source = try makeTexture(width: 1_024, height: 1_024)
        let bilateral = C7BilateralBlur(radius: 7)
        let pointwise = C7FusedPointOperations(operations: [
            .init(kind: .brightness, value: 0.05), .init(kind: .contrast, value: 1.1),
            .init(kind: .saturation, value: 0.8), .init(kind: .exposure, value: 0.1),
            .init(kind: .gamma, value: 1.05), .init(kind: .opacity, value: 0.9)
        ])
        for (name, before, after): (String, C7FilterProtocol, C7FilterProtocol) in [
            ("bilateral", OriginalBilateral(base: bilateral), bilateral),
            ("pointwise", GenericPointOperations(base: pointwise), pointwise)
        ] {
            _ = try render(before, source: source, repetitions: 16)
            _ = try render(after, source: source, repetitions: 16)
            var original: [Double] = [], optimized: [Double] = []
            for index in 0..<9 {
                if index.isMultiple(of: 2) {
                    original.append(try render(before, source: source, repetitions: 16).gpuMS)
                    optimized.append(try render(after, source: source, repetitions: 16).gpuMS)
                } else {
                    optimized.append(try render(after, source: source, repetitions: 16).gpuMS)
                    original.append(try render(before, source: source, repetitions: 16).gpuMS)
                }
            }
            print("算法基准 \(name) GPU 中位数 ms：\(original.sorted()[4]) → \(optimized.sorted()[4])")
        }
        for grouped in [false, true] {
            var times: [Double] = []
            for _ in 0..<7 {
                let result = try histogram(source, columns: 8, rows: 8, grouped: grouped)
                times.append(result.gpuMS)
            }
            print("算法基准 CLAHE grouped=\(grouped) GPU 中位数 ms：\(times.sorted()[3])")
        }
        let base = ImageNode.texture(source)
        let node = (0..<256).reduce(base) { node, _ in node.applying(C7Brightness(brightness: 0.001)) }
        let start = Date()
        var nodes = 0
        for _ in 0..<20 { nodes += try node.makeImageGraph().nodeCount }
        print("算法基准 256 层图构建 20 次 ms：\(Date().timeIntervalSince(start) * 1_000)，节点 \(nodes)")
    }

    private func prepareBilateralReference() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void BilateralReference(texture2d<half, access::write> outputTexture [[texture(0)]],
                                    texture2d<half, access::read> inputTexture [[texture(1)]],
                                    constant float *sigmaSpace [[buffer(0)]],
                                    constant float *sigmaColor [[buffer(1)]],
                                    constant float *blurRadius [[buffer(2)]],
                                    uint2 grid [[thread_position_in_grid]]) {
            const float x = float(grid.x);
            const float y = float(grid.y);
            const float width = float(inputTexture.get_width());
            const float height = float(inputTexture.get_height());

            uint2 centralPixel = uint2(x, y);
            half4 centralColor = inputTexture.read(centralPixel);

            int radius = int(*blurRadius);
            if (radius < 1) radius = 1;

            half4 sum = half4(0.0, 0.0, 0.0, 0.0);
            half weightSum = 0.0;

            float sigmaSpaceSquared = *sigmaSpace * *sigmaSpace;
            float sigmaColorSquared = *sigmaColor * *sigmaColor;

            for (int i = -radius; i <= radius; i++) {
                for (int j = -radius; j <= radius; j++) {
                    int2 offset = int2(i, j);
                    uint2 currentPixel = uint2(clamp(int(x) + offset.x, 0, int(width) - 1),
                                               clamp(int(y) + offset.y, 0, int(height) - 1));
                    half4 currentColor = inputTexture.read(currentPixel);
                    float spatialDistance = sqrt(float(i * i + j * j));
                    half3 colorDiff = currentColor.rgb - centralColor.rgb;
                    float colorDistance = length(float3(colorDiff));
                    float spatialWeight = exp(-(spatialDistance * spatialDistance) / (2.0 * sigmaSpaceSquared));
                    float colorWeight = exp(-(colorDistance * colorDistance) / (2.0 * sigmaColorSquared));
                    float weight = spatialWeight * colorWeight;
                    sum += currentColor * half(weight);
                    weightSum += half(weight);
                }
            }
            half4 outColor = sum / weightSum;

            outputTexture.write(outColor, grid);
        }
        """
        let library = try device.makeLibrary(source: source, options: nil)
        HarbethContext.shared.registerExternalLibraryProvider(AlgorithmReferenceLibrary(library: library))
    }

    private func makeTexture(width: Int, height: Int) throws -> MTLTexture {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        var values = [Float16](repeating: 0, count: width * height * 4)
        for i in 0..<(width * height) {
            let alpha: Float = i % 17 == 0 ? 0 : i % 5 == 0 ? 0.5 : 1
            values[i * 4] = Float16((i % 31 == 0 ? -0.08 : Float((i * 7) % 251) / 250) * alpha)
            values[i * 4 + 1] = Float16(Float((i * 13) % 193) / 192 * alpha)
            values[i * 4 + 2] = Float16((i % 23 == 0 ? 2 : Float((i * 19) % 157) / 156) * alpha)
            values[i * 4 + 3] = Float16(alpha)
        }
        values.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
            withBytes: $0.baseAddress!, bytesPerRow: width * 8) }
        return texture
    }

    private func render(_ filter: C7FilterProtocol, source: MTLTexture, repetitions: Int = 1) throws -> (texture: MTLTexture, gpuMS: Double) {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: source.pixelFormat, width: source.width, height: source.height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared
        let output = try XCTUnwrap(source.device.makeTexture(descriptor: descriptor))
        let command = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
        for _ in 0..<repetitions { _ = try filter.applyAtTexture(form: source, to: output, for: command) }
        try command.commitAndWaitUntilCompleted(identifier: "AlgorithmExecutionTests")
        return (output, (command.gpuEndTime - command.gpuStartTime) * 1_000 / Double(repetitions))
    }

    private func read(_ texture: MTLTexture) -> [UInt16] {
        var result = [UInt16](repeating: 0, count: texture.width * texture.height * 4)
        texture.getBytes(&result, bytesPerRow: texture.width * 8, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        return result
    }

    private struct Histogram {
        let histogram: MTLBuffer
        let counts: MTLBuffer
        let gpuMS: Double
    }

    private func bytes(_ buffer: MTLBuffer) -> Data { Data(bytes: buffer.contents(), count: buffer.length) }

    private func histogram(_ source: MTLTexture, columns: Int, rows: Int, grouped: Bool) throws -> Histogram {
        let device = source.device
        let histogram = try XCTUnwrap(device.makeBuffer(length: columns * rows * 256 * 4, options: .storageModeShared))
        let counts = try XCTUnwrap(device.makeBuffer(length: columns * rows * 4, options: .storageModeShared))
        memset(histogram.contents(), 0, histogram.length)
        memset(counts.contents(), 0, counts.length)
        let command = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
        let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
        encoder.setComputePipelineState(try Compute.makeComputePipelineState(with: grouped ? "C7CLAHEHistogramGrouped" : "C7CLAHEHistogram"))
        encoder.setTexture(source, index: 0)
        encoder.setBuffer(histogram, offset: 0, index: 0)
        encoder.setBuffer(counts, offset: 0, index: 1)
        var x = UInt32(columns), y = UInt32(rows)
        encoder.setBytes(&x, length: 4, index: 2)
        encoder.setBytes(&y, length: 4, index: 3)
        let width = grouped ? (source.width + columns - 1) / columns : source.width
        let height = grouped ? (source.height + rows - 1) / rows : source.height
        encoder.dispatchThreadgroups(MTLSize(width: (width + 15) / 16, height: (height + 15) / 16, depth: grouped ? columns * rows : 1),
            threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1))
        encoder.endEncoding()
        try command.commitAndWaitUntilCompleted(identifier: "AlgorithmExecutionTests.histogram")
        return Histogram(histogram: histogram, counts: counts, gpuMS: (command.gpuEndTime - command.gpuStartTime) * 1_000)
    }

    private func lookup(_ histogram: Histogram, columns: Int, rows: Int, limit: Float, parallel: Bool) throws -> MTLBuffer {
        let result = try XCTUnwrap(histogram.histogram.device.makeBuffer(length: columns * rows * 256 * 4, options: .storageModeShared))
        let command = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
        let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
        encoder.setComputePipelineState(try Compute.makeComputePipelineState(with: parallel ? "C7CLAHEBuildLookupTableParallel" : "C7CLAHEBuildLookupTable"))
        encoder.setBuffer(histogram.histogram, offset: 0, index: 0)
        encoder.setBuffer(histogram.counts, offset: 0, index: 1)
        encoder.setBuffer(result, offset: 0, index: 2)
        var x = UInt32(columns), y = UInt32(rows), clip = limit
        encoder.setBytes(&x, length: 4, index: 3)
        encoder.setBytes(&y, length: 4, index: 4)
        encoder.setBytes(&clip, length: 4, index: 5)
        encoder.dispatchThreadgroups(MTLSize(width: columns * rows, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: parallel ? 256 : 1, height: 1, depth: 1))
        encoder.endEncoding()
        try command.commitAndWaitUntilCompleted(identifier: "AlgorithmExecutionTests.lookup")
        return result
    }
}

private struct GenericPointOperations: C7FilterProtocol {
    let base: C7FusedPointOperations
    var modifier: ModifierEnum { .compute(kernel: "C7FusedPointOperations") }
    var kernelParameterBindings: [KernelParameterBinding] { base.kernelParameterBindings }
    var memoryAccessPattern: MemoryAccessPattern { base.memoryAccessPattern }
}

private struct OriginalBilateral: C7FilterProtocol {
    let base: C7BilateralBlur
    var modifier: ModifierEnum { .compute(kernel: "BilateralReference") }
    var computeKernelLibrarySource: KernelLibrarySource { .externalProvider("algorithm-reference") }
    var factors: [Float] { base.factors }
    var memoryAccessPattern: MemoryAccessPattern { .neighborhood }
}

private struct AlgorithmReferenceLibrary: ExternalMTLLibraryProvider {
    let library: MTLLibrary
    var providerIdentifier: String { "algorithm-reference" }
    func provideLibrary(for device: MTLDevice) -> MTLLibrary? { library }
}
