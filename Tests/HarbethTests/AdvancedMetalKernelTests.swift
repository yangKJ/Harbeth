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

    func testProgrammableBlendDescriptorCarriesLibrarySourceAndFunctionConstants() {
        let constants = [
            KernelFunctionConstantDescriptor(name: "harbeth::usesWideMix", index: 0, value: .bool(true)),
            KernelFunctionConstantDescriptor(name: "harbeth::blendVariant", index: 1, value: .int(2))
        ]
        let filter = C7ProgrammableBlend(
            functionName: "C7BlendColorAdd",
            blendTexture: nil,
            intensity: 0.4,
            librarySource: .sourceFallback("programmable-blend-test"),
            functionConstants: constants
        )
        let descriptor = filter.kernelDescriptor(inputSize: C7Size(width: 4, height: 4))

        XCTAssertEqual(descriptor.functionIdentity.kind, .advancedMetal)
        XCTAssertEqual(descriptor.functionIdentity.primaryName, "C7BlendColorAdd")
        XCTAssertEqual(descriptor.functionIdentity.librarySource, .sourceFallback("programmable-blend-test"))
        XCTAssertEqual(descriptor.functionIdentity.functionConstants, constants)
        XCTAssertTrue(descriptor.fingerprint.contains("library=sourceFallback:programmable-blend-test"))
        XCTAssertTrue(descriptor.fingerprint.contains("constant=harbeth::blendVariant"))
        XCTAssertTrue(descriptor.arguments.contains(where: { argument in
            argument.name == "harbeth::usesWideMix"
                && argument.role == .functionConstant
                && argument.dataType == .bool
        }))
    }

    func testProgrammableBlendMatchesBuiltInSourceOverBlend() throws {
        let input = try makeSolidTexture(red: 40, green: 80, blue: 120, alpha: 255)
        let overlay = try makeSolidTexture(red: 220, green: 30, blue: 10, alpha: 128)

        let expected = try HarbethIO(
            element: input,
            filter: C7Blend(with: .sourceOver, blendTexture: overlay, intensity: 1.0)
        ).output()
        let programmable = try HarbethIO(
            element: input,
            filter: C7ProgrammableBlend(
                functionName: "C7BlendSourceOver",
                blendTexture: overlay,
                intensity: 1.0,
                librarySource: .sourceFallback("programmable-source-over")
            )
        ).output()

        XCTAssertEqual(try firstPixel(in: programmable), try firstPixel(in: expected))
    }

    func testProgrammableBlendSupportsCustomSamplingCoordinatesViaFunctionConstants() throws {
        let input = try makeSolidTexture(red: 10, green: 20, blue: 30, alpha: 255)
        let overlay = try makeHorizontalTexture(
            left: [0, 0, 0, 255],
            right: [255, 0, 0, 255]
        )

        let leftSample = try HarbethIO(
            element: input,
            filter: C7ProgrammableBlend(
                functionName: "C7ProgrammableBlendCoordinateProbe",
                blendTexture: overlay,
                intensity: 1.0,
                librarySource: .sourceFallback("programmable-coordinate-probe"),
                functionConstants: [
                    KernelFunctionConstantDescriptor(name: "useRightSample", index: 0, value: .bool(false))
                ]
            )
        ).output()
        let rightSample = try HarbethIO(
            element: input,
            filter: C7ProgrammableBlend(
                functionName: "C7ProgrammableBlendCoordinateProbe",
                blendTexture: overlay,
                intensity: 1.0,
                librarySource: .sourceFallback("programmable-coordinate-probe"),
                functionConstants: [
                    KernelFunctionConstantDescriptor(name: "useRightSample", index: 0, value: .bool(true))
                ]
            )
        ).output()

        XCTAssertEqual(try firstPixel(in: leftSample), [0, 0, 0, 255])
        XCTAssertEqual(try firstPixel(in: rightSample), [255, 0, 0, 255])
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

    private func makeSolidTexture(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 2,
            height: 2,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            XCTFail("Failed to create solid texture.")
            throw HarbethError.textureLoader
        }

        let bytes = Array(repeating: [red, green, blue, alpha], count: 4).flatMap { $0 }
        texture.replace(
            region: MTLRegionMake2D(0, 0, 2, 2),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: 8
        )
        return texture
    }

    private func makeHorizontalTexture(left: [UInt8], right: [UInt8]) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }
        guard left.count == 4, right.count == 4 else {
            throw HarbethError.filterParameterInvalid("Expected RGBA pixels.")
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 2,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            XCTFail("Failed to create horizontal texture.")
            throw HarbethError.textureLoader
        }

        let bytes = left + right
        texture.replace(
            region: MTLRegionMake2D(0, 0, 2, 1),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: 8
        )
        return texture
    }

    private func firstPixel(in texture: MTLTexture) throws -> [UInt8] {
        guard let bytes = texture.c7.bytes(), bytes.count >= 4 else {
            XCTFail("Expected readable RGBA bytes.")
            throw HarbethError.texture2Image
        }
        return Array(bytes[0..<4])
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
