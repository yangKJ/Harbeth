//
//  SamplerContractForwardingTests.swift
//  Harbeth
//
//  Created by Condy on 2026/10/7.
//

import Metal
import XCTest
@testable import Harbeth

final class SamplerContractForwardingTests: XCTestCase {
    func testSamplerOverrideForwardsCompleteRenderContractAndOnlyChangesSamplerIdentity() {
        let base = SamplerContractProbeFilter()
        let adapted = SamplerExecutionAdapter.adapt(renderFilter: base, samplerDescriptor: .nearest)

        XCTAssertEqual(adapted.identifier, "sampler-contract-probe|sampler=\(ImageSamplerDescriptor.nearest.fingerprint)")
        XCTAssertEqual(adapted.modifier, base.modifier)
        XCTAssertEqual(adapted.factors, base.factors)
        XCTAssertEqual(adapted.otherInputTextures.count, base.otherInputTextures.count)
        XCTAssertEqual(adapted.kernelParameterBindings, base.kernelParameterBindings)
        XCTAssertEqual(adapted.computeKernelLibrarySource, base.computeKernelLibrarySource)
        XCTAssertEqual(adapted.computeKernelFunctionConstants, base.computeKernelFunctionConstants)
        XCTAssertEqual(adapted.destinationTextureContract, base.destinationTextureContract)
        XCTAssertEqual(adapted.kernelOutputContract, base.kernelOutputContract)
        XCTAssertEqual(adapted.memoryAccessPattern, base.memoryAccessPattern)
        XCTAssertEqual(adapted.kernelPixelContract, base.kernelPixelContract)
        XCTAssertEqual(adapted.kernelResourceIdentity, base.kernelResourceIdentity)
        XCTAssertEqual(adapted.renderVertexStride, base.renderVertexStride)
        XCTAssertEqual(adapted.renderPrimitiveTopology, base.renderPrimitiveTopology)
        XCTAssertEqual(adapted.renderBlendMode, base.renderBlendMode)
        XCTAssertEqual(adapted.renderRasterSampleCount, base.renderRasterSampleCount)
        XCTAssertEqual(adapted.renderPreloadsSourceTexture, base.renderPreloadsSourceTexture)
        XCTAssertEqual(adapted.renderOutputContract, base.renderOutputContract)
        XCTAssertEqual(adapted.renderSamplerDescriptor, ImageSamplerDescriptor.nearest)
        XCTAssertEqual(adapted.renderSamplerConsumption, base.renderSamplerConsumption)
        XCTAssertEqual(adapted.resize(input: C7Size(width: 7, height: 5)), base.resize(input: C7Size(width: 7, height: 5)))
    }

    func testRenderLayerCompositePreservesPremultipliedBlendAcrossTextureFrameAndAttachments() throws {
        let expected = [128, 0, 127, 255]
        for sampler in [ImageSamplerDescriptor.default, .nearest] {
            let texturePixel = try MaskTestHelpers.pixel(in: makeCompositeNode(sampler: sampler).makeTexture(), x: 0, y: 0)
            assertCompositePixel(texturePixel, expected: expected, route: "makeTexture", sampler: sampler)

            let framePixel = try MaskTestHelpers.pixel(in: makeCompositeNode(sampler: sampler).makeFrame().texture, x: 0, y: 0)
            assertCompositePixel(framePixel, expected: expected, route: "makeFrame", sampler: sampler)

            let attachment = try XCTUnwrap(makeCompositeNode(sampler: sampler).makeAttachmentSet()?.primary)
            let attachmentPixel = try MaskTestHelpers.pixel(in: attachment.texture, x: 0, y: 0)
            assertCompositePixel(attachmentPixel, expected: expected, route: "makeAttachmentSet", sampler: sampler)
        }
    }

    private func assertCompositePixel(
        _ pixel: (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8),
        expected: [Int],
        route: String,
        sampler: ImageSamplerDescriptor
    ) {
        let actual = [pixel.red, pixel.green, pixel.blue, pixel.alpha]
        for (value, target) in zip(actual, expected) {
            XCTAssertLessThanOrEqual(
                abs(Int(value) - target),
                1,
                "route=\(route) sampler=\(sampler.fingerprint) pixel=\(actual) expected=\(expected)"
            )
        }
    }

    private func makeCompositeNode(sampler: ImageSamplerDescriptor) throws -> ImageNode {
        let background = try makeSharedTexture(bytes: [UInt8(0), UInt8(0), UInt8(255), UInt8(255)])
        let layer = try makeSharedTexture(bytes: [UInt8(128), UInt8(0), UInt8(0), UInt8(128)])
        return ImageNode.texture(background)
            .applying(try RenderLayerComposite(layerTexture: layer, opacity: 1))
            .withSamplerDescriptor(sampler)
    }

    private func makeSharedTexture(bytes: [UInt8]) throws -> MTLTexture {
        let device = try MaskTestHelpers.requireDevice()
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw HarbethError.makeTexture
        }
        texture.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: MemoryLayout<UInt8>.size * 4
        )
        return texture
    }
}

private struct SamplerContractProbeFilter: RenderProtocol {
    var identifier: String { "sampler-contract-probe" }
    var modifier: ModifierEnum { .render(vertex: "basicVertex", fragment: "basicFragment") }
    var factors: [Float] { [0.25, 0.75] }
    var computeKernelLibrarySource: KernelLibrarySource { .externalProvider("sampler-contract") }
    var computeKernelFunctionConstants: [KernelFunctionConstantDescriptor] {
        [KernelFunctionConstantDescriptor(name: "mode", index: 2, value: .int(7))]
    }
    var destinationTextureContract: FilterDestinationTextureContract {
        FilterDestinationTextureContract(
            usage: [.shaderRead, .renderTarget],
            storageMode: .private,
            aliasingPolicy: .inPlaceAllowed
        )
    }
    var kernelOutputContract: RenderOutputContract { .highPrecisionLinearTexture }
    var memoryAccessPattern: MemoryAccessPattern { .dualTexture }
    var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(samplingFootprint: .neighborhood(radius: 2))
    }
    var kernelResourceIdentity: String? { "sampler-resource" }
    var renderVertexStride: Int { 8 }
    var renderPrimitiveTopology: RenderPrimitiveTopology { .triangle }
    var renderBlendMode: RenderBlendMode { .premultipliedSourceOver }
    var renderRasterSampleCount: Int { 4 }
    var renderPreloadsSourceTexture: Bool { true }
    var renderOutputContract: RenderOutputContract { .highPrecisionLinearTexture }
    var renderSamplerConsumption: RenderSamplerConsumption { .runtimeBound }

    func resize(input size: C7Size) -> C7Size {
        C7Size(width: size.width + 1, height: size.height + 1)
    }
}
