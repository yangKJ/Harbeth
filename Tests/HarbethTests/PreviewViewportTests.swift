//
//  PreviewViewportTests.swift
//  Harbeth
//
//  Created by Condy on 2026/10/10.
//

import CoreGraphics
import Metal
import XCTest
@testable import Harbeth

@MainActor
final class PreviewViewportTests: XCTestCase {
    func testRejectsInvalidDimensionsButAllowsNegativeOrigin() async {
        XCTAssertNil(PreviewViewport(normalizedContentRect: CGRect(x: 0, y: 0, width: 0, height: 1)))
        XCTAssertNil(PreviewViewport(normalizedContentRect: CGRect(x: 0, y: 0, width: -1, height: 1)))
        XCTAssertNil(PreviewViewport(normalizedContentRect: CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 1)))
        XCTAssertNotNil(PreviewViewport(normalizedContentRect: CGRect(x: -2, y: -1, width: 3, height: 2)))
    }

    func testDefaultAspectFitGeometry() async {
        let vertices = PreviewQuadGeometry.vertices(textureSize: CGSize(width: 2, height: 1), drawableSize: CGSize(width: 1, height: 1),
                                                    resizingMode: .aspectFit, viewport: nil)
        XCTAssertEqual(vertices, [-1, -0.5, 0, 1, 1, -0.5, 1, 1, -1, 0.5, 0, 0, 1, 0.5, 1, 0])
    }

    func testDefaultAspectFillAndStretchGeometry() async {
        let fill = PreviewQuadGeometry.vertices(textureSize: CGSize(width: 2, height: 1), drawableSize: CGSize(width: 1, height: 1),
                                                resizingMode: .aspectFill, viewport: nil)
        let stretch = PreviewQuadGeometry.vertices(textureSize: CGSize(width: 2, height: 1), drawableSize: CGSize(width: 1, height: 1),
                                                   resizingMode: .scaleToFill, viewport: nil)
        XCTAssertEqual(fill, [-1, -1, 0.25, 1, 1, -1, 0.75, 1, -1, 1, 0.25, 0, 1, 1, 0.75, 0])
        XCTAssertEqual(stretch, [-1, -1, 0, 1, 1, -1, 1, 1, -1, 1, 0, 0, 1, 1, 1, 0])
    }

    func testExplicitDestinationClipsQuadAndMapsUV() async {
        let viewport = PreviewViewport(normalizedContentRect: CGRect(x: -0.5, y: 0.25, width: 2, height: 0.5))
        let vertices = PreviewQuadGeometry.vertices(textureSize: CGSize(width: 2, height: 2), drawableSize: CGSize(width: 4, height: 4),
                                                    resizingMode: .scaleToFill, viewport: viewport)
        XCTAssertEqual(vertices, [-1, -0.5, 0.25, 1, 1, -0.5, 0.75, 1, -1, 0.5, 0.25, 0, 1, 0.5, 0.75, 0])
    }

    func testFullyOffscreenViewportReturnsEmptyQuad() async {
        let viewport = PreviewViewport(normalizedContentRect: CGRect(x: 2, y: 0, width: 1, height: 1))
        XCTAssertEqual(PreviewQuadGeometry.vertices(textureSize: CGSize(width: 2, height: 2), drawableSize: CGSize(width: 2, height: 2),
                                                    resizingMode: .scaleToFill, viewport: viewport), [])
    }

    func testHugeViewportKeepsPositionBoundedAndUVFinite() async throws {
        let viewport = PreviewViewport(normalizedContentRect: CGRect(x: -1_000_000, y: -1_000_000, width: 2_000_001, height: 2_000_001))
        let vertices = try XCTUnwrap(PreviewQuadGeometry.vertices(
            textureSize: CGSize(width: 2, height: 2), drawableSize: CGSize(width: 2, height: 2), resizingMode: .scaleToFill, viewport: viewport
        ))
        XCTAssertTrue(vertices.enumerated().allSatisfy { index, value in
            value.isFinite && (index % 4 < 2 ? (-1...1).contains(value) : (0...1).contains(value))
        })
        XCTAssertEqual(vertices[2], 0.49999976, accuracy: 0.00001)
        XCTAssertEqual(vertices[6], 0.50000024, accuracy: 0.00001)
    }

    func testNearestSamplingPreservesDiscretePixel() async throws {
        let output = try render(viewport: nil, sampling: .nearest)
        XCTAssertEqual(pixel(output, x: 1, y: 1), [255, 0, 0, 255])
    }

    func testLinearSamplingMatchesIndependentBilinearBlend() async throws {
        let value = pixel(try render(viewport: nil, sampling: .linear), x: 1, y: 1)
        XCTAssertEqual(Double(value[0]), 159, accuracy: 2)
        XCTAssertEqual(Double(value[1]), 64, accuracy: 2)
        XCTAssertEqual(Double(value[2]), 64, accuracy: 2)
        XCTAssertEqual(value[3], 255)
    }

    func testViewportSamplesRightHalfWithCorrectVerticalOrientation() async throws {
        let viewport = PreviewViewport(normalizedContentRect: CGRect(x: -1, y: 0, width: 2, height: 1))
        let output = try render(viewport: viewport, sampling: .nearest)
        XCTAssertEqual(pixel(output, x: 0, y: 1), [0, 255, 0, 255])
        XCTAssertEqual(pixel(output, x: 3, y: 3), [255, 255, 255, 255])
    }

    func testOffscreenViewportClearsOldPixels() async throws {
        let viewport = PreviewViewport(normalizedContentRect: CGRect(x: 2, y: 2, width: 1, height: 1))
        let output = try render(viewport: viewport, sampling: .nearest)
        for x in 0..<4 {
            for y in 0..<4 { XCTAssertEqual(pixel(output, x: x, y: y), [0, 0, 0, 255]) }
        }
    }

    func testInFlightCommandsKeepTheirOwnVertices() async throws {
        let device = try metalDevice()
        let input = try makeInput(device: device)
        let pipeline = try HarbethContext.shared.makeRenderPipelineState(vertex: "basicVertex", fragment: "basicFragment", pixelFormat: .rgba8Unorm)
        let sampler = try XCTUnwrap(HarbethContext.shared.makeSamplerState(minFilter: .nearest, magFilter: .nearest))
        let a = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
        let b = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
        let ta = try makeOutput(device: device)
        let tb = try makeOutput(device: device)
        try encode(input: input, output: ta, viewport: PreviewViewport(normalizedContentRect: CGRect(x: 0, y: 0, width: 0.5, height: 1)),
                   pipeline: pipeline, sampler: sampler, commandBuffer: a)
        try encode(input: input, output: tb, viewport: PreviewViewport(normalizedContentRect: CGRect(x: 0.5, y: 0, width: 0.5, height: 1)),
                   pipeline: pipeline, sampler: sampler, commandBuffer: b)
        finish([a, b])
        XCTAssertNil(a.error)
        XCTAssertNil(b.error)
        XCTAssertEqual(pixel(ta, x: 0, y: 0), [255, 0, 0, 255])
        XCTAssertEqual(pixel(tb, x: 3, y: 0), [0, 255, 0, 255])
    }

    private func render(viewport: PreviewViewport?, sampling: PreviewSampling) throws -> MTLTexture {
        let device = try metalDevice()
        let input = try makeInput(device: device)
        let output = try makeOutput(device: device)
        let pipeline = try HarbethContext.shared.makeRenderPipelineState(vertex: "basicVertex", fragment: "basicFragment", pixelFormat: .rgba8Unorm)
        let filter: MTLSamplerMinMagFilter = sampling == .nearest ? .nearest : .linear
        let sampler = try XCTUnwrap(HarbethContext.shared.makeSamplerState(minFilter: filter, magFilter: filter))
        let commandBuffer = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
        try encode(input: input, output: output, viewport: viewport, pipeline: pipeline, sampler: sampler, commandBuffer: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        XCTAssertNil(commandBuffer.error)
        return output
    }

    private func finish(_ commands: [MTLCommandBuffer]) {
        for command in commands { command.commit() }
        for command in commands { command.waitUntilCompleted() }
    }

    private func encode(input: MTLTexture, output: MTLTexture, viewport: PreviewViewport?, pipeline: MTLRenderPipelineState,
                        sampler: MTLSamplerState, commandBuffer: MTLCommandBuffer) throws {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = output
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
        pass.colorAttachments[0].storeAction = .store
        let encoder = try XCTUnwrap(commandBuffer.makeRenderCommandEncoder(descriptor: pass))
        let vertices = try XCTUnwrap(PreviewQuadGeometry.vertices(
            textureSize: CGSize(width: input.width, height: input.height), drawableSize: CGSize(width: output.width, height: output.height),
            resizingMode: .scaleToFill, viewport: viewport
        ))
        PreviewDrawEncoder.encode(texture: input, vertices: vertices, pipelineState: pipeline, samplerState: sampler, into: encoder)
        encoder.endEncoding()
    }

    private func metalDevice() throws -> MTLDevice {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("当前环境没有 Metal 设备") }
        return device
    }

    private func makeInput(device: MTLDevice) throws -> MTLTexture {
        let texture = try makeTexture(device: device, width: 2, height: 2)
        let bytes: [UInt8] = [255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255]
        bytes.withUnsafeBytes { raw in
            texture.replace(region: MTLRegionMake2D(0, 0, 2, 2), mipmapLevel: 0, withBytes: raw.baseAddress!, bytesPerRow: 8)
        }
        return texture
    }

    private func makeOutput(device: MTLDevice) throws -> MTLTexture { try makeTexture(device: device, width: 4, height: 4) }

    private func makeTexture(device: MTLDevice, width: Int, height: Int) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead, .renderTarget]
        descriptor.storageMode = .shared
        return try XCTUnwrap(device.makeTexture(descriptor: descriptor))
    }

    private func pixel(_ texture: MTLTexture, x: Int, y: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        bytes.withUnsafeMutableBytes { raw in
            texture.getBytes(raw.baseAddress!, bytesPerRow: 4, from: MTLRegionMake2D(x, y, 1, 1), mipmapLevel: 0)
        }
        return bytes
    }
}
