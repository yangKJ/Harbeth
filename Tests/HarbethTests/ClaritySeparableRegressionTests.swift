//
//  ClaritySeparableRegressionTests.metal
//  Harbeth
//
//  Created by Condy on 2026/11/16.
//

import XCTest
import Metal
@testable import Harbeth

final class ClaritySeparableRegressionTests: XCTestCase {
    func testSeparableAndBudgetFallbackMatchOriginalGaussianReference() throws {
        for format in NeighborhoodTestImage.formats {
            let input = try NeighborhoodTestImage(width: 67, height: 65, format: format)
            for radius: Float in [0.12, 0.3] {
                let expected = reference(input.values, width: 67, height: 65, radius: radius, intensity: 0.7)
                let filter = C7Clarity(intensity: 0.7, radius: radius)
                let fast = try encode(input.texture, filter: filter, budget: 16 * 1024 * 1024)
                let direct = try encode(input.texture, filter: filter, budget: 0)
                input.assertPixels(try NeighborhoodTestImage.read(fast), expected)
                input.assertPixels(try NeighborhoodTestImage.read(direct), expected)
                let a = try NeighborhoodTestImage.read(fast), b = try NeighborhoodTestImage.read(direct)
                for i in stride(from: 3, to: a.count, by: 4) {
                    XCTAssertEqual(a[i], input.values[i]); XCTAssertEqual(b[i], input.values[i])
                }
            }
        }
    }

    func testSmallOddAndSinglePixelKeepTruncatedBoundaryNormalization() throws {
        for (width, height) in [(1,1), (17,13)] {
            let input = try NeighborhoodTestImage(width: width, height: height, format: .rgba32Float, constant: width == 1 ? 0.5 : nil)
            let output: MTLTexture = try HarbethIO(element: input.texture, filter: C7Clarity()).output()
            input.assertPixels(try NeighborhoodTestImage.read(output), reference(input.values, width: width, height: height, radius: 0.12, intensity: 1))
        }
    }

    func testZeroAndNonFiniteParametersPreserveFloat32Pixels() throws {
        let input = try NeighborhoodTestImage(width: 67, height: 65, format: .rgba32Float)
        let bytes = try XCTUnwrap(input.texture.c7.rawBytes(maximumBytes: 67 * 65 * 16))
        for filter in [C7Clarity(intensity: 0), C7Clarity(radius: 0), C7Clarity(radius: .nan), C7Clarity(intensity: .nan)] {
            let output: MTLTexture = try HarbethIO(element: input.texture, filter: filter).output()
            XCTAssertEqual(output.c7.rawBytes(maximumBytes: bytes.count), bytes)
        }
    }

