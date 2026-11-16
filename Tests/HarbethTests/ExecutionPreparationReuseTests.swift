//
//  ExecutionPreparationReuseTests.swift
//  HarbethTests
//
//  由 Condy 创建于 2026/11/16。
//

import XCTest
import Metal
@testable import Harbeth

final class ExecutionPreparationReuseTests: XCTestCase {
    func testStartRenderFrameTaskUsesPreparedDiagnostics() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil)
        let texture = try makeTexture()
        let node = ImageNode.texture(texture).applying(C7Brightness(brightness: 0.1))
        let task = try node.startRenderFrameTask(profile: .stablePreview)
        _ = try task.output()
        XCTAssertNotNil(task.diagnostics)
    }

    func testStartRenderFrameTaskKeepsDerivativeAndFrameDiagnosticsAligned() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil)
        let texture = try makeTexture()
        let baseDerivative = RenderProfile.stablePreview.defaultDerivativeSpec
        let derivative = ImageDerivativeSpec(name: "testExact", renderIntent: baseDerivative.renderIntent, sourceTier: baseDerivative.sourceTier, semantic: baseDerivative.semantic, outputSizePolicy: .exact(C7Size(width: 1, height: 1)))
        let node = ImageNode.texture(texture).applying(C7Brightness(brightness: 0.1))
        let task = try node.startRenderFrameTask(profile: .stablePreview, derivative: derivative)
        let frame = try task.output()
        XCTAssertEqual(frame.texture.width, 1)
        XCTAssertEqual(frame.texture.height, 1)
        XCTAssertEqual(task.diagnostics?.outputSize, C7Size(width: 1, height: 1))
    }

    func testRenderProgramSourceFingerprintMatchesExecutionGuard() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil)
        let texture = try makeTexture()
        let filter = C7Brightness(brightness: 0.1)
        let io = HarbethIO(element: texture, filter: filter)
        let program = io.makeRenderProgram(input: texture)
        XCTAssertEqual(program.sourceFilterFingerprint, [filter].chainRecipe.fingerprint)
        XCTAssertNoThrow(try io.executeRenderProgram(input: texture, program: program))
    }

    @available(macOS 12.0, *)
    func testMakeFrameAsyncRemainsAsyncEntryPoint() async throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil)
        let node = ImageNode.texture(try makeTexture()).applying(C7Brightness(brightness: 0.1))
        let frame = try await node.makeFrameAsync()
        XCTAssertGreaterThan(frame.texture.width, 0)
    }

    func testColorResolutionReadsContractsWithoutConstructingKernels() throws {
        let counter = PreparationReadCounter()
        let p3 = ContractColorFilter(color: .displayP3, counter: counter)
        let inherited = ContractColorFilter(color: .preserveInput, counter: counter)
        let io = HarbethIO(element: try makeTexture(), filters: [p3, inherited])
        XCTAssertEqual(io.resolvedOutputColorSpace(inputSize: C7Size(width: 2, height: 2)), .displayP3)
        XCTAssertEqual(counter.value, 0)
        XCTAssertEqual(io.resolvedOutputColorSpace(inputSize: C7Size(width: 2, height: 2), outputColorSpace: .sRGB), .sRGB)
        XCTAssertEqual(counter.value, 0)
        let chain = ContractColorPipeline(final: p3)
        let pipelineIO = HarbethIO(element: try makeTexture(), filters: [chain, inherited])
        XCTAssertEqual(pipelineIO.resolvedOutputColorSpace(inputSize: C7Size(width: 2, height: 2)), .displayP3)
    }

    func testColorResolutionPreservesRenderProtocolContract() throws {
        let counter = PreparationReadCounter()
        let inherited = ContractColorFilter(color: .preserveInput, counter: counter)
        let io = HarbethIO(element: try makeTexture(), filters: [RenderColorFilter(), inherited])
        XCTAssertEqual(io.resolvedOutputColorSpace(inputSize: C7Size(width: 2, height: 2)), .displayP3)
        let frame = try io.makeFrame()
        XCTAssertEqual(frame.colorSpace?.name as String?, CGColorSpace.displayP3 as String)
        let compute = HarbethIO(element: try makeTexture(), filter: ComputeColorFilter())
        XCTAssertEqual(compute.resolvedOutputColorSpace(inputSize: C7Size(width: 2, height: 2)), .sRGB)
    }

    func testSizePreparationMutationKeepsCompiledFingerprintCurrent() throws {
        let source = try makeTexture()
        let filter = SizePreparedBrightness()
        let io = HarbethIO(element: source, filter: filter)
        let program = io.makeRenderProgram(input: source)
        XCTAssertGreaterThan(filter.preparationCount, 1)
        XCTAssertEqual(program.sourceFilterFingerprint, [filter].chainRecipe.fingerprint)
        XCTAssertNoThrow(try io.executeRenderProgram(input: source, program: program))
    }

    func testMutableFilterInvalidatesCachedProgramAndOldExecutionGuard() throws {
        let source = try makeTexture()
        let filter = MutablePreparationBrightness()
        let io = HarbethIO(element: source, filter: filter).replacingInput(with: source)
        let old = io.makeRenderProgram(input: source)
        filter.brightness = 0.4
        XCTAssertThrowsError(try io.executeRenderProgram(input: source, program: old))
        let next = io.replacingInput(with: source).makeRenderProgram(input: source)
        XCTAssertNotEqual(old.sourceFilterFingerprint, next.sourceFilterFingerprint)
        XCTAssertNoThrow(try io.executeRenderProgram(input: source, program: next))
    }

    func testProvidedSourceFingerprintAvoidsOneRepeatedRead() throws {
        let source = try makeTexture()
        let filter = MutablePreparationBrightness()
        let fingerprint = [filter].chainRecipe.fingerprint
        filter.counter.value = 0
        _ = RenderExecutionCompiler.compile(filters: [filter], inputSize: C7Size(texture: source), sourceFilterFingerprint: fingerprint)
        let preparedReads = filter.counter.value
        filter.counter.value = 0
        _ = RenderExecutionCompiler.compile(filters: [filter], inputSize: C7Size(texture: source))
        XCTAssertGreaterThan(filter.counter.value, preparedReads)
    }

    private func makeTexture() throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 2, height: 2, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(MTLCreateSystemDefaultDevice()?.makeTexture(descriptor: descriptor))
        let pixels = [UInt8](repeating: 128, count: 16)
        TextureLoader.replaceTexture(texture, region: MTLRegionMake2D(0, 0, 2, 2), bytes: pixels, packedBytesPerRow: 8)
        return texture
    }
}

