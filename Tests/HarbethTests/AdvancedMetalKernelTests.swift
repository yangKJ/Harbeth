import XCTest
import MetalKit
@testable import Harbeth

final class AdvancedMetalKernelTests: XCTestCase {
    func testCapabilityReportUsesSharedDeviceWhenDeviceIsNotProvided() {
        let report = Device.metalCapabilityReport(.customAdvancedEncoder, on: nil)

        XCTAssertEqual(report.capability, .customAdvancedEncoder)
        XCTAssertEqual(report.status, .requiresConcreteImplementationCheck)
        XCTAssertFalse(report.isSupported)
        XCTAssertTrue(report.canBeImplementedByHigherPackage)
    }

    func testCustomAdvancedEncoderRequiresConcreteImplementationCheck() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is not available.")
        }

        let report = Device.metalCapabilityReport(.customAdvancedEncoder, on: device)

        XCTAssertEqual(report.capability, .customAdvancedEncoder)
        XCTAssertEqual(report.status, .requiresConcreteImplementationCheck)
        XCTAssertFalse(report.isSupported)
        XCTAssertTrue(report.canBeImplementedByHigherPackage)
    }

    func testAdvancedKernelFallsBackWhenDefaultCapabilityIsNotDirectlySupported() throws {
        let (commandBuffer, output, input) = try makeTexturePair()

        let filter = FallbackOnlyAdvancedFilter()
        let result = try filter.encode(commandBuffer: commandBuffer, textures: [output, input])

        XCTAssertTrue(result === output)
    }

    func testAdvancedMetalModifierRoutesThroughApply() throws {
        let (commandBuffer, output, input) = try makeTexturePair()

        let filter = FallbackOnlyAdvancedFilter()
        let result = try filter.apply(form: input, to: output, for: commandBuffer, complete: nil)

        XCTAssertEqual(filter.advancedMetalCapability, .customAdvancedEncoder)
        XCTAssertTrue(result === output)
    }

    private func makeTexturePair() throws -> (MTLCommandBuffer, MTLTexture, MTLTexture) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw XCTSkip("Metal device is not available.")
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let output = device.makeTexture(descriptor: descriptor),
              let input = device.makeTexture(descriptor: descriptor) else {
            XCTFail("Failed to create test textures.")
            throw HarbethError.filterParameterInvalid("Failed to create test textures.")
        }

        return (commandBuffer, output, input)
    }
}

private struct FallbackOnlyAdvancedFilter: C7AdvancedMetalKernelProtocol {
    var modifier: ModifierEnum {
        .advancedMetal(capability: .customAdvancedEncoder, function: "unused")
    }

    func encodeAdvanced(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        throw HarbethError.filterParameterInvalid("Advanced path should not run in this test.")
    }

    func encodeFallback(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        guard let output = textures.first else {
            throw HarbethError.filterParameterInvalid("Missing output texture.")
        }
        return output
    }
}