    func testHDRConstantsStayFiniteOnBothExecutionPaths() throws {
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            for value: Float in [10000, 65504] {
                let input = try NeighborhoodTestImage(width: 67, height: 65, format: format, constant: value)
                for budget in [0, 16 * 1024 * 1024] {
                    let output = try encode(input.texture, filter: C7Clarity(), budget: budget)
                    input.assertPixels(try NeighborhoodTestImage.read(output), input.values, tolerance: value * 0.001)
                }
            }
        }
    }

    func testTemporarySelectionAndConcurrentReservationStayBounded() {
        XCTAssertFalse(C7Clarity.usesSeparable(width: 1, height: 1, radius: 0.12, maximumTemporaryBytes: Int.max))
        XCTAssertFalse(C7Clarity.usesSeparable(width: 3840, height: 2160, radius: 0.12, maximumTemporaryBytes: 64 * 1024 * 1024))
        XCTAssertTrue(C7Clarity.usesSeparable(width: 3840, height: 2160, radius: 0.12, maximumTemporaryBytes: 128 * 1024 * 1024))
        XCTAssertFalse(C7Clarity.usesSeparable(width: Int.max, height: Int.max, radius: 0.12, maximumTemporaryBytes: Int.max))
        let budget = ClarityScratchBudget()
        XCTAssertTrue(budget.reserve(32, limit: 64)); XCTAssertTrue(budget.reserve(32, limit: 64))
        DispatchQueue.concurrentPerform(iterations: 16) { _ in XCTAssertFalse(budget.reserve(1, limit: 64)) }
        budget.release(32); budget.release(32)
        XCTAssertTrue(budget.reserve(64, limit: 64)); budget.release(64)
    }

    func testRequestBudgetIncludesTheInternalFloatSurface() throws {
        let input = try NeighborhoodTestImage(width: 67, height: 65, format: .rgba32Float)
        let request = try HarbethIO(element: input.texture, filter: C7Clarity()).makeRenderRequest()
        XCTAssertGreaterThanOrEqual(request.resourceEstimate.transientBytes, 67 * 65 * 16)
        let limited = request.withResourceBudget(.init(maximumTransientBytes: 0))
        XCTAssertFalse(limited.resourceAdmission.isAccepted)
        XCTAssertThrowsError(try limited.renderTexture())
        let nodeRequest = try ImageNode.texture(input.texture).applying(C7Clarity()).makeRenderRequest()
        XCTAssertGreaterThanOrEqual(nodeRequest.resourceEstimate.transientBytes, 67 * 65 * 16)
        let nodeOutput = try nodeRequest.renderTexture()
        input.assertPixels(try NeighborhoodTestImage.read(nodeOutput), reference(input.values, width: 67, height: 65, radius: 0.12, intensity: 1))
    }

    func testScratchAllocationFailureFallsBackWithoutChangingOutput() throws {
        let input = try NeighborhoodTestImage(width: 67, height: 65, format: .rgba16Float)
        let context = HarbethContext.shared
        let original = context.textureAllocator
        let allocator = RejectClarityScratchAllocator(texturePool: TexturePool(device: input.texture.device), strategy: .exact)
        context.setTextureAllocatorForTesting(allocator)
        defer { context.setTextureAllocatorForTesting(original) }
        let output: MTLTexture = try HarbethIO(element: input.texture, filter: C7Clarity()).output()
        XCTAssertEqual(allocator.rejectedCount, 1)
        input.assertPixels(try NeighborhoodTestImage.read(output), reference(input.values, width: 67, height: 65, radius: 0.12, intensity: 1))
    }

    func testUnsubmittedBufferDestructionReturnsScratchReservation() throws {
        let input = try NeighborhoodTestImage(width: 67, height: 65, format: .rgba32Float)
        let bytes = 67 * 65 * 16
        try autoreleasepool {
            let command = try XCTUnwrap(HarbethContext.shared.commandQueue.makeCommandBuffer())
            let destination = try XCTUnwrap(input.texture.device.makeTexture(descriptor: input.texture.c7.descriptor))
            let context = try MetalCommandEncodingContext(commandBuffer: command, textures: [destination, input.texture])
            _ = try C7Clarity().encode(context: context, maximumTemporaryBytes: bytes)
            XCTAssertFalse(ClarityScratchBudget.shared.reserve(1, limit: bytes))
        }
        let returned = ClarityScratchBudget.shared.reserve(bytes, limit: bytes)
        XCTAssertTrue(returned)
        if returned { ClarityScratchBudget.shared.release(bytes) }
    }

    func testClaritySubmitsOnceAndConcurrentOutputsKeepIndependentSurfaces() throws {
        let input = try NeighborhoodTestImage(width: 67, height: 65, format: .rgba32Float)
        let expected = reference(input.values, width: 67, height: 65, radius: 0.12, intensity: 1)
        let old = HarbethContext.shared.enablePerformanceMonitor
        HarbethContext.shared.enablePerformanceMonitor = true
        defer { HarbethContext.shared.enablePerformanceMonitor = old }
        let monitor = HarbethContext.shared.performanceMonitor
        let before = monitor.gpuWorkSnapshot().commandBufferCount
        let output: MTLTexture = try HarbethIO(element: input.texture, filter: C7Clarity()).output()
        XCTAssertEqual(monitor.gpuWorkSnapshot().commandBufferCount - before, 1)
        input.assertPixels(try NeighborhoodTestImage.read(output), expected)
        let transfer = HarbethUncheckedTransfer(value: input)
        DispatchQueue.concurrentPerform(iterations: 8) { _ in
            do {
                let output: MTLTexture = try HarbethIO(element: transfer.value.texture, filter: C7Clarity()).output()
                transfer.value.assertPixels(try NeighborhoodTestImage.read(output), expected)
            } catch { XCTFail("并发 Clarity 失败：\(error)") }
        }
    }

    private func encode(_ source: MTLTexture, filter: C7Clarity, budget: Int) throws -> MTLTexture {
        let d = source.c7.descriptor
        d.storageMode = .shared
        let output = try XCTUnwrap(source.device.makeTexture(descriptor: d))
        let command = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
        defer { HarbethContext.shared.recycleCommandBuffer(command) }
        let context = try MetalCommandEncodingContext(commandBuffer: command, textures: [output, source])
        _ = try filter.encode(context: context, maximumTemporaryBytes: budget)
        try command.commitAndWaitUntilCompleted(identifier: "ClarityRegression")
        return output
    }

    // 独立 Double 高斯，逐轴排除边界外样本；等价于旧二维可分离权重的归一化。
    private func reference(_ input: [Float], width: Int, height: Int, radius: Float, intensity: Float) -> [Float] {
        let sigma = Double(radius * 10), r = Int(ceil((radius * 10) * 10))
        let weights = (-r...r).map { exp(-Double($0 * $0) / (2 * sigma * sigma)) }
        var horizontal = [Double](repeating: 0, count: input.count), result = input
        for y in 0..<height { for x in 0..<width {
            var total: Double = 0
            for dx in -r...r where (0..<width).contains(x + dx) {
                let w = weights[dx + r]; total += w
                for c in 0..<3 { horizontal[(y * width + x) * 4 + c] += Double(input[(y * width + x + dx) * 4 + c]) * w }
            }
            for c in 0..<3 { horizontal[(y * width + x) * 4 + c] /= total }
        } }
        for y in 0..<height { for x in 0..<width {
            var total: Double = 0, blur = [Double](repeating: 0, count: 3)
            for dy in -r...r where (0..<height).contains(y + dy) {
                let w = weights[dy + r]; total += w
                for c in 0..<3 { blur[c] += horizontal[((y + dy) * width + x) * 4 + c] * w }
            }
            let i = (y * width + x) * 4
            for c in 0..<3 { result[i + c] = Float(Double(input[i + c]) + (Double(input[i + c]) - blur[c] / total) * Double(intensity)) }
        } }
        return result
    }
}

private final class RejectClarityScratchAllocator: TexturePoolAllocator {
    var rejectedCount = 0
    override func makeTexture(descriptor: MTLTextureDescriptor, device: MTLDevice) -> MTLTexture? {
        if descriptor.pixelFormat == .rgba32Float && descriptor.storageMode == .private {
            rejectedCount += 1
            return nil
        }
        return super.makeTexture(descriptor: descriptor, device: device)
    }
}
