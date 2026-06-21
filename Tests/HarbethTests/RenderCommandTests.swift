import XCTest
import Metal
@testable import Harbeth

final class RenderCommandTests: XCTestCase {

    func testRenderAuxiliaryLuminanceDescriptorDeclaresPrimaryAndLuminanceAttachments() {
        let descriptor = RenderAuxiliaryLuminance().renderCommandDescriptor(inputSize: C7Size(width: 8, height: 6))

        XCTAssertEqual(descriptor.outputContract.attachmentCount, 2)
        XCTAssertEqual(descriptor.outputContract.attachments[0].semantic, .primaryColor)
        XCTAssertEqual(descriptor.outputContract.attachments[0].pixelFormat, .rgba8Unorm)
        XCTAssertEqual(descriptor.outputContract.attachments[1].semantic, .luminance)
        XCTAssertEqual(descriptor.outputContract.attachments[1].pixelFormat, .rgba8Unorm)
        XCTAssertEqual(descriptor.renderPass.colorAttachments.map(\.index), [0, 1])
        XCTAssertEqual(
            descriptor.renderPass.colorAttachments.map(\.pixelFormat),
            [String(describing: MTLPixelFormat.rgba8Unorm), String(describing: MTLPixelFormat.rgba8Unorm)]
        )
    }

    func testRenderAuxiliaryMaskCoverageDescriptorDeclaresPrimaryAndMaskAttachments() throws {
        let maskTexture = try makeTexture(width: 1, height: 1, pixelFormat: .rgba8Unorm)
        let filter = RenderAuxiliaryMaskCoverage(
            mask: MaskDescriptor(
                texture: maskTexture,
                component: .red,
                invert: true,
                featherPolicy: .normalized(0.25),
                opacity: 0.6
            )
        )
        let descriptor = filter.renderCommandDescriptor(inputSize: C7Size(width: 8, height: 6))

        XCTAssertEqual(descriptor.outputContract.attachmentCount, 2)
        XCTAssertEqual(descriptor.outputContract.attachments[0].semantic, .primaryColor)
        XCTAssertEqual(descriptor.outputContract.attachments[1].semantic, .maskCoverage)
        XCTAssertEqual(descriptor.fragmentTextureCount, 2)
        XCTAssertEqual(descriptor.parameterFingerprint, "0.6000,1.0000,1.0000,0.2500")
        XCTAssertEqual(descriptor.renderPass.colorAttachments.map(\.index), [0, 1])
    }

    func testRenderAuxiliaryHighlightClippingDescriptorDeclaresPrimaryAndAnalysisAttachments() {
        let descriptor = RenderAuxiliaryHighlightClipping(threshold: 0.85, softness: 0.1)
            .renderCommandDescriptor(inputSize: C7Size(width: 8, height: 6))

        XCTAssertEqual(descriptor.outputContract.attachmentCount, 2)
        XCTAssertEqual(descriptor.outputContract.attachments[0].semantic, .primaryColor)
        XCTAssertEqual(descriptor.outputContract.attachments[1].semantic, .analysis)
        XCTAssertEqual(descriptor.outputContract.attachments[1].pixelFormat, .rgba8Unorm)
        XCTAssertEqual(descriptor.parameterFingerprint, "0.8500,0.1000")
        XCTAssertEqual(descriptor.renderPass.colorAttachments.map(\.index), [0, 1])
    }

    func testRenderCommandDescriptorTracksFragmentTexturesAndCustomGeometry() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let source = try makeTexture(width: 8, height: 6, pixelFormat: .rgba8Unorm)
        let overlay = try makeTexture(width: 8, height: 6, pixelFormat: .rgba8Unorm)
        let basic = RenderBasicFilter().renderCommandDescriptor(inputSize: C7Size(width: 8, height: 6))
        let overlayDescriptor = RenderOverlayTestFilter(overlay: overlay)
            .renderCommandDescriptor(inputSize: C7Size(width: 8, height: 6))
        let projective = RenderTransform3D()
            .renderCommandDescriptor(inputSize: C7Size(width: source.width, height: source.height))

