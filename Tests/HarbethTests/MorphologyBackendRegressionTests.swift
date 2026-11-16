import MetalPerformanceShaders
// 由 Condy 创建于 2026/11/16。
import XCTest

@testable import Harbeth

final class MorphologyBackendRegressionTests: XCTestCase {
    func testSmallKernelsMatchIndependentRectangularMinMax() throws {
        for format in NeighborhoodTestImage.formats {
            let input = try NeighborhoodTestImage(width: 17, height: 13, format: format)
            for size: Float in [1, 2, 5, 9] {
                for erosion in [true, false] {
                    let filter = C7Morphology(operation: erosion ? .erosion : .dilation, kernelSize: size)
                    let output: MTLTexture = try HarbethIO(element: input.texture, filter: filter).output()
                    let actual = try NeighborhoodTestImage.read(output)
                    let r = filter.normalizedKernelSize / 2
                    for (x, y) in [(0, 0), (16, 0), (0, 12), (16, 12), (8, 6)] {
                        for c in 0..<4 {
                            var value = Float(Float16(input.values[(y * 17 + x) * 4 + c]))
                            for dy in -r...r {
                                for dx in -r...r where (0..<17).contains(x + dx) && (0..<13).contains(y + dy) {
                                    let sample = Float(Float16(input.values[((y + dy) * 17 + x + dx) * 4 + c]))
                                    value = erosion ? min(value, sample) : max(value, sample)
                                }
                            }
                            let expected = format == .rgba8Unorm ? (min(max(value, 0), 1) * 255).rounded() / 255 : value
                            XCTAssertEqual(
                                actual[(y * 17 + x) * 4 + c], expected, accuracy: format == .rgba8Unorm ? 1.0 / 255 : 0)
                        }
                    }
                }
            }
        }
    }

    func testLargeMPSAndBudgetFallbackAreBitIdenticalForEligibleFormats() throws {
        try XCTSkipUnless(MPSSupportsMTLDevice(try XCTUnwrap(MTLCreateSystemDefaultDevice())))
        for format in [MTLPixelFormat.rgba8Unorm, .rgba16Float] {
            let input = try NeighborhoodTestImage(width: 512, height: 512, format: format)
            for size: Float in [7, 9] {
                for erosion in [true, false] {
                    let filter = C7Morphology(operation: erosion ? .erosion : .dilation, kernelSize: size)
                    let fast = try encode(filter, input: input.texture, budget: 16 * 1024 * 1024)
                    let direct = try encode(filter, input: input.texture, budget: 0)
                    XCTAssertEqual(
                        fast.c7.rawBytes(maximumBytes: 512 * 512 * 16), direct.c7.rawBytes(maximumBytes: 512 * 512 * 16)
                    )
                }
            }
        }
    }

    func testFloat32RetainsLegacyHalfQuantizationAndAvoidsBackendSwitch() throws {
        let input = try NeighborhoodTestImage(width: 512, height: 512, format: .rgba32Float, constant: 0.1234567)
        let filter = C7Morphology(operation: .erosion, kernelSize: 9)
        let output = try encode(filter, input: input.texture, budget: 16 * 1024 * 1024)
        XCTAssertEqual(try NeighborhoodTestImage.read(output)[0], Float(Float16(0.1234567)))
    }

    func testBGRAStorageRetainsAllFourChannels() throws {
        let input = try NeighborhoodTestImage(width: 512, height: 512, format: .rgba8Unorm)
        let d = input.texture.c7.descriptor
        d.pixelFormat = .bgra8Unorm
        let texture = try XCTUnwrap(input.texture.device.makeTexture(descriptor: d))
        let data = try XCTUnwrap(input.texture.c7.rawBytes(maximumBytes: 512 * 512 * 4))
        data.withUnsafeBytes {
            texture.replace(
                region: MTLRegionMake2D(0, 0, 512, 512), mipmapLevel: 0, withBytes: $0.baseAddress!,
                bytesPerRow: 512 * 4)
        }
        for operation in [C7Morphology.OperationType.erosion, .dilation] {
            let filter = C7Morphology(operation: operation, kernelSize: 9)
            let fast = try encode(filter, input: texture, budget: 16 * 1024 * 1024)
            let direct = try encode(filter, input: texture, budget: 0)
            XCTAssertEqual(
                fast.c7.rawBytes(maximumBytes: 512 * 512 * 4), direct.c7.rawBytes(maximumBytes: 512 * 512 * 4))
        }
    }

