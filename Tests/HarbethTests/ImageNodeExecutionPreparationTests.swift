//
//  ImageNodeExecutionPreparationTests.swift
//  Harbeth
//
//  Created by Condy on 2026/10/7.
//

import Foundation
import CoreImage
import Metal
import XCTest
@testable import Harbeth

final class ImageNodeExecutionPreparationTests: XCTestCase {
    func testEditFrameEncodesUpstreamOnceWithColdAndWarmPlans() throws {
        let recorder = PreparationEncodingRecorder()
        let node = try makeNode(recorder).editing(EditRecipe())
        HarbethContext.shared.resetCaches()
        for _ in 0..<2 {
            recorder.reset()
            let frame = try node.makeFrame()
            XCTAssertEqual(recorder.encodingCount, 1)
            XCTAssertEqual(Array(try XCTUnwrap(frame.texture.c7.bytes()).prefix(4)), [64, 96, 128, 255])
        }
    }

    func testRequestPlanningDoesNotEncodeUpstreamAndEachExecutionEncodesOnce() throws {
        let recorder = PreparationEncodingRecorder()
        let node = try makeNode(recorder).editing(EditRecipe())
        HarbethContext.shared.resetCaches()
        let request = try node.makeRenderRequest()
        XCTAssertEqual(recorder.encodingCount, 0)
        _ = try request.renderTexture()
        XCTAssertEqual(recorder.encodingCount, 1)
        recorder.reset()
        _ = try request.renderFrame()
        XCTAssertEqual(recorder.encodingCount, 1)
    }

    func testChainedAndArrayFiltersUseOneCommandBuffer() throws {
        let recorder = PreparationEncodingRecorder()
        let source = ImageNode.texture(try makeTexture())
        let filter = PreparationCountingFilter(recorder: recorder)
        let chained = source.applying(filter).applying(filter).applying(filter)
        let array = source.applying(filters: [filter, filter, filter])
        for node in [chained, array] {
            for frameOutput in [false, true] {
                recorder.reset()
                let texture = try frameOutput ? node.makeFrame().texture : node.makeTexture()
                XCTAssertEqual(recorder.encodingCount, 3)
                XCTAssertEqual(recorder.commandBufferCount, 1)
                XCTAssertEqual(Array(try XCTUnwrap(texture.c7.bytes()).prefix(4)), [64, 96, 128, 255])
            }
        }
    }

    func testNestedEditingAndSamplerWrappersKeepSingleUpstreamExecution() throws {
        let recorder = PreparationEncodingRecorder()
        let node = try makeNode(recorder)
            .editing(EditRecipe(geometry: ImageTransformRecipe(targetSize: CGSize(width: 3, height: 3), aspectPolicy: .fit)))
            .withSamplerDescriptor(.nearest)
            .editing(EditRecipe())
        HarbethContext.shared.resetCaches()
        let request = try node.makeRenderRequest()
        XCTAssertEqual(recorder.encodingCount, 0)
        let frame = try request.renderFrame()
        XCTAssertEqual(recorder.encodingCount, 1)
        XCTAssertEqual(frame.texture.width, 3)
        XCTAssertEqual(frame.sourceDescriptor, try node.makeRenderRecipe().source)
        XCTAssertEqual(recorder.encodingCount, 1, "生成描述不得再次执行滤镜。")
    }

    func testAsyncEditFrameEncodesUpstreamOnce() async throws {
        let recorder = PreparationEncodingRecorder()
        let node = try makeNode(recorder).editing(EditRecipe())
        HarbethContext.shared.resetCaches()
        let frame = try await node.makeFrameAsync()
        XCTAssertEqual(recorder.encodingCount, 1)
        XCTAssertEqual(Array(try XCTUnwrap(frame.texture.c7.bytes()).prefix(4)), [64, 96, 128, 255])
    }

