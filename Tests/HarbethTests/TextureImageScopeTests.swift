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