private final class PreparationReadCounter { var value = 0 }
private final class MutablePreparationBrightness: C7FilterProtocol {
    var brightness: Float = 0.1
    let counter = PreparationReadCounter()
    var modifier: ModifierEnum { .compute(kernel: "C7Brightness") }
    var factors: [Float] { counter.value += 1; return [brightness] }
}
private final class SizePreparedBrightness: C7FilterProtocol {
    var preparationCount = 0
    var modifier: ModifierEnum { .compute(kernel: "C7Brightness") }
    var factors: [Float] { [Float(preparationCount) / 100] }
    func resize(input: C7Size) -> C7Size {
        preparationCount += 1
        return input
    }
}
private struct RenderColorFilter: RenderProtocol {
    var modifier: ModifierEnum { .render(vertex: "basicVertex", fragment: "basicFragment") }
    var renderSamplerConsumption: RenderSamplerConsumption { .runtimeBound }
    var renderOutputContract: RenderOutputContract { RenderOutputContract(colorSpace: .displayP3) }
}
private struct ComputeColorFilter: RenderProtocol {
    var modifier: ModifierEnum { .compute(kernel: "C7Brightness") }
    var factors: [Float] { [0] }
    var renderSamplerConsumption: RenderSamplerConsumption { .runtimeBound }
    var renderOutputContract: RenderOutputContract { RenderOutputContract(colorSpace: .displayP3) }
    var kernelOutputContract: RenderOutputContract { RenderOutputContract(colorSpace: .sRGB) }
}
private struct ContractColorFilter: C7FilterProtocol {
    let color: ImageColorSpaceContract
    let counter: PreparationReadCounter
    var modifier: ModifierEnum { counter.value += 1; return .compute(kernel: "C7Brightness") }
    var factors: [Float] { [0] }
    var kernelOutputContract: RenderOutputContract { RenderOutputContract(colorSpace: color) }
}
private struct ContractColorPipeline: C7FilterPipelineProtocol {
    let final: ContractColorFilter
    var pipelineFilters: [C7FilterProtocol] { [] }
    func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? { final }
}