    func testSourceMaterializationIsSharedOnlyWithinOnePreparation() throws {
        let source = ImageSource.ciImage(CIImage(color: CIColor(red: 1, green: 0, blue: 0))
            .cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4)))
        let preparation = ImageNodeSourcePreparation()
        let first = try preparation.texture(for: source)
        XCTAssertTrue(first === (try preparation.texture(for: source)))
        XCTAssertFalse(first === (try ImageNodeSourcePreparation().texture(for: source)))
    }

    func testLocalEffectMaskIsNotResolvedDuringPlanningAndExecutesOnce() throws {
        let recorder = PreparationEncodingRecorder()
        let mask = try MaskDescriptor(texture: makeTexture())
        let maskCalls = MaskResolutionCounter()
        let effect = try LocalEffectRecipe(filters: [C7Brightness(brightness: 0.1)],
                                          mask: PreparationMaskRecipe(mask: mask, calls: maskCalls))
        let node = try makeNode(recorder).editing(EditRecipe(localEffects: [effect]))
        maskCalls.count = 0
        let request = try node.makeRenderRequest()
        XCTAssertEqual(maskCalls.count, 0)
        XCTAssertEqual(recorder.encodingCount, 0)
        _ = try request.renderFrame()
        XCTAssertEqual(maskCalls.count, 1)
        XCTAssertEqual(recorder.encodingCount, 1)
    }

    private func makeNode(_ recorder: PreparationEncodingRecorder) throws -> ImageNode {
        ImageNode.texture(try makeTexture()).applying(PreparationCountingFilter(recorder: recorder))
    }

    private func makeTexture() throws -> MTLTexture {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice(), "验收需要可用的 Metal 设备。")
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 4, height: 4, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let bytes = Array(repeating: [UInt8](arrayLiteral: 64, 96, 128, 255), count: 16).flatMap { $0 }
        texture.replace(region: MTLRegionMake2D(0, 0, 4, 4), mipmapLevel: 0, withBytes: bytes, bytesPerRow: 16)
        return texture
    }
}

private final class MaskResolutionCounter {
    var count = 0
}

private struct PreparationMaskRecipe: MaskRecipe {
    let mask: MaskDescriptor
    let calls: MaskResolutionCounter
    var profile: RenderProfile { .stablePreview }
    var fingerprint: String { "preparation-mask" }
    var graphDescriptor: MaskGraphDescriptor { mask.graphDescriptor }

    func graphDescriptor(component: MaskComponent, blendMode: MaskBlendMode, invert: Bool, featherPolicy: MaskFeatherPolicy, opacity: Float) -> MaskGraphDescriptor {
        mask.graphDescriptor
    }

    func makeMaskDescriptor(component: MaskComponent, blendMode: MaskBlendMode, invert: Bool, featherPolicy: MaskFeatherPolicy, opacity: Float) throws -> MaskDescriptor {
        calls.count += 1
        return mask
    }
}

private struct PreparationCountingFilter: C7FilterProtocol {
    let recorder: PreparationEncodingRecorder
    var modifier: ModifierEnum { .compute(kernel: "C7Brightness") }
    var factors: [Float] { [0] }

    func combinationBegin(for buffer: MTLCommandBuffer, source texture: MTLTexture, dest texture2: MTLTexture) throws -> MTLTexture {
        recorder.record(buffer)
        return texture
    }
}

private final class PreparationEncodingRecorder: @unchecked Sendable {
    private let lock = NSLock()
    // 保持强引用直到本次计数结束，避免对象地址复用影响 command buffer 去重。
    private var buffers: [MTLCommandBuffer] = []
    var encodingCount: Int { lock.withLock { buffers.count } }
    var commandBufferCount: Int { lock.withLock { Set(buffers.map(ObjectIdentifier.init)).count } }
    func record(_ buffer: MTLCommandBuffer) { lock.withLock { buffers.append(buffer) } }
    func reset() { lock.withLock { buffers.removeAll() } }
}
