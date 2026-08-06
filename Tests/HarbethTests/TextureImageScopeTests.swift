//
//  TextureImageScopeTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/7/28.
//

import XCTest
import Metal
@testable import Harbeth

final class TextureImageScopeTests: XCTestCase {
    func testLuminanceWaveformIsGeneratedEntirelyAsAnalysisAttachment() throws {
        let input = try makeTexture(
            width: 2,
            height: 2,
            pixels: [
                0, 0, 0, 255, 255, 255, 255, 255,
                64, 64, 64, 255, 192, 192, 192, 255
            ]
        )
        let configuration = TextureImageScopeConfiguration(
            kind: .luminanceWaveform,
            width: 32,
            height: 16,
            intensity: 1,
            pixelFormat: .rgba8Unorm
        )

        let output = try input.c7.renderImageScope(configuration)
        let bytes = readRGBA8(output.texture)

        XCTAssertEqual(output.attachment.semantic, .waveform)
        XCTAssertEqual(output.texture.width, 32)
        XCTAssertEqual(output.texture.height, 16)
        XCTAssertTrue(bytes.enumerated().contains { $0.offset % 4 != 3 && $0.element > 0 })
    }

    func testTextureImageScopeConfigurationTracksValueRange() {
        let base = TextureImageScopeConfiguration(
            kind: .luminanceWaveform,
            width: 24,
            height: 16,
            intensity: 1,
            pixelFormat: .rgba8Unorm,
            valueRange: TextureAnalysisValueRange(minimum: 0.2, maximum: 0.8)
        )
        let same = TextureImageScopeConfiguration(
            kind: .luminanceWaveform,
            width: 24,
            height: 16,
            intensity: 1,
            pixelFormat: .rgba8Unorm,
            valueRange: TextureAnalysisValueRange(minimum: 0.2, maximum: 0.8)
        )
        let changed = TextureImageScopeConfiguration(
            kind: .luminanceWaveform,
            width: 24,
            height: 16,
            intensity: 1,
            pixelFormat: .rgba8Unorm,
            valueRange: TextureAnalysisValueRange(minimum: 0.4, maximum: 0.6)
        )

        XCTAssertEqual(base, same)
        XCTAssertEqual(base.fingerprint, same.fingerprint)
        XCTAssertNotEqual(base.fingerprint, changed.fingerprint)
        XCTAssertTrue(base.fingerprint.contains("range=min=0.2000|max=0.8000"))
    }

    func testTextureImageScopeConfigurationDecodesLegacyPayloadWithStableDefaults() throws {
        struct LegacyConfiguration: Codable {
            let kind: TextureImageScopeKind
            let width: Int
            let height: Int
            let intensity: Float
            let pixelFormat: PixelFormatContract
        }
        let legacy = LegacyConfiguration(
            kind: .vectorscope,
            width: 32,
            height: 24,
            intensity: 0.2,
            pixelFormat: .rgba8Unorm
        )
        let decoded = try JSONDecoder().decode(
            TextureImageScopeConfiguration.self,
            from: JSONEncoder().encode(legacy)
        )

        XCTAssertEqual(decoded.valueRange, .normalized)
        XCTAssertTrue(decoded.normalizesDensity)
        XCTAssertEqual(decoded.kind, .vectorscope)
    }

    func testRenderImageScopeRespondsToValueRange() throws {
        let input = try makeTexture(
            width: 2,
            height: 1,
            pixels: [
                64, 64, 64, 255,
                128, 128, 128, 255
            ]
        )
        let defaultOutput = try input.c7.renderImageScope(
            TextureImageScopeConfiguration(
                kind: .luminanceWaveform,
                width: 24,
                height: 16,
                pixelFormat: .rgba8Unorm,
                valueRange: .normalized
            )
        )
        let narrowRangeOutput = try input.c7.renderImageScope(
            TextureImageScopeConfiguration(
                kind: .luminanceWaveform,
                width: 24,
                height: 16,
                pixelFormat: .rgba8Unorm,
                valueRange: TextureAnalysisValueRange(minimum: 0.2, maximum: 0.3)
            )
        )

        XCTAssertEqual(defaultOutput.attachment.semantic, .waveform)
        XCTAssertNotEqual(
            readRGBA8(defaultOutput.texture),
            readRGBA8(narrowRangeOutput.texture)
        )
        XCTAssertNotEqual(defaultOutput.configuration.fingerprint, narrowRangeOutput.configuration.fingerprint)
    }

    func testImageScopeCanEncodeIntoCallerCommandBuffer() throws {
        let input = try makeTexture(width: 1, height: 1, pixels: [255, 255, 255, 255])
        guard let commandBuffer = input.device.makeCommandQueue()?.makeCommandBuffer() else {
            throw XCTSkip("Could not create Metal command buffer.")
        }
        let output = try input.c7.encodeImageScope(
            TextureImageScopeConfiguration(kind: .luminanceWaveform, width: 8, height: 8, pixelFormat: .rgba8Unorm),
            into: commandBuffer
        )

        XCTAssertEqual(commandBuffer.status, .notEnqueued)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        XCTAssertEqual(commandBuffer.status, .completed)
        XCTAssertEqual(output.attachment.semantic, .waveform)
        XCTAssertTrue(readRGBA8(output.texture).contains { $0 > 0 })
    }

    func testRGBWaveformAndVectorscopeKeepDistinctSemantics() throws {
        let input = try makeTexture(
            width: 2,
            height: 1,
            pixels: [255, 0, 0, 255, 0, 0, 255, 255]
        )
        let waveform = try input.c7.renderImageScope(
            TextureImageScopeConfiguration(kind: .rgbWaveform, width: 24, height: 16, pixelFormat: .rgba8Unorm)
        )
        let vectorscope = try input.c7.renderImageScope(
            TextureImageScopeConfiguration(kind: .vectorscope, width: 24, height: 24, pixelFormat: .rgba8Unorm)
        )

        XCTAssertEqual(waveform.attachment.semantic, .waveform)
        XCTAssertEqual(vectorscope.attachment.semantic, .vectorscope)
        XCTAssertNotEqual(waveform.configuration.fingerprint, vectorscope.configuration.fingerprint)
        XCTAssertNotNil(waveform.makeCGImage())
        XCTAssertNotNil(vectorscope.makeCGImage())
    }

    func testScopeAttachmentContractsExposeColorPreviewPolicies() {
        let waveform = RenderOutputAttachmentContract.waveform(index: 1)
        let vectorscope = RenderOutputAttachmentContract.vectorscope(index: 2)

        XCTAssertEqual(waveform.debugPolicy.interpretation, .color)
        XCTAssertEqual(vectorscope.debugPolicy.interpretation, .color)
        XCTAssertEqual(waveform.debugPolicy.label, "waveform")
        XCTAssertEqual(vectorscope.debugPolicy.label, "vectorscope")
        XCTAssertTrue(waveform.debugPolicy.preservesDynamicRange)
    }

    private func makeTexture(width: Int, height: Int, pixels: [UInt8]) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw XCTSkip("Could not create Metal texture.")
        }
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: width * 4
        )
        return texture
    }

    private func readRGBA8(_ texture: MTLTexture) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: texture.width * texture.height * 4)
        texture.getBytes(
            &bytes,
            bytesPerRow: texture.width * 4,
            from: MTLRegionMake2D(0, 0, texture.width, texture.height),
            mipmapLevel: 0
        )
        return bytes
    }
}