        XCTAssertEqual(basic.fragmentTextureCount, 1)
        XCTAssertEqual(overlayDescriptor.fragmentTextureCount, 2)
        XCTAssertTrue(overlayDescriptor.parameterFingerprint.contains("0.2500"))
        XCTAssertFalse(basic.geometry.usesCustomVertices)
        XCTAssertTrue(projective.geometry.usesCustomVertices)
        XCTAssertEqual(projective.geometry.vertexStride, 5)
    }

    func testRenderCommandBatchRejectsMismatchedRenderPassContracts() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let source = try makeTexture(width: 8, height: 6, pixelFormat: .rgba8Unorm)
        let basic = RenderCommand(filter: RenderBasicFilter(), sourceTexture: source)
        let projective = RenderCommand(filter: RenderTransform3D(), sourceTexture: source)
        let batchRenderPass = basic.descriptor.renderPass
        let destination = try makeTexture(width: 8, height: 6, pixelFormat: .rgba8Unorm)

        XCTAssertThrowsError(
            try RenderCommandBatch(
                renderPass: batchRenderPass,
                destinationTexturesByAttachmentIndex: [0: destination],
                commands: [basic, projective]
            )
        ) { error in
            guard case .configurationInvalid(let message)? = error.asHarbethError else {
                return XCTFail("Expected configurationInvalid, got \(error)")
            }
            XCTAssertTrue(message.contains("render pass contract"))
        }
    }

    func testRenderCommandBatchDescriptorTracksDrawCalls() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let source = try makeTexture(width: 8, height: 6, pixelFormat: .rgba8Unorm)
        let first = RenderCommand(filter: RenderBasicFilter(), sourceTexture: source)
        let second = RenderCommand(filter: RenderBasicFilter(), sourceTexture: source)
        let destination = try makeTexture(width: 8, height: 6, pixelFormat: .rgba8Unorm)
        let batch = try RenderCommandBatch(
            renderPass: first.descriptor.renderPass,
            destinationTexturesByAttachmentIndex: [0: destination],
            commands: [first, second]
        )

        XCTAssertEqual(batch.descriptor.commandCount, 2)
        XCTAssertEqual(batch.descriptor.drawCallCount, 2)
        XCTAssertEqual(batch.descriptor.commandFingerprints.count, 2)
        XCTAssertTrue(batch.descriptor.fingerprint.contains("drawCalls=2"))
    }

    func testRenderCommandDescriptorTracksExplicitBindings() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let source = try makeTexture(width: 8, height: 6, pixelFormat: .rgba8Unorm)
        let descriptor = RenderBindingTestFilter().renderCommandDescriptor(inputSize: C7Size(width: 8, height: 6))
        let command = RenderCommand(filter: RenderBindingTestFilter(), sourceTexture: source)

        XCTAssertEqual(descriptor.parameterBindings.count, 2)
        XCTAssertTrue(descriptor.parameterBindings.contains(where: { $0.name == "vertexTransform" && $0.stage == .renderVertex }))
        XCTAssertTrue(descriptor.parameterBindings.contains(where: { $0.name == "tintColor" && $0.stage == .renderFragment }))
        XCTAssertTrue(command.descriptor.fingerprint.contains("binding=vertexTransform"))
        XCTAssertTrue(command.descriptor.fingerprint.contains("binding=tintColor"))
    }

    func testRenderCommandDescriptorDerivesMultiAttachmentRenderPassFromOutputContract() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let descriptor = RenderMultiAttachmentTestFilter().renderCommandDescriptor(inputSize: C7Size(width: 8, height: 6))

        XCTAssertEqual(descriptor.outputContract.attachmentCount, 2)
        XCTAssertTrue(descriptor.outputContract.hasMultipleAttachments)
        XCTAssertEqual(descriptor.renderPass.colorAttachments.count, 2)
        XCTAssertEqual(descriptor.renderPass.colorAttachments[0].index, 0)
        XCTAssertEqual(descriptor.renderPass.colorAttachments[1].index, 1)
        XCTAssertEqual(descriptor.renderPass.colorAttachments[0].pixelFormat, "rgba16Float")
        XCTAssertEqual(descriptor.renderPass.colorAttachments[1].pixelFormat, "rgba8Unorm")
        XCTAssertTrue(descriptor.fingerprint.contains("attachments=attachment=0"))
        XCTAssertTrue(descriptor.fingerprint.contains("attachment=1"))
    }

    func testRenderCommandBatchRejectsMismatchedOutputContracts() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let source = try makeTexture(width: 8, height: 6, pixelFormat: .rgba8Unorm)
        let first = RenderCommand(filter: RenderBasicFilter(), sourceTexture: source)
        let second = RenderCommand(
            filter: RenderMultiAttachmentTestFilter(),
            sourceTexture: source,
            renderPass: first.descriptor.renderPass
        )
        let destination0 = try makeTexture(width: 8, height: 6, pixelFormat: .rgba8Unorm)

        XCTAssertThrowsError(
            try RenderCommandBatch(
                renderPass: first.descriptor.renderPass,
                destinationTexturesByAttachmentIndex: [0: destination0],
                commands: [first, second]
            )
        ) { error in
            guard case .configurationInvalid(let message)? = error.asHarbethError else {
                return XCTFail("Expected configurationInvalid, got \(error)")
            }
            XCTAssertTrue(message.contains("output contract"))
        }
    }

    func testRenderCommandBatchEncodesAuxiliaryLuminanceAttachment() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        guard let commandQueue = Shared.shared.defaultDevice.device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            XCTFail("Failed to create command queue.")
            return
        }

        let source = try makeTexture(width: 1, height: 1, pixelFormat: .rgba8Unorm, bytes: [64, 128, 255, 255])
        let command = RenderCommand(filter: RenderAuxiliaryLuminance(), sourceTexture: source)
        let primary = try makeTexture(width: 1, height: 1, pixelFormat: .rgba8Unorm)
        let luminance = try makeTexture(width: 1, height: 1, pixelFormat: .rgba8Unorm)
        let batch = try RenderCommandBatch(
            renderPass: command.descriptor.renderPass,
            destinationTexturesByAttachmentIndex: [0: primary, 1: luminance],
            commands: [command]
        )

        try Rendering.encode(batch: batch, commandBuffer: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let primaryPixel = try firstPixel(in: primary)
        let luminancePixel = try firstPixel(in: luminance)

        XCTAssertEqual(primaryPixel.red, 64, accuracy: 2)
        XCTAssertEqual(primaryPixel.green, 128, accuracy: 2)
        XCTAssertEqual(primaryPixel.blue, 255, accuracy: 2)
        XCTAssertEqual(primaryPixel.alpha, 255, accuracy: 2)

        XCTAssertEqual(luminancePixel.red, 124, accuracy: 2)
        XCTAssertEqual(luminancePixel.green, 124, accuracy: 2)
        XCTAssertEqual(luminancePixel.blue, 124, accuracy: 2)
        XCTAssertEqual(luminancePixel.alpha, 255, accuracy: 2)
    }

    func testRenderCommandBatchEncodesAuxiliaryMaskCoverageAttachment() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        guard let commandQueue = Shared.shared.defaultDevice.device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            XCTFail("Failed to create command queue.")
            return
        }

        let source = try makeTexture(width: 1, height: 1, pixelFormat: .rgba8Unorm, bytes: [10, 20, 30, 255])
        let maskTexture = try makeTexture(width: 1, height: 1, pixelFormat: .rgba8Unorm, bytes: [128, 64, 32, 255])
        let command = RenderCommand(
            filter: RenderAuxiliaryMaskCoverage(
                mask: MaskDescriptor(texture: maskTexture, component: .red, opacity: 1)
            ),
            sourceTexture: source
        )
        let primary = try makeTexture(width: 1, height: 1, pixelFormat: .rgba8Unorm)
        let coverage = try makeTexture(width: 1, height: 1, pixelFormat: .rgba8Unorm)
        let batch = try RenderCommandBatch(
            renderPass: command.descriptor.renderPass,
            destinationTexturesByAttachmentIndex: [0: primary, 1: coverage],
            commands: [command]
        )

        try Rendering.encode(batch: batch, commandBuffer: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let primaryPixel = try firstPixel(in: primary)
        let coveragePixel = try firstPixel(in: coverage)

        XCTAssertEqual(primaryPixel.red, 10, accuracy: 2)
        XCTAssertEqual(primaryPixel.green, 20, accuracy: 2)
        XCTAssertEqual(primaryPixel.blue, 30, accuracy: 2)
        XCTAssertEqual(coveragePixel.red, 128, accuracy: 2)
        XCTAssertEqual(coveragePixel.green, 128, accuracy: 2)
        XCTAssertEqual(coveragePixel.blue, 128, accuracy: 2)
        XCTAssertEqual(coveragePixel.alpha, 255, accuracy: 2)
    }

    func testRenderCommandBatchEncodesAuxiliaryHighlightClippingAttachment() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        guard let commandQueue = Shared.shared.defaultDevice.device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            XCTFail("Failed to create command queue.")
            return
        }

        let source = try makeTexture(width: 1, height: 1, pixelFormat: .rgba8Unorm, bytes: [250, 250, 250, 255])
        let command = RenderCommand(
            filter: RenderAuxiliaryHighlightClipping(threshold: 0.9, softness: 0),
            sourceTexture: source
        )
        let primary = try makeTexture(width: 1, height: 1, pixelFormat: .rgba8Unorm)
        let analysis = try makeTexture(width: 1, height: 1, pixelFormat: .rgba8Unorm)
        let batch = try RenderCommandBatch(
            renderPass: command.descriptor.renderPass,
            destinationTexturesByAttachmentIndex: [0: primary, 1: analysis],
            commands: [command]
        )

        try Rendering.encode(batch: batch, commandBuffer: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let primaryPixel = try firstPixel(in: primary)
        let analysisPixel = try firstPixel(in: analysis)

        XCTAssertEqual(primaryPixel.red, 250, accuracy: 2)
        XCTAssertEqual(primaryPixel.green, 250, accuracy: 2)
        XCTAssertEqual(primaryPixel.blue, 250, accuracy: 2)
        XCTAssertEqual(analysisPixel.red, 255, accuracy: 2)
        XCTAssertEqual(analysisPixel.green, 0, accuracy: 2)
        XCTAssertEqual(analysisPixel.blue, 0, accuracy: 2)
        XCTAssertEqual(analysisPixel.alpha, 255, accuracy: 2)
    }

    func testRenderAttachmentSetExposesAuxiliaryAnalysisTextureAndPolicy() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let source = try makeTexture(width: 1, height: 1, pixelFormat: .rgba8Unorm, bytes: [250, 250, 250, 255])
        let output = try RenderAuxiliaryHighlightClipping(threshold: 0.9, softness: 0)
            .renderAttachmentSet(from: source, identifier: "RenderCommandTests.highlightAttachmentSet")

        XCTAssertEqual(output.attachments.map(\.semantic), [.primaryColor, .analysis])
        XCTAssertEqual(output.debugPolicies.map(\.label), ["primaryColor", "analysis"])
        XCTAssertEqual(output.debugPolicies.map(\.interpretation), [.color, .scalarField])
        XCTAssertEqual(output.texture(for: .primaryColor)?.pixelFormat, .rgba8Unorm)
        XCTAssertEqual(output.texture(for: .analysis)?.pixelFormat, .rgba8Unorm)
        XCTAssertNotNil(output.makeCGImage(for: .analysis, colorSpace: CGColorSpaceCreateDeviceRGB()))
    }

    private func makeTexture(width: Int,
                             height: Int,
                             pixelFormat: MTLPixelFormat) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        guard let texture = Shared.shared.defaultDevice.device.makeTexture(descriptor: descriptor) else {
            throw HarbethError.makeTexture
        }
        return texture
    }

    private func makeTexture(width: Int,
                             height: Int,
                             pixelFormat: MTLPixelFormat,
                             bytes: [UInt8]) throws -> MTLTexture {
        let texture = try makeTexture(width: width, height: height, pixelFormat: pixelFormat)
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: width * 4
        )
        return texture
    }

    private func firstPixel(in texture: MTLTexture) throws -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        guard let bytes = texture.c7.bytes(), bytes.count >= 4 else {
            XCTFail("Expected readable RGBA bytes.")
            throw HarbethError.texture2Image
        }
        return (bytes[0], bytes[1], bytes[2], bytes[3])
    }
}

private struct RenderOverlayTestFilter: RenderProtocol {
    let overlay: MTLTexture

    var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "basicFragment")
    }

    var factors: [Float] {
        [0.25]
    }

    var otherInputTextures: C7InputTextures {
        [overlay]
    }
}

private struct RenderBindingTestFilter: RenderProtocol {
    var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "basicFragment")
    }

    var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(
                name: "vertexTransform",
                index: 1,
                stage: .renderVertex,
                value: .matrix4x4(.Color.identity)
            ),
            KernelParameterBinding(
                name: "tintColor",
                index: 0,
                stage: .renderFragment,
                value: .float4(SIMD4<Float>(1, 0, 0, 1))
            )
        ]
    }
}

private struct RenderMultiAttachmentTestFilter: RenderProtocol {
    var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "basicFragment")
    }

    var renderOutputContract: RenderOutputContract {
        RenderOutputContract(
            colorSpace: .extendedLinearSRGB,
            pixelFormat: .rgba16Float,
            additionalAttachments: [
                RenderOutputAttachmentContract(
                    index: 1,
                    alpha: .opaque,
                    colorSpace: .sRGB,
                    pixelFormat: .rgba8Unorm
                )
            ]
        )
    }
}