    func testUnsubmittedMPSBufferReturnsQuotaAfterCacheInvalidation() throws {
        let input = try NeighborhoodTestImage(width: 512, height: 512, format: .rgba16Float)
        let runtime = HarbethContext.shared
        let bytes = 512 * 512 * 16
        try autoreleasepool {
            let command = try XCTUnwrap(runtime.commandQueue.makeCommandBuffer())
            let output = try XCTUnwrap(input.texture.device.makeTexture(descriptor: input.texture.c7.descriptor))
            let context = try MetalCommandEncodingContext(commandBuffer: command, textures: [output, input.texture])
            _ = try C7Morphology(operation: .erosion, kernelSize: 9).encode(
                context: context, maximumTemporaryBytes: bytes)
            runtime.invalidateDerivedResources(domain: .mask, namespace: "harbeth.morphology.kernel")
            XCTAssertFalse(runtime.morphologyScratchBudget.reserve(1, limit: bytes))
        }
        let returned = runtime.morphologyScratchBudget.reserve(bytes, limit: bytes)
        XCTAssertTrue(returned)
        if returned { runtime.morphologyScratchBudget.release(bytes) }
    }

    func testBudgetSelectionAndInternalResourceAdmission() throws {
        XCTAssertFalse(C7Morphology.prefersMPS(width: 17, height: 13, kernelSize: 9, maximumTemporaryBytes: Int.max))
        XCTAssertFalse(C7Morphology.prefersMPS(width: 512, height: 512, kernelSize: 3, maximumTemporaryBytes: Int.max))
        XCTAssertFalse(C7Morphology.prefersMPS(width: 512, height: 512, kernelSize: 9, maximumTemporaryBytes: 0))
        XCTAssertTrue(
            C7Morphology.prefersMPS(width: 512, height: 512, kernelSize: 9, maximumTemporaryBytes: 16 * 1024 * 1024))
        let input = try NeighborhoodTestImage(width: 512, height: 512, format: .rgba16Float)
        let request = try ImageNode.texture(input.texture).applying(C7Morphology(operation: .dilation, kernelSize: 9))
            .makeRenderRequest()
        XCTAssertGreaterThanOrEqual(request.resourceEstimate.transientBytes, 512 * 512 * 16)
        XCTAssertFalse(request.withResourceBudget(.init(maximumTransientBytes: 0)).resourceAdmission.isAccepted)
        let budget = MorphologyScratchBudget()
        XCTAssertTrue(budget.reserve(32, limit: 64))
        XCTAssertTrue(budget.reserve(32, limit: 64))
        budget.purge()
        XCTAssertFalse(budget.reserve(1, limit: 64))
        budget.release(32)
        budget.release(32)
        XCTAssertTrue(budget.reserve(64, limit: 64))
        budget.release(64)
    }

    func testConcurrentRequestsAndCacheInvalidationKeepOutputStable() throws {
        let input = try NeighborhoodTestImage(width: 512, height: 512, format: .rgba16Float)
        let filter = C7Morphology(operation: .dilation, kernelSize: 9)
        let expected = try encode(filter, input: input.texture, budget: 0).c7.rawBytes(maximumBytes: 512 * 512 * 8)
        let transfer = HarbethUncheckedTransfer(value: input.texture)
        DispatchQueue.concurrentPerform(iterations: 8) { i in
            do {
                if i == 3 {
                    HarbethContext.shared.invalidateDerivedResources(
                        domain: .mask, namespace: "harbeth.morphology.kernel")
                }
                let output: MTLTexture = try HarbethIO(element: transfer.value, filter: filter).output()
                XCTAssertEqual(output.c7.rawBytes(maximumBytes: 512 * 512 * 8), expected)
            } catch { XCTFail("并发形态学失败：\(error)") }
        }
    }

    private func encode(_ filter: C7Morphology, input: MTLTexture, budget: Int) throws -> MTLTexture {
        let output = try XCTUnwrap(input.device.makeTexture(descriptor: input.c7.descriptor))
        let command = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
        defer { HarbethContext.shared.recycleCommandBuffer(command) }
        let context = try MetalCommandEncodingContext(commandBuffer: command, textures: [output, input])
        _ = try filter.encode(context: context, maximumTemporaryBytes: budget)
        try command.commitAndWaitUntilCompleted(identifier: "MorphologyRegression")
        return output
    }
}
