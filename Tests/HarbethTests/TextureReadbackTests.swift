import XCTest
import Metal
import CoreGraphics
import CoreVideo
@testable import Harbeth

final class TextureReadbackTests: XCTestCase {

    func testHalfFloatExtendedLinearTextureRoundTripPreservesExtendedValues() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: 1,
            height: 1,
            mipmapped: false
        )
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        var source: [Float16] = [2, 0.5, -0.25, 1]
        texture.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0,
            withBytes: &source,
            bytesPerRow: MemoryLayout<Float16>.size * 4
        )
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
        let image = try XCTUnwrap(texture.c7.toCGImage(colorSpace: colorSpace))

        XCTAssertEqual(image.bitsPerComponent, 16)
        XCTAssertEqual(image.bitsPerPixel, 64)
        XCTAssertTrue(image.bitmapInfo.contains(.floatComponents))
        XCTAssertEqual(image.colorSpace?.name as String?, CGColorSpace.extendedLinearSRGB as String)

        let roundTripped = try TextureLoader(with: image).texture
        XCTAssertEqual(roundTripped.pixelFormat, .rgba16Float)
        var output = [Float16](repeating: 0, count: 4)
        roundTripped.getBytes(
            &output,
            bytesPerRow: MemoryLayout<Float16>.size * 4,
            from: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0
        )
        XCTAssertEqual(Float(output[0]), 2, accuracy: 0.002)
        XCTAssertEqual(Float(output[1]), 0.5, accuracy: 0.002)
        XCTAssertEqual(Float(output[2]), -0.25, accuracy: 0.002)
    }

    func testHighPrecisionCGImageFallbackNeverDowngradesToRGBA8() throws {
        let image = try makeHalfFloatCGImage(
            colorSpaceName: CGColorSpace.itur_2100_PQ,
            pixels: [Float16(0.73), Float16(0.31), Float16(0.12), Float16(1)]
        )

        XCTAssertEqual(TextureLoader.preferredPixelFormat(for: image), .rgba16Float)
        let texture = try TextureLoader.drawCGImageToTexture(image, pixelFormat: .rgba16Float)
        XCTAssertEqual(texture.pixelFormat, .rgba16Float)
    }

    func testCGImageSourceDescriptorReportsConcretePixelFormat() throws {
        let sRGB = try makeEightBitCGImage(colorSpaceName: CGColorSpace.sRGB)
        let hlg = try makeHalfFloatCGImage(
            colorSpaceName: CGColorSpace.itur_2100_HLG,
            pixels: [Float16(0.62), Float16(0.4), Float16(0.2), Float16(1)]
        )

        XCTAssertEqual(ImageSource.cgImage(sRGB).descriptor.texturePixelFormat, .rgba8Unorm)
        XCTAssertEqual(ImageSource.cgImage(hlg).descriptor.texturePixelFormat, .rgba16Float)
    }

    func testHalfFloatPixelBufferTextureLoaderPrefersRGBA16Float() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_64RGBAHalf,
            kCVPixelBufferWidthKey: 2,
            kCVPixelBufferHeightKey: 2,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            2,
            2,
            kCVPixelFormatType_64RGBAHalf,
            attributes as CFDictionary,
            &pixelBuffer
        )
        try XCTSkipIf(
            status != kCVReturnSuccess,
            "RGBA16F pixel buffer is unavailable in this environment. CVPixelBufferCreate status=\(status)."
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create RGBA16F pixel buffer.")
            return
        }

        let contract = pixelBuffer.c7.contract
        XCTAssertEqual(contract.preferredMetalPixelFormat, .rgba16Float)

        let texture = try TextureLoader(with: pixelBuffer).texture
        #if targetEnvironment(simulator)
        XCTAssertTrue(texture.pixelFormat == .rgba8Unorm || texture.pixelFormat == .rgba16Float)
        #else
        XCTAssertEqual(texture.pixelFormat, .rgba16Float)
        #endif
    }

    func testHalfFloatPixelBufferDirectMetalBridgeUsesRGBA16FloatWhenAvailable() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Direct CVMetalTexture bridge assertions are not stable on Simulator.")
        #else
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_64RGBAHalf,
            kCVPixelBufferWidthKey: 2,
            kCVPixelBufferHeightKey: 2,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            2,
            2,
            kCVPixelFormatType_64RGBAHalf,
            attributes as CFDictionary,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        guard let pixelBuffer else {
            XCTFail("Failed to create RGBA16F pixel buffer.")
            return
        }

        var cache: CVMetalTextureCache?
        XCTAssertEqual(CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device!, nil, &cache), kCVReturnSuccess)
        let texture = pixelBuffer.c7.convert2MTLTexture(textureCache: cache, pixelFormat: .rgba16Float)

        XCTAssertEqual(texture?.pixelFormat, .rgba16Float)
        if let texture {
            XCTAssertNil(TextureOwnerRegistry.owner(for: texture))
        }
        #endif
    }

    func testBiPlanarPixelBufferTextureLoaderDecodesToRGBAWhenAvailable() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Direct plane-texture bridge assertions are not stable on Simulator.")
        #else
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey: 4,
            kCVPixelBufferHeightKey: 4,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            4,
            4,
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            attributes as CFDictionary,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        guard let pixelBuffer else {
            XCTFail("Failed to create bi-planar pixel buffer.")
            return
        }

        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()
        XCTAssertEqual(bridgePlan.loadStrategy, .directPlaneTexture)
        XCTAssertTrue(bridgePlan.preservesOwnerReference)

        let texture = try TextureLoader(with: pixelBuffer).texture

        XCTAssertEqual(texture.pixelFormat, .rgba8Unorm)
        XCTAssertEqual(texture.width, 4)
        XCTAssertEqual(texture.height, 4)
        XCTAssertNil(TextureOwnerRegistry.owner(for: texture))
        #endif
    }

    func testImageNodePixelBufferUsesPlaneAwareDecodeForBiPlanarYUV() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Direct plane-texture bridge assertions are not stable on Simulator.")
        #else
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        let pixelBuffer = try makePixelBuffer(
            width: 4,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            unavailableMessage: "Bi-planar pixel buffer is unavailable in this environment."
        )

        let frame = try ImageNode
            .pixelBuffer(pixelBuffer)
            .makeFrame(profile: .interactiveLatency)

        XCTAssertEqual(frame.texture.pixelFormat, .rgba8Unorm)
        XCTAssertEqual(frame.texture.width, 4)
        XCTAssertEqual(frame.texture.height, 4)
        XCTAssertEqual(frame.sourceDescriptor.pixelBufferBridgePolicy, .directPlaneDecodeToRGBA)
        XCTAssertNil(TextureOwnerRegistry.owner(for: frame.texture))
        #endif
    }

    func testImageNodeSampleBufferUsesPlaneAwareDecodeForBiPlanarYUV() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Direct plane-texture bridge assertions are not stable on Simulator.")
        #else
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        let pixelBuffer = try makePixelBuffer(
            width: 4,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            unavailableMessage: "Bi-planar pixel buffer is unavailable in this environment."
        )
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffer.")
            return
        }

        let frame = try ImageNode
            .sampleBuffer(sampleBuffer)
            .makeFrame(profile: .interactiveLatency)

        XCTAssertEqual(frame.texture.pixelFormat, .rgba8Unorm)
        XCTAssertEqual(frame.texture.width, 4)
        XCTAssertEqual(frame.texture.height, 4)
        XCTAssertEqual(frame.sourceDescriptor.pixelBufferBridgePolicy, .directPlaneDecodeToRGBA)
        XCTAssertEqual(frame.sourceDescriptor.sampleBufferContract?.pixelBufferContract?.cvPixelFormatType, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        #endif
    }

    func testTriPlanarPixelBufferTextureLoaderDecodesToRGBAWhenAvailable() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Direct plane-texture bridge assertions are not stable on Simulator.")
        #else
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8PlanarFullRange,
            kCVPixelBufferWidthKey: 6,
            kCVPixelBufferHeightKey: 4,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            6,
            4,
            kCVPixelFormatType_420YpCbCr8PlanarFullRange,
            attributes as CFDictionary,
            &pixelBuffer
        )
        try XCTSkipIf(
            status != kCVReturnSuccess,
            "Tri-planar pixel buffer is unavailable in this environment. CVPixelBufferCreate status=\(status)."
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create tri-planar pixel buffer.")
            return
        }

        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()
        XCTAssertEqual(bridgePlan.loadStrategy, .directPlaneTexture)
        XCTAssertTrue(bridgePlan.preservesOwnerReference)
        XCTAssertEqual(bridgePlan.directPlaneBridgeCount, 3)

        let texture = try TextureLoader(with: pixelBuffer).texture

        XCTAssertEqual(texture.pixelFormat, .rgba8Unorm)
        XCTAssertEqual(texture.width, 6)
        XCTAssertEqual(texture.height, 4)
        XCTAssertNil(TextureOwnerRegistry.owner(for: texture))
        #endif
    }

    func testBiPlanarFullRangeDecodeStrategyDefaultsTo601FullRange() throws {
        let pixelBuffer = try makePixelBuffer(
            width: 4,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            unavailableMessage: "Bi-planar pixel buffer is unavailable in this environment."
        )
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()

        let strategy = try XCTUnwrap(TextureLoader.makeYCbCrDecodeStrategy(for: pixelBuffer, bridgePlan: bridgePlan))

        XCTAssertEqual(strategy.layout, .biPlanar)
        XCTAssertEqual(strategy.destinationPixelFormat, .rgba8Unorm)
        XCTAssertEqual(strategy.descriptor, "601FullRange")
        XCTAssertEqual(strategy.conversionMatrix.values, Matrix3x3.Kernel.to601FullRange.values)
        XCTAssertEqual(strategy.conversionOffset.x, 0, accuracy: 0.0001)
        XCTAssertEqual(strategy.conversionOffset.y, -0.5, accuracy: 0.0001)
        XCTAssertEqual(strategy.conversionOffset.z, -0.5, accuracy: 0.0001)
    }

    func test422BiPlanarPixelBufferContractUsesBiPlanarMetalFormats() throws {
        let pixelBuffer = try makePixelBuffer(
            width: 8,
            height: 4,
            pixelFormatType: kCVPixelFormatType_422YpCbCr8BiPlanarVideoRange,
            unavailableMessage: "422 bi-planar pixel buffer is unavailable in this environment."
        )

        let contract = pixelBuffer.c7.contract
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()

        XCTAssertEqual(contract.colorModel, .yCbCrBiPlanar)
        XCTAssertEqual(contract.planeCount, 2)
        XCTAssertEqual(contract.nativeTextureLayout, .planeTextures)
        XCTAssertEqual(contract.planes[0].metalPixelFormat, .r8Unorm)
        XCTAssertEqual(contract.planes[1].metalPixelFormat, .rg8Unorm)
        XCTAssertEqual(contract.planes[0].width, 8)
        XCTAssertEqual(contract.planes[0].height, 4)
        XCTAssertEqual(contract.planes[1].width, 4)
        XCTAssertEqual(contract.planes[1].height, 4)
        XCTAssertEqual(bridgePlan.loadStrategy, .directPlaneTexture)
    }

    func test422BiPlanarDecodeStrategyUsesBiPlanarLayoutAndRange() throws {
        let pixelBuffer = try makePixelBuffer(
            width: 8,
            height: 4,
            pixelFormatType: kCVPixelFormatType_422YpCbCr8BiPlanarFullRange,
            unavailableMessage: "422 bi-planar pixel buffer is unavailable in this environment."
        )
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()

        let strategy = try XCTUnwrap(TextureLoader.makeYCbCrDecodeStrategy(for: pixelBuffer, bridgePlan: bridgePlan))

        XCTAssertEqual(strategy.layout, .biPlanar)
        XCTAssertEqual(strategy.matrixContract, .bt601FullRange)
        XCTAssertEqual(strategy.descriptor, "601FullRange")
        XCTAssertEqual(strategy.destinationPixelFormat, .rgba8Unorm)
        XCTAssertEqual(strategy.conversionOffset.x, 0, accuracy: 0.0001)
    }

    func test420TenBitBiPlanarContractUsesHighPrecisionPlaneFormats() throws {
        let pixelBuffer = try makePixelBuffer(
            width: 8,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
            unavailableMessage: "420 10-bit bi-planar pixel buffer is unavailable in this environment."
        )

        let contract = pixelBuffer.c7.contract
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()

        XCTAssertEqual(contract.colorModel, .yCbCrBiPlanar)
        XCTAssertEqual(contract.planeCount, 2)
        XCTAssertEqual(contract.nativeTextureLayout, .planeTextures)
        XCTAssertEqual(contract.planes[0].metalPixelFormat, .r16Unorm)
        XCTAssertEqual(contract.planes[1].metalPixelFormat, .rg16Unorm)
        XCTAssertEqual(contract.planes[0].width, 8)
        XCTAssertEqual(contract.planes[0].height, 4)
        XCTAssertEqual(contract.planes[1].width, 4)
        XCTAssertEqual(contract.planes[1].height, 2)
        XCTAssertEqual(bridgePlan.loadStrategy, .directPlaneTexture)
    }

    func test420TenBitBiPlanarDecodeStrategyUsesRGBA16FloatAndTenBitOffset() throws {
        let pixelBuffer = try makePixelBuffer(
            width: 8,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
            unavailableMessage: "420 10-bit bi-planar pixel buffer is unavailable in this environment."
        )
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()

        let strategy = try XCTUnwrap(TextureLoader.makeYCbCrDecodeStrategy(for: pixelBuffer, bridgePlan: bridgePlan))

        XCTAssertEqual(strategy.layout, .biPlanar)
        XCTAssertEqual(strategy.matrixContract, .bt601VideoRange)
        XCTAssertEqual(strategy.descriptor, "601VideoRange10Bit")
        XCTAssertEqual(strategy.destinationPixelFormat, .rgba16Float)
        XCTAssertEqual(strategy.conversionOffset.x, -(64.0 / 1023.0), accuracy: 0.0001)
    }

    func test420TenBitBiPlanarDecodeContractTracksTenBitComponents() throws {
        let pixelBuffer = try makePixelBuffer(
            width: 8,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
            unavailableMessage: "420 10-bit bi-planar pixel buffer is unavailable in this environment."
        )
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()

        let contract = try XCTUnwrap(TextureLoader.makeYCbCrDecodeContract(for: pixelBuffer, bridgePlan: bridgePlan))

        XCTAssertEqual(contract.layout, .biPlanar)
        XCTAssertEqual(contract.matrix, .bt601VideoRange)
        XCTAssertEqual(contract.componentBitDepth, 10)
        XCTAssertEqual(contract.destinationPixelFormat, .rgba16Float)
        XCTAssertEqual(contract.fingerprint, "layout=biPlanar|matrix=bt601VideoRange|bitDepth=10|destPixel=115")
    }

    func test422TenBitBiPlanarContractUsesFullHeightChromaAndHighPrecisionFormats() throws {
        let pixelBuffer = try makePixelBuffer(
            width: 8,
            height: 4,
            pixelFormatType: kCVPixelFormatType_422YpCbCr10BiPlanarFullRange,
            unavailableMessage: "422 10-bit bi-planar pixel buffer is unavailable in this environment."
        )

        let contract = pixelBuffer.c7.contract
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()

        XCTAssertEqual(contract.colorModel, .yCbCrBiPlanar)
        XCTAssertEqual(contract.planes[0].metalPixelFormat, .r16Unorm)
        XCTAssertEqual(contract.planes[1].metalPixelFormat, .rg16Unorm)
        XCTAssertEqual(contract.planes[0].width, 8)
        XCTAssertEqual(contract.planes[0].height, 4)
        XCTAssertEqual(contract.planes[1].width, 4)
        XCTAssertEqual(contract.planes[1].height, 4)
        XCTAssertEqual(bridgePlan.loadStrategy, .directPlaneTexture)
    }

    func test422TenBitBiPlanarFullRangeDecodeStrategyUsesRGBA16Float() throws {
        let pixelBuffer = try makePixelBuffer(
            width: 8,
            height: 4,
            pixelFormatType: kCVPixelFormatType_422YpCbCr10BiPlanarFullRange,
            unavailableMessage: "422 10-bit bi-planar pixel buffer is unavailable in this environment."
        )
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()

        let strategy = try XCTUnwrap(TextureLoader.makeYCbCrDecodeStrategy(for: pixelBuffer, bridgePlan: bridgePlan))

        XCTAssertEqual(strategy.layout, .biPlanar)
        XCTAssertEqual(strategy.matrixContract, .bt601FullRange)
        XCTAssertEqual(strategy.descriptor, "601FullRange10Bit")
        XCTAssertEqual(strategy.destinationPixelFormat, .rgba16Float)
        XCTAssertEqual(strategy.conversionOffset.x, 0, accuracy: 0.0001)
    }

    func test420TenBitBiPlanarTextureLoaderDecodesToRGBA16Float() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Direct plane-texture bridge assertions are not stable on Simulator.")
        #else
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        let pixelBuffer = try makePixelBuffer(
            width: 8,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
            unavailableMessage: "420 10-bit bi-planar pixel buffer is unavailable in this environment."
        )

        let texture = try TextureLoader(with: pixelBuffer).texture

        XCTAssertEqual(texture.pixelFormat, .rgba16Float)
        XCTAssertEqual(texture.width, 8)
        XCTAssertEqual(texture.height, 4)
        XCTAssertNil(TextureOwnerRegistry.owner(for: texture))
        #endif
    }

    func test422TenBitBiPlanarTextureLoaderDecodesToRGBA16Float() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Direct plane-texture bridge assertions are not stable on Simulator.")
        #else
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        let pixelBuffer = try makePixelBuffer(
            width: 8,
            height: 4,
            pixelFormatType: kCVPixelFormatType_422YpCbCr10BiPlanarFullRange,
            unavailableMessage: "422 10-bit bi-planar pixel buffer is unavailable in this environment."
        )

        let texture = try TextureLoader(with: pixelBuffer).texture

        XCTAssertEqual(texture.pixelFormat, .rgba16Float)
        XCTAssertEqual(texture.width, 8)
        XCTAssertEqual(texture.height, 4)
        XCTAssertNil(TextureOwnerRegistry.owner(for: texture))
        #endif
    }

    func testBiPlanarAttachmentCanPromoteDecodeStrategyTo709() throws {
        let pixelBuffer = try makePixelBuffer(
            width: 4,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            unavailableMessage: "Bi-planar pixel buffer is unavailable in this environment."
        )
        CVBufferSetAttachment(
            pixelBuffer,
            kCVImageBufferYCbCrMatrixKey,
            kCVImageBufferYCbCrMatrix_ITU_R_709_2,
            .shouldPropagate
        )
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()
        let contract = pixelBuffer.c7.contract

        let strategy = try XCTUnwrap(TextureLoader.makeYCbCrDecodeStrategy(for: pixelBuffer, bridgePlan: bridgePlan))

        XCTAssertEqual(contract.yCbCrMatrixAttachment, .ituR709_2)
        XCTAssertEqual(strategy.layout, .biPlanar)
        XCTAssertEqual(strategy.descriptor, "709VideoRange")
        XCTAssertEqual(strategy.conversionMatrix.values, Matrix3x3.Kernel.to709.values)
        XCTAssertEqual(strategy.conversionOffset.x, -16.0 / 255.0, accuracy: 0.0001)
    }

    func testBiPlanarFullRange709AttachmentUsesExplicitFullRangeMatrix() throws {
        let pixelBuffer = try makePixelBuffer(
            width: 4,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            unavailableMessage: "Bi-planar pixel buffer is unavailable in this environment."
        )
        CVBufferSetAttachment(
            pixelBuffer,
            kCVImageBufferYCbCrMatrixKey,
            kCVImageBufferYCbCrMatrix_ITU_R_709_2,
            .shouldPropagate
        )
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()

        let strategy = try XCTUnwrap(TextureLoader.makeYCbCrDecodeStrategy(for: pixelBuffer, bridgePlan: bridgePlan))

        XCTAssertEqual(strategy.descriptor, "709FullRange")
        XCTAssertEqual(strategy.matrixContract, .bt709FullRange)
        XCTAssertEqual(strategy.conversionMatrix.values, Matrix3x3.Kernel.to709FullRange.values)
        XCTAssertEqual(strategy.conversionOffset.x, 0, accuracy: 0.0001)
    }

    func testBiPlanarAttachmentCanPromoteDecodeStrategyTo2020() throws {
        let pixelBuffer = try makePixelBuffer(
            width: 4,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            unavailableMessage: "Bi-planar pixel buffer is unavailable in this environment."
        )
        if #available(iOS 14.0, macOS 11.0, tvOS 14.0, *) {
            CVBufferSetAttachment(
                pixelBuffer,
                kCVImageBufferYCbCrMatrixKey,
                kCVImageBufferYCbCrMatrix_ITU_R_2020,
                .shouldPropagate
            )
        } else {
            throw XCTSkip("BT.2020 attachments are unavailable on this platform.")
        }
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()
        let contract = pixelBuffer.c7.contract

        let strategy = try XCTUnwrap(TextureLoader.makeYCbCrDecodeStrategy(for: pixelBuffer, bridgePlan: bridgePlan))

        XCTAssertEqual(contract.yCbCrMatrixAttachment, .ituR2020)
        XCTAssertEqual(strategy.layout, .biPlanar)
        XCTAssertEqual(strategy.descriptor, "2020VideoRange")
        XCTAssertEqual(strategy.matrixContract, .bt2020VideoRange)
        XCTAssertEqual(strategy.conversionMatrix.values, Matrix3x3.Kernel.to2020.values)
        XCTAssertEqual(strategy.conversionOffset.x, -16.0 / 255.0, accuracy: 0.0001)
    }

    func testWideGamutAttachmentsPromoteDecodeDestinationToRGBA16Float() throws {
        let pixelBuffer = try makePixelBuffer(
            width: 4,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            unavailableMessage: "Bi-planar pixel buffer is unavailable in this environment."
        )
        CVBufferSetAttachment(
            pixelBuffer,
            kCVImageBufferColorPrimariesKey,
            kCVImageBufferColorPrimaries_P3_D65,
            .shouldPropagate
        )
        CVBufferSetAttachment(
            pixelBuffer,
            kCVImageBufferTransferFunctionKey,
            kCVImageBufferTransferFunction_sRGB,
            .shouldPropagate
        )
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()

        let strategy = try XCTUnwrap(TextureLoader.makeYCbCrDecodeStrategy(for: pixelBuffer, bridgePlan: bridgePlan))

        XCTAssertEqual(pixelBuffer.c7.contract.attachmentColorSpace?.gamut, .displayP3)
        XCTAssertEqual(strategy.destinationPixelFormat, .rgba16Float)
    }

    func testWideGamutBiPlanarTextureLoaderDecodesToRGBA16Float() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Direct plane-texture bridge assertions are not stable on Simulator.")
        #else
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        let pixelBuffer = try makePixelBuffer(
            width: 4,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            unavailableMessage: "Bi-planar pixel buffer is unavailable in this environment."
        )
        CVBufferSetAttachment(
            pixelBuffer,
            kCVImageBufferColorPrimariesKey,
            kCVImageBufferColorPrimaries_P3_D65,
            .shouldPropagate
        )
        CVBufferSetAttachment(
            pixelBuffer,
            kCVImageBufferTransferFunctionKey,
            kCVImageBufferTransferFunction_sRGB,
            .shouldPropagate
        )

        let texture = try TextureLoader(with: pixelBuffer).texture

        XCTAssertEqual(texture.pixelFormat, .rgba16Float)
        XCTAssertEqual(texture.width, 4)
        XCTAssertEqual(texture.height, 4)
        #endif
    }

    func testHDRAttachmentsPromoteDecodeDestinationToRGBA16Float() throws {
        let pixelBuffer = try makePixelBuffer(
            width: 4,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            unavailableMessage: "Bi-planar pixel buffer is unavailable in this environment."
        )
        if #available(iOS 14.0, macOS 11.0, tvOS 14.0, *) {
            CVBufferSetAttachment(
                pixelBuffer,
                kCVImageBufferColorPrimariesKey,
                kCVImageBufferColorPrimaries_ITU_R_2020,
                .shouldPropagate
            )
            CVBufferSetAttachment(
                pixelBuffer,
                kCVImageBufferTransferFunctionKey,
                kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ,
                .shouldPropagate
            )
        } else {
            throw XCTSkip("HDR attachments are unavailable on this platform.")
        }
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()

        let strategy = try XCTUnwrap(TextureLoader.makeYCbCrDecodeStrategy(for: pixelBuffer, bridgePlan: bridgePlan))

        XCTAssertEqual(pixelBuffer.c7.contract.attachmentColorSpace?.gamut, .ituR2020)
        XCTAssertEqual(pixelBuffer.c7.contract.attachmentColorSpace?.transferFunction, .perceptualQuantizer)
        XCTAssertEqual(strategy.destinationPixelFormat, .rgba16Float)
    }

    func testHDRBiPlanarTextureLoaderDecodesToRGBA16Float() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Direct plane-texture bridge assertions are not stable on Simulator.")
        #else
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        let pixelBuffer = try makePixelBuffer(
            width: 4,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            unavailableMessage: "Bi-planar pixel buffer is unavailable in this environment."
        )
        if #available(iOS 14.0, macOS 11.0, tvOS 14.0, *) {
            CVBufferSetAttachment(
                pixelBuffer,
                kCVImageBufferColorPrimariesKey,
                kCVImageBufferColorPrimaries_ITU_R_2020,
                .shouldPropagate
            )
            CVBufferSetAttachment(
                pixelBuffer,
                kCVImageBufferTransferFunctionKey,
                kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ,
                .shouldPropagate
            )
        } else {
            throw XCTSkip("HDR attachments are unavailable on this platform.")
        }

        let texture = try TextureLoader(with: pixelBuffer).texture

        XCTAssertEqual(texture.pixelFormat, .rgba16Float)
        XCTAssertEqual(texture.width, 4)
        XCTAssertEqual(texture.height, 4)
        #endif
    }

    func testTriPlanarFullRangeDecodeStrategyUsesTriPlanarLayout() throws {
        let pixelBuffer = try makePixelBuffer(
            width: 6,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr8PlanarFullRange,
            unavailableMessage: "Tri-planar pixel buffer is unavailable in this environment."
        )
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()

        let strategy = try XCTUnwrap(TextureLoader.makeYCbCrDecodeStrategy(for: pixelBuffer, bridgePlan: bridgePlan))

        XCTAssertEqual(strategy.layout, .triPlanar)
        XCTAssertEqual(strategy.descriptor, "601FullRange")
        XCTAssertEqual(strategy.conversionMatrix.values, Matrix3x3.Kernel.to601FullRange.values)
    }

    func testTriPlanarAttachmentCanPromoteFullRangeDecodeStrategyTo2020() throws {
        let pixelBuffer = try makePixelBuffer(
            width: 6,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr8PlanarFullRange,
            unavailableMessage: "Tri-planar pixel buffer is unavailable in this environment."
        )
        if #available(iOS 14.0, macOS 11.0, tvOS 14.0, *) {
            CVBufferSetAttachment(
                pixelBuffer,
                kCVImageBufferYCbCrMatrixKey,
                kCVImageBufferYCbCrMatrix_ITU_R_2020,
                .shouldPropagate
            )
        } else {
            throw XCTSkip("BT.2020 attachments are unavailable on this platform.")
        }
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()

        let strategy = try XCTUnwrap(TextureLoader.makeYCbCrDecodeStrategy(for: pixelBuffer, bridgePlan: bridgePlan))

        XCTAssertEqual(strategy.layout, .triPlanar)
        XCTAssertEqual(strategy.descriptor, "2020FullRange")
        XCTAssertEqual(strategy.matrixContract, .bt2020FullRange)
        XCTAssertEqual(strategy.conversionMatrix.values, Matrix3x3.Kernel.to2020FullRange.values)
        XCTAssertEqual(strategy.conversionOffset.x, 0, accuracy: 0.0001)
    }

    func testBiPlanarPixelBufferTextureSourceResolvesAllPlaneTextures() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Direct plane-texture bridge assertions are not stable on Simulator.")
        #else
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        let pixelBuffer = try makePixelBuffer(
            width: 4,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            unavailableMessage: "Bi-planar pixel buffer is unavailable in this environment."
        )

        let source = try TextureLoader.resolveTextureSource(with: pixelBuffer)

        XCTAssertEqual(source.bridgePlan.loadStrategy, .directPlaneTexture)
        XCTAssertTrue(source.bridgePlan.requiresColorConversion)
        XCTAssertTrue(source.requiresPlaneAwareDecoding)
        XCTAssertTrue(source.exposesAllDirectPlaneTextures)
        XCTAssertEqual(source.planeTextures.count, 2)
        XCTAssertEqual(source.retainedOwners.count, 3)
        XCTAssertEqual(source.primaryTexture.pixelFormat, .r8Unorm)
        XCTAssertEqual(source.planeTextures[0].pixelFormat, .r8Unorm)
        XCTAssertEqual(source.planeTextures[1].pixelFormat, .rg8Unorm)
        XCTAssertEqual(ObjectIdentifier(source.primaryTexture), ObjectIdentifier(source.planeTextures[0]))
        XCTAssertNil(TextureOwnerRegistry.owner(for: source.primaryTexture))
        XCTAssertTrue(source.retainedOwners.contains { $0 === pixelBuffer })
        #endif
    }

    func testTriPlanarPixelBufferTextureSourceResolvesAllPlaneTextures() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Direct plane-texture bridge assertions are not stable on Simulator.")
        #else
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        let pixelBuffer = try makePixelBuffer(
            width: 6,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr8PlanarFullRange,
            unavailableMessage: "Tri-planar pixel buffer is unavailable in this environment."
        )

        let source = try TextureLoader.resolveTextureSource(with: pixelBuffer)

        XCTAssertEqual(source.bridgePlan.loadStrategy, .directPlaneTexture)
        XCTAssertTrue(source.bridgePlan.requiresColorConversion)
        XCTAssertTrue(source.requiresPlaneAwareDecoding)
        XCTAssertTrue(source.exposesAllDirectPlaneTextures)
        XCTAssertEqual(source.planeTextures.count, 3)
        XCTAssertEqual(source.retainedOwners.count, 4)
        XCTAssertEqual(source.primaryTexture.pixelFormat, .r8Unorm)
        XCTAssertEqual(source.planeTextures[0].pixelFormat, .r8Unorm)
        XCTAssertEqual(source.planeTextures[1].pixelFormat, .r8Unorm)
        XCTAssertEqual(source.planeTextures[2].pixelFormat, .r8Unorm)
        XCTAssertEqual(ObjectIdentifier(source.primaryTexture), ObjectIdentifier(source.planeTextures[0]))
        XCTAssertNil(TextureOwnerRegistry.owner(for: source.primaryTexture))
        XCTAssertTrue(source.retainedOwners.contains { $0 === pixelBuffer })
        #endif
    }

    func testDecodedYCbCrTextureReleasesBridgeOwnersAfterMaterialization() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Direct plane-texture bridge assertions are not stable on Simulator.")
        #else
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        let pixelBuffer = try makePixelBuffer(
            width: 4,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            unavailableMessage: "Bi-planar pixel buffer is unavailable in this environment."
        )

        let texture = try TextureLoader(with: pixelBuffer).texture
        let owners = TextureOwnerRegistry.owners(for: texture)

        XCTAssertTrue(owners.isEmpty)
        #endif
    }

    func testDecodedTenBitYCbCrTextureReleasesBridgeOwnersAfterMaterialization() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Direct plane-texture bridge assertions are not stable on Simulator.")
        #else
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        let pixelBuffer = try makePixelBuffer(
            width: 8,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr10BiPlanarFullRange,
            unavailableMessage: "420 10-bit bi-planar pixel buffer is unavailable in this environment."
        )

        let texture = try TextureLoader(with: pixelBuffer).texture
        let owners = TextureOwnerRegistry.owners(for: texture)

        XCTAssertEqual(texture.pixelFormat, .rgba16Float)
        XCTAssertTrue(owners.isEmpty)
        #endif
    }

    func testSampleBufferTextureSourceRetainsPixelBufferBridgeOwnersOnly() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Direct plane-texture bridge assertions are not stable on Simulator.")
        #else
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        let pixelBuffer = try makePixelBuffer(
            width: 4,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            unavailableMessage: "Bi-planar pixel buffer is unavailable in this environment."
        )
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffer.")
            return
        }

        let source = try TextureLoader.resolveTextureSource(with: sampleBuffer)
        let owners = TextureOwnerRegistry.owners(for: source.primaryTexture)

        XCTAssertEqual(source.retainedOwners.count, 3)
        XCTAssertTrue(source.retainedOwners.contains { $0 === pixelBuffer })
        XCTAssertFalse(source.retainedOwners.contains { $0 === sampleBuffer })
        XCTAssertTrue(owners.isEmpty)
        #endif
    }

    func testDecodedSampleBufferTextureReleasesPixelBufferBridgeOwnersAfterMaterialization() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Direct plane-texture bridge assertions are not stable on Simulator.")
        #else
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        let pixelBuffer = try makePixelBuffer(
            width: 4,
            height: 4,
            pixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            unavailableMessage: "Bi-planar pixel buffer is unavailable in this environment."
        )
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffer.")
            return
        }

        let texture = try TextureLoader(with: sampleBuffer).texture
        let owners = TextureOwnerRegistry.owners(for: texture)

        XCTAssertTrue(owners.isEmpty)
        #endif
    }

    func testBGRAContainingPixelBufferTextureProducesVisibleCGImage() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: 2,
            kCVPixelBufferHeightKey: 2,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            2,
            2,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        guard let pixelBuffer else {
            XCTFail("Failed to create BGRA pixel buffer.")
            return
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            XCTFail("Pixel buffer has no base address.")
            return
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let rows = baseAddress.assumingMemoryBound(to: UInt8.self)
        for y in 0..<2 {
            for x in 0..<2 {
                let offset = y * bytesPerRow + x * 4
                rows[offset + 0] = 0
                rows[offset + 1] = 64
                rows[offset + 2] = 255
                rows[offset + 3] = 255
            }
        }

        var cache: CVMetalTextureCache?
        XCTAssertEqual(CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device!, nil, &cache), kCVReturnSuccess)
        guard let texture = pixelBuffer.c7.convert2MTLTexture(textureCache: cache, pixelFormat: .bgra8Unorm),
              let cgImage = texture.c7.toCGImage(colorSpace: CGColorSpaceCreateDeviceRGB()) else {
            XCTFail("Expected BGRA pixel buffer texture to produce a CGImage.")
            return
        }

        XCTAssertFalse(cgImageIsFullyTransparent(cgImage))
    }

    func testManagedTextureWrittenByGPUProducesVisibleCGImageOnMacOS() throws {
        #if os(macOS)
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        let queue = device!.makeCommandQueue()
        try XCTSkipIf(queue == nil, "Metal command queue is unavailable in this environment.")

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 2,
            height: 2,
            mipmapped: false
        )
        descriptor.storageMode = .managed
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device!.makeTexture(descriptor: descriptor),
              let commandBuffer = queue!.makeCommandBuffer(),
              let blit = commandBuffer.makeBlitCommandEncoder() else {
            XCTFail("Failed to create managed texture writeback fixtures.")
            return
        }

        var pixels: [UInt8] = [
            255, 0, 0, 255, 0, 255, 0, 255,
            0, 0, 255, 255, 255, 255, 0, 255
        ]
        guard let source = device!.makeBuffer(bytes: &pixels, length: pixels.count, options: .storageModeShared) else {
            XCTFail("Failed to create source pixel buffer.")
            return
        }
        blit.copy(
            from: source,
            sourceOffset: 0,
            sourceBytesPerRow: 8,
            sourceBytesPerImage: pixels.count,
            sourceSize: MTLSize(width: 2, height: 2, depth: 1),
            to: texture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        guard let cgImage = texture.c7.toCGImage(colorSpace: CGColorSpaceCreateDeviceRGB()) else {
            XCTFail("Expected managed texture readback to create a CGImage.")
            return
        }

        XCTAssertFalse(cgImageIsFullyTransparent(cgImage))
        #else
        throw XCTSkip("Managed texture CPU readback is a macOS-specific regression test.")
        #endif
    }

    func testPrivateTextureWrittenByGPUCanBeReadBackThroughStagingBuffer() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let queue = try XCTUnwrap(device.makeCommandQueue())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 2,
            height: 2,
            mipmapped: false
        )
        descriptor.storageMode = .private
        descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let commandBuffer = try XCTUnwrap(queue.makeCommandBuffer())
        let blit = try XCTUnwrap(commandBuffer.makeBlitCommandEncoder())
        let pixels: [UInt8] = [
            255, 0, 0, 255, 0, 255, 0, 255,
            0, 0, 255, 255, 255, 255, 0, 255
        ]
        let source = try XCTUnwrap(device.makeBuffer(bytes: pixels, length: pixels.count, options: .storageModeShared))
        blit.copy(
            from: source,
            sourceOffset: 0,
            sourceBytesPerRow: 8,
            sourceBytesPerImage: pixels.count,
            sourceSize: .init(width: 2, height: 2, depth: 1),
            to: texture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: .init(x: 0, y: 0, z: 0)
        )
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let readback = try XCTUnwrap(texture.c7.bytes())

        XCTAssertEqual(Array(readback), pixels)
    }

    func testReplacePackedBytesKeepsSmallRGBAUploadReadable() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(
            width: 2,
            height: 1,
            options: [
                .texturePixelFormat: MTLPixelFormat.rgba8Unorm
            ],
            identifier: "TextureReadbackTests.packedUpload"
        )
        let sourceBytes: [UInt8] = [
            0, 0, 0, 255,
            255, 255, 255, 255
        ]

        texture.c7.replacePackedBytes(
            region: MTLRegionMake2D(0, 0, 2, 1),
            bytes: sourceBytes,
            packedBytesPerRow: 8
        )

        let readback = try XCTUnwrap(texture.c7.bytes())
        XCTAssertEqual(Array(readback[0..<8]), sourceBytes)
    }

    private func cgImageIsFullyTransparent(_ image: CGImage) -> Bool {
        let width = image.width
        let height = image.height
        let rowBytes = width * 4
        var bytes = [UInt8](repeating: 0, count: rowBytes * height)
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: rowBytes,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return true
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 3, to: bytes.count, by: 4).allSatisfy { bytes[$0] == 0 }
    }

    private func makePixelBuffer(width: Int,
                                 height: Int,
                                 pixelFormatType: OSType,
                                 unavailableMessage: String) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: pixelFormatType,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            pixelFormatType,
            attributes as CFDictionary,
            &pixelBuffer
        )
        try XCTSkipIf(
            status != kCVReturnSuccess,
            "\(unavailableMessage) CVPixelBufferCreate status=\(status)."
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create pixel buffer.")
            throw XCTSkip()
        }
        return pixelBuffer
    }

    private func makeHalfFloatCGImage(colorSpaceName: CFString, pixels: [Float16]) throws -> CGImage {
        let data = pixels.withUnsafeBytes { Data($0) }
        let provider = try XCTUnwrap(CGDataProvider(data: data as CFData))
        let colorSpace = try XCTUnwrap(CGColorSpace(name: colorSpaceName))
        let bitmapInfo = CGBitmapInfo(rawValue:
            CGBitmapInfo.floatComponents.rawValue
                | CGBitmapInfo.byteOrder16Little.rawValue
                | CGImageAlphaInfo.premultipliedLast.rawValue
        )
        return try XCTUnwrap(CGImage(
            width: 1,
            height: 1,
            bitsPerComponent: 16,
            bitsPerPixel: 64,
            bytesPerRow: 8,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
    }

    private func makeEightBitCGImage(colorSpaceName: CFString) throws -> CGImage {
        let data = Data([191, 82, 31, 255])
        let provider = try XCTUnwrap(CGDataProvider(data: data as CFData))
        let colorSpace = try XCTUnwrap(CGColorSpace(name: colorSpaceName))
        return try XCTUnwrap(CGImage(
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
    }
}
