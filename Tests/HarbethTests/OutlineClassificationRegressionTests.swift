// 由 Condy 创建于 2026/11/17。保留完整搜索作为独立执行参考。
import XCTest
import Metal
@testable import Harbeth

final class OutlineClassificationRegressionTests: XCTestCase {
    func testAdmittedShapesAndTemporaryResourceEstimatesAreBounded() {
        let limit = 4 * 1024 * 1024
        XCTAssertNil(OutlineFlatClassification.requirement(width: 256, height: 256, thickness: 0.04, limit: limit))
        XCTAssertNil(OutlineFlatClassification.requirement(width: 512, height: 512, thickness: 0, limit: limit))
        XCTAssertNil(OutlineFlatClassification.requirement(width: 512, height: 512, thickness: .nan, limit: limit))
        XCTAssertNil(OutlineFlatClassification.requirement(width: 512, height: 512, thickness: 0.04, limit: 1))
        XCTAssertNil(OutlineFlatClassification.requirement(width: 4096, height: 4096, thickness: 0.02, limit: limit))
        XCTAssertEqual(OutlineFlatClassification.requirement(width: 512, height: 512, thickness: 0.02, limit: limit)?.bytes, 4096)
        XCTAssertEqual(C7StickerOutline().temporaryTextureRequirement(inputSize: .init(width: 512, height: 512)).bytes, 4096)
    }

    func testFlatClassifiedOutputIsBitIdenticalToDirectAcrossContentAndPartialGroups() throws {
        for (w, h) in [(512, 512), (513, 517)] { for kind in 0..<6 {
            try autoreleasepool {
                let source = try fixture(width: w, height: h, kind: kind)
                for (thickness, blur): (Float, Float) in [(0.02, 0.1), (0.04, 0), (0.02, 1)] {
                    let f = C7StickerOutline(outlineThickness: thickness, outlineBlur: blur)
                    let expected: MTLTexture = try HarbethIO(element: source, filter: DirectOutline(base: f)).output()
                    let actual: MTLTexture = try HarbethIO(element: source, filter: f).output()
                    XCTAssertEqual(actual.c7.rawBytes(maximumBytes: w * h * 8), expected.c7.rawBytes(maximumBytes: w * h * 8), "内容 \(kind)、尺寸 \(w)×\(h)、厚度 \(thickness)、模糊 \(blur)")
                }
            }
        } }
    }

