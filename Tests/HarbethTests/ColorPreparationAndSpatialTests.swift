// 由 Condy 创建于 2026/11/17。参数快照与空间合同的离线验收。
import XCTest
import Metal
@testable import Harbeth

final class ColorPreparationAndSpatialTests: XCTestCase {
    func testScalarEncodingSnapshotsWholeArrayOnceAndNextRequestSeesUpdates() throws {
        let source = try ColorMathPixels.make(width: 1, height: 1, values: [0.1, 0.2, 0.3, 1], format: .rgba32Float)
        for count in [1, 4, 20] {
            let state = ParameterCounter(), filter = CountedScalar(count: count, state: state)
            let destination = try ColorMathPixels.make(width: 1, height: 1, values: [0, 0, 0, 0], format: .rgba32Float)
            let command = try XCTUnwrap(HarbethContext.shared.device.makeCommandQueue()?.makeCommandBuffer())
            _ = try filter.encode(input: source, destination: destination, commandBuffer: command)
            command.commit(); command.waitUntilCompleted()
            XCTAssertEqual(state.scalarReads, 2, "描述与实际编码各读取一次，不按每个下标重建")
            state.value = 0.25
            let next: MTLTexture = try HarbethIO(element: source, filter: filter).output()
            XCTAssertEqual(try ColorMathPixels.read(next)[0], 0.35, accuracy: 0.00001)
        }
    }

    func testVectorEncodingReusesCurrentDescriptorBindings() throws {
        let state = ParameterCounter(), filter = CountedVector(state: state)
        let source = try ColorMathPixels.make(width: 1, height: 1, values: [0.5, 0.5, 0.5, 1], format: .rgba16Float)
        let destination = try ColorMathPixels.make(width: 1, height: 1, values: [0, 0, 0, 0], format: .rgba16Float)
        let command = try XCTUnwrap(HarbethContext.shared.device.makeCommandQueue()?.makeCommandBuffer())
        _ = try filter.encode(input: source, destination: destination, commandBuffer: command)
        command.commit(); command.waitUntilCompleted()
        XCTAssertEqual(state.bindingReads, 1)
        state.value = 0.25
        let changed: MTLTexture = try HarbethIO(element: source, filter: filter).output()
        XCTAssertEqual(try ColorMathPixels.read(changed)[0], 1.0 / 3, accuracy: 0.001)
    }

    func testWarpContractsRejectOrdinaryTileAndPointwiseFusion() {
        for f: any C7FilterProtocol in [C7Swirl(), C7Bulge(), C7Pinch(), C7GlassSphere()] {
            XCTAssertEqual(f.samplingFootprint, .global)
            XCTAssertEqual(f.kernelPixelContract.coordinateDependency, .fullImage)
            XCTAssertEqual(f.kernelPixelContract.globalDependency, .imageDimensions)
            XCTAssertFalse(f.kernelPixelContract.canAutoTile)
            XCTAssertFalse(f.kernelPixelContract.isPointwiseFusionEligible)
        }
    }

    func testWarpRegionsWithFullSourceMatchFullImageCrops() throws {
        let source = try ColorMathPixels.fixture(width: 17, height: 13, format: .rgba16Float)
        let extent = CGRect(x: 0, y: 0, width: 17, height: 13)
        for roi in [CGRect(x: 4, y: 3, width: 8, height: 7), CGRect(x: 0, y: 0, width: 5, height: 3)] {
            let context = try TextureMappingContext(inputLogicalExtent: extent, inputRegion: extent, outputLogicalExtent: extent, outputRegion: roi)
            for f: any C7FilterProtocol in [C7Swirl(), C7Bulge(scale: -1), C7Pinch(), C7GlassSphere()] {
                let full: MTLTexture = try HarbethIO(element: source, filter: f).output()
                let output = try encode(RegionWarp(base: f, context: context), source: source, width: Int(roi.width), height: Int(roi.height))
                let values = try ColorMathPixels.read(full)
                var expected: [Float] = []
                for y in Int(roi.minY)..<Int(roi.maxY) { for x in Int(roi.minX)..<Int(roi.maxX) { let i = (y * 17 + x) * 4; expected += values[i..<i + 4] } }
                XCTAssertEqual(try ColorMathPixels.read(output), expected)
            }
        }
    }

    func testBulgeZeroScaleUsesInputLogicalSizeWhenOutputDiffers() throws {
        let source = try ColorMathPixels.fixture(width: 16, height: 16, format: .rgba16Float)
        let context = try TextureMappingContext(inputLogicalExtent: CGRect(x: 0, y: 0, width: 16, height: 16), inputRegion: CGRect(x: 0, y: 0, width: 16, height: 16),
            outputLogicalExtent: CGRect(x: 0, y: 0, width: 32, height: 24), outputRegion: CGRect(x: 0, y: 0, width: 32, height: 24))
        let output = try encode(RegionWarp(base: C7Bulge(scale: 0), context: context), source: source, width: 32, height: 24)
        let original = try ColorMathPixels.read(source)
        var expected: [Float] = []
        for y in 0..<24 { for x in 0..<32 { let i = (Int(Float(y) / 24 * 16) * 16 + Int(Float(x) / 32 * 16)) * 4; expected += original[i..<i + 4] } }
        XCTAssertEqual(try ColorMathPixels.read(output), expected)
    }

    private func encode(_ filter: any C7FilterProtocol, source: MTLTexture, width: Int, height: Int) throws -> MTLTexture {
        let output = try ColorMathPixels.make(width: width, height: height, values: [Float](repeating: 0, count: width * height * 4), format: .rgba16Float)
        let command = try XCTUnwrap(HarbethContext.shared.device.makeCommandQueue()?.makeCommandBuffer())
        _ = try filter.encode(input: source, destination: output, commandBuffer: command)
        command.commit(); command.waitUntilCompleted()
        XCTAssertEqual(command.status, .completed)
        return output
    }
}

private final class ParameterCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var scalar = 0, binding = 0, current: Float = 0
    var scalarReads: Int { lock.lock(); defer { lock.unlock() }; return scalar }
    var bindingReads: Int { lock.lock(); defer { lock.unlock() }; return binding }
    var value: Float { get { lock.lock(); defer { lock.unlock() }; return current } set { lock.lock(); current = newValue; lock.unlock() } }
    func readScalar() -> Float { lock.lock(); defer { lock.unlock() }; scalar += 1; return current }
    func readBinding() -> Float { lock.lock(); defer { lock.unlock() }; binding += 1; return current }
}
private struct CountedScalar: C7FilterProtocol {
    let count: Int
    let state: ParameterCounter
    var modifier: ModifierEnum { .compute(kernel: "C7Brightness") }
    var factors: [Float] { let value = state.readScalar(); return [Float](repeating: value, count: count) }
}
private struct CountedVector: C7FilterProtocol {
    let state: ParameterCounter
    var modifier: ModifierEnum { .compute(kernel: "C7LevelsAdjustment") }
    var kernelParameterBindings: [KernelParameterBinding] { C7LevelsAdjustment(inputBlack: .init(repeating: state.readBinding())).kernelParameterBindings }
}
private struct RegionWarp: C7FilterProtocol {
    let base: any C7FilterProtocol
    let context: TextureMappingContext
    var modifier: ModifierEnum { base.modifier }
    var factors: [Float] { base.factors }
    var kernelParameterBindings: [KernelParameterBinding] {
        factors.enumerated().map { .init(name: "factor\($0.offset)", index: $0.offset, stage: .compute, value: .float($0.element)) }
        + [.init(name: "region", index: 30, stage: .compute, value: .floatArray(context.kernelValues))]
    }
}