    func testFloat32AndSmallShapesPreserveDirectFallback() throws {
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] { for n in [1, 17] {
            let source = try ColorMathPixels.fixture(width: n, height: n, format: format)
            for thickness: Float in [0, 0.02] {
                let f = C7StickerOutline(outlineThickness: thickness)
                let a: MTLTexture = try HarbethIO(element: source, filter: f).output()
                let b: MTLTexture = try HarbethIO(element: source, filter: DirectOutline(base: f)).output()
                XCTAssertEqual(a.c7.rawBytes(maximumBytes: n * n * 16), b.c7.rawBytes(maximumBytes: n * n * 16))
            }
        } }
        let source = try ColorMathPixels.fixture(width: 512, height: 512, format: .rgba32Float)
        let command = try XCTUnwrap(HarbethContext.shared.device.makeCommandQueue()?.makeCommandBuffer())
        let output = try ColorMathPixels.make(width: 512, height: 512, values: [Float](repeating: 0, count: 512 * 512 * 4), format: .rgba32Float)
        XCTAssertNil(try encode(C7StickerOutline(), source: source, destination: output, command: command, limit: 1024 * 1024))
    }

    func testUnsubmittedAndInFlightLeasesKeepIndependentFlagsUntilCompletion() throws {
        let runtime = HarbethContext.shared, budget = runtime.outlineClassificationBudget, initial = budget.usedBytes
        let source = try fixture(width: 512, height: 512, kind: 1)
        let queue = try XCTUnwrap(runtime.device.makeCommandQueue())
        try autoreleasepool {
            let command = try XCTUnwrap(queue.makeCommandBuffer()), output = try empty(512, 512)
            XCTAssertNotNil(try encode(C7StickerOutline(), source: source, destination: output, command: command, limit: 1024 * 1024))
            XCTAssertEqual(budget.usedBytes, initial + 4096)
            budget.purge(); XCTAssertEqual(budget.usedBytes, initial + 4096)
        }
        XCTAssertEqual(budget.usedBytes, initial)
        var commands: [MTLCommandBuffer] = [], outputs: [MTLTexture] = []
        let complete = expectation(description: "分类表归还")
        complete.expectedFulfillmentCount = 3
        for kind in 0..<3 {
            let command = try XCTUnwrap(queue.makeCommandBuffer()), output = try empty(512, 512)
            let source = try fixture(width: 512, height: 512, kind: kind)
            XCTAssertNotNil(try encode(C7StickerOutline(), source: source, destination: output, command: command, limit: 1024 * 1024))
            command.addCompletedHandler { _ in complete.fulfill() }
            commands.append(command); outputs.append(output)
        }
        XCTAssertEqual(budget.usedBytes, initial + 3 * 4096)
        for command in commands { command.commit() }
        wait(for: [complete], timeout: 10)
        for command in commands { command.waitUntilCompleted(); XCTAssertEqual(command.status, .completed) }
        for kind in 0..<3 {
            let expected: MTLTexture = try HarbethIO(element: fixture(width: 512, height: 512, kind: kind), filter: DirectOutline(base: C7StickerOutline())).output()
            XCTAssertEqual(outputs[kind].c7.rawBytes(maximumBytes: 512 * 512 * 8), expected.c7.rawBytes(maximumBytes: 512 * 512 * 8))
        }
        XCTAssertEqual(budget.usedBytes, initial)
    }

    func testZeroBudgetAndConcurrentExhaustionFallBackWithoutLeaking() throws {
        let runtime = HarbethContext.shared, budget = runtime.outlineClassificationBudget
        let source = try fixture(width: 512, height: 512, kind: 1), output = try empty(512, 512)
        let queue = try XCTUnwrap(runtime.device.makeCommandQueue())
        XCTAssertNil(try encode(C7StickerOutline(), source: source, destination: output, command: XCTUnwrap(queue.makeCommandBuffer()), limit: 0))
        XCTAssertTrue(budget.reserve(4096, limit: 4096))
        defer { budget.release(4096) }
        XCTAssertNil(try encode(C7StickerOutline(), source: source, destination: output, command: XCTUnwrap(queue.makeCommandBuffer()), limit: 4096))
        XCTAssertEqual(budget.usedBytes, 4096)
    }

    func testAllocationFailureReleasesReservationBeforeDirectFallback() throws {
        let runtime = HarbethContext.shared, original = runtime.textureAllocator
        let source = try fixture(width: 512, height: 512, kind: 1), output = try empty(512, 512)
        let command = try XCTUnwrap(runtime.device.makeCommandQueue()?.makeCommandBuffer()), initial = runtime.outlineClassificationBudget.usedBytes
        runtime.textureAllocator = FailedOutlineAllocator(texturePool: runtime.texturePool, strategy: .exact)
        defer { runtime.textureAllocator = original }
        XCTAssertNil(try encode(C7StickerOutline(), source: source, destination: output, command: command, limit: 1024 * 1024))
        XCTAssertEqual(runtime.outlineClassificationBudget.usedBytes, initial)
    }

    func testAsyncFrameAndCancelledRequestKeepSourceAndReleaseResources() async throws {
        let source = try fixture(width: 512, height: 512, kind: 1)
        let before = source.c7.rawBytes(maximumBytes: 512 * 512 * 8)
        let node = ImageNode.texture(source).applying(C7StickerOutline())
        _ = try await node.makeFrameAsync()
        XCTAssertEqual(source.c7.rawBytes(maximumBytes: 512 * 512 * 8), before)
        let transfer = HarbethUncheckedTransfer(value: source)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await ImageNode.texture(transfer.value).applying(C7StickerOutline()).makeFrameAsync()
        }
        do { _ = try await task.value; XCTFail("取消请求应失败") } catch { }
        XCTAssertEqual(source.c7.rawBytes(maximumBytes: 512 * 512 * 8), before)
    }

    private func fixture(width: Int, height: Int, kind: Int) throws -> MTLTexture {
        var values = [Float](repeating: 1, count: width * height * 4)
        for y in 0..<height { for x in 0..<width {
            let i = (y * width + x) * 4
            let alpha: Float = kind == 4 ? ((x + y) % 7 == 0 ? 0 : (x + y) % 7 == 1 ? 0.05 : 1) : 1
            for c in 0..<3 {
                let v: Float = kind == 0 ? Float((x + y) % 2) : kind == 1 ? 0.1 : kind == 2 ? Float((i + c) * 17 % 251) / 250 : kind == 3 ? 0.3 + 0.1 * Float((x + y) % 17) / 16 : kind == 4 ? 0.1 : 60000
                values[i + c] = v * alpha
            }
            values[i + 3] = alpha
        } }
        return try ColorMathPixels.make(width: width, height: height, values: values, format: .rgba16Float)
    }
    private func empty(_ width: Int, _ height: Int) throws -> MTLTexture { try ColorMathPixels.make(width: width, height: height, values: [Float](repeating: 0, count: width * height * 4), format: .rgba16Float) }
    private func encode(_ f: C7StickerOutline, source: MTLTexture, destination: MTLTexture, command: MTLCommandBuffer, limit: Int) throws -> MTLTexture? {
        let descriptor = f.kernelDescriptor()
        let identity = KernelFunctionIdentity(kind: .compute, primaryName: "C7StickerOutline", functionConstants: [.init(name: "stickerUsesSIMDGroup", index: 0, value: .bool(true))])
        return try OutlineFlatClassification.encode(commandBuffer: command, textures: [destination, source], descriptor: descriptor, identity: identity, maximumTemporaryBytes: limit)
    }
}

private struct DirectOutline: C7FilterProtocol {
    let base: C7StickerOutline
    var modifier: ModifierEnum { base.modifier }
    var kernelParameterBindings: [KernelParameterBinding] { base.kernelParameterBindings }
    var computeKernelFunctionConstants: [KernelFunctionConstantDescriptor] { [.init(name: "stickerUsesSIMDGroup", index: 0, value: .bool(true))] }
}
private final class FailedOutlineAllocator: TexturePoolAllocator {
    override func dequeueTexture(matching descriptor: MTLTextureDescriptor, allowsSizeTolerance: Bool) -> MTLTexture? { nil }
    override func dequeueTextureLease(matching descriptor: MTLTextureDescriptor, allowsSizeTolerance: Bool, logicalExtent: C7Size?) -> TextureLease? { nil }
    override func makeTexture(descriptor: MTLTextureDescriptor, device: MTLDevice) -> MTLTexture? { nil }
}
