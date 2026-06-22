import XCTest
import Metal
import CoreVideo
import CoreMedia
@testable import Harbeth

final class PixelBufferOutputTests: XCTestCase {

    func testPixelBufferPoolDescriptorCreatesMetalCompatibleBuffers() throws {
        let descriptor = RenderPixelBufferDescriptor(
            width: 3,
            height: 2,
            minimumBufferCount: 2
        )
        let pool = try PixelBufferPool(descriptor: descriptor)
        let pixelBuffer = try pool.makePixelBuffer()

        XCTAssertEqual(descriptor.width, 3)
        XCTAssertEqual(descriptor.height, 2)
        XCTAssertTrue(descriptor.fingerprint.contains("size=3x2"))
        XCTAssertEqual(CVPixelBufferGetWidth(pixelBuffer), 3)
        XCTAssertEqual(CVPixelBufferGetHeight(pixelBuffer), 2)
        XCTAssertEqual(CVPixelBufferGetPixelFormatType(pixelBuffer), kCVPixelFormatType_32BGRA)
        XCTAssertNotNil(CVPixelBufferGetIOSurface(pixelBuffer))
    }

    func testRenderPixelBufferCreatesIndependentOutputBuffer() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [40, 60, 80, 255])
        let pool = try PixelBufferPool(width: 2, height: 2)

        let output = try HarbethIO(
            element: input,
            filter: C7Brightness(brightness: 0.1)
        ).renderPixelBuffer(pool: pool)

        XCTAssertEqual(CVPixelBufferGetWidth(output), 2)
        XCTAssertEqual(CVPixelBufferGetHeight(output), 2)
        XCTAssertEqual(CVPixelBufferGetPixelFormatType(output), kCVPixelFormatType_32BGRA)
    }

    func testRenderPixelBufferRespectsDerivativeOutputSize() throws {
        let input = try makeTexture(width: 4, height: 4, pixel: [120, 40, 20, 255])
        let derivative = ImageDerivativeSpec(
            name: "pixelBufferDerivative",
            renderIntent: .stable,
            sourceTier: .stableReusable,
            semantic: RenderProfile.stablePreview.defaultImageSemantic,
            outputSizePolicy: .exact(C7Size(width: 2, height: 3))
        )

        let output = try HarbethIO(
            element: input,
            filters: []
        ).renderPixelBuffer(profile: .stablePreview, derivative: derivative)

        XCTAssertEqual(CVPixelBufferGetWidth(output), 2)
        XCTAssertEqual(CVPixelBufferGetHeight(output), 3)
    }

    func testRenderPixelBufferCanMaterializeRGBA16FloatOutput() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [120, 40, 20, 255])

        let output = try HarbethIO(
            element: input,
            filters: []
        ).renderPixelBuffer(
            profile: .stablePreview,
            outputPixelFormat: .rgba16Float
        )

        XCTAssertEqual(CVPixelBufferGetWidth(output), 2)
        XCTAssertEqual(CVPixelBufferGetHeight(output), 2)
        XCTAssertEqual(CVPixelBufferGetPixelFormatType(output), kCVPixelFormatType_64RGBAHalf)
        XCTAssertEqual(output.c7.contract.colorModel, .rgba)
        XCTAssertEqual(output.c7.contract.nativeTextureLayout, .directSingleTexture)
        XCTAssertEqual(output.c7.contract.preferredMetalPixelFormat, .rgba16Float)
    }

    func testRenderPixelBufferPreservesSourceImageBufferColorAttachments() throws {
        let pixelBuffer = try makeBGRAPixelBuffer(width: 2, height: 2)
        CVBufferSetAttachment(
            pixelBuffer,
            kCVImageBufferYCbCrMatrixKey,
            kCVImageBufferYCbCrMatrix_ITU_R_709_2,
            .shouldPropagate
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

        let output = try HarbethIO(
            element: pixelBuffer,
            filter: C7Brightness(brightness: 0.1)
        ).renderPixelBuffer()

        XCTAssertEqual(output.c7.contract.colorPrimariesAttachment, .p3D65)
        XCTAssertEqual(output.c7.contract.transferFunctionAttachment, .sRGB)
        XCTAssertEqual(output.c7.contract.attachmentColorSpace?.gamut, .displayP3)
        XCTAssertEqual(output.c7.contract.attachmentColorSpace?.transferFunction, .sRGB)
        XCTAssertNil(output.c7.contract.yCbCrMatrixAttachment)
    }

    func testRenderPixelBufferRejectsUnsupportedPixelFormatContract() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [120, 40, 20, 255])

        XCTAssertThrowsError(
            try HarbethIO(
                element: input,
                filters: []
            ).renderPixelBuffer(
                profile: .stablePreview,
                outputPixelFormat: PixelFormatContract(pixelFormat: .rgba32Float, preservesInput: false)
            )
        ) { error in
            guard case .configurationInvalid(let message)? = error.asHarbethError else {
                return XCTFail("Expected configurationInvalid, got \(error)")
            }
            XCTAssertTrue(message.contains("does not support"))
        }
    }

    func testBGRAPixelBufferContractPrefersDirectSingleTextureBridge() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: 4,
            kCVPixelBufferHeightKey: 3,
            kCVPixelBufferMetalCompatibilityKey: true
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(kCFAllocatorDefault, 4, 3, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &pixelBuffer),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create BGRA pixel buffer.")
            return
        }

        let contract = pixelBuffer.c7.contract
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()

        XCTAssertFalse(contract.planar)
        XCTAssertEqual(contract.planeCount, 1)
        XCTAssertEqual(contract.colorModel, .rgba)
        XCTAssertEqual(contract.nativeTextureLayout, .directSingleTexture)
        XCTAssertEqual(contract.planes.first?.metalPixelFormat, .bgra8Unorm)
        XCTAssertEqual(bridgePlan.loadStrategy, .directMetalTexture)
        XCTAssertTrue(bridgePlan.preservesOwnerReference)
        XCTAssertEqual(bridgePlan.planes.count, 1)
        XCTAssertEqual(bridgePlan.planes.first?.conversionStrategy, .directMetalTexture)
        XCTAssertTrue(bridgePlan.planes.first?.preservesOwnerReference ?? false)
    }

    func testRGBA16FloatPixelBufferContractPrefersDirectSingleTextureBridge() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_64RGBAHalf,
            kCVPixelBufferWidthKey: 4,
            kCVPixelBufferHeightKey: 3,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(kCFAllocatorDefault, 4, 3, kCVPixelFormatType_64RGBAHalf, attributes as CFDictionary, &pixelBuffer),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create RGBA16F pixel buffer.")
            return
        }

        let contract = pixelBuffer.c7.contract
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()

        XCTAssertFalse(contract.planar)
        XCTAssertEqual(contract.colorModel, .rgba)
        XCTAssertEqual(contract.nativeTextureLayout, .directSingleTexture)
        XCTAssertEqual(contract.preferredMetalPixelFormat, .rgba16Float)
        XCTAssertEqual(bridgePlan.loadStrategy, .directMetalTexture)
        XCTAssertEqual(bridgePlan.planes.first?.metalPixelFormat, .rgba16Float)
    }

    func testPixelBufferCopyCompatibilityRejectsPixelFormatMismatch() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_64RGBAHalf,
            kCVPixelBufferWidthKey: 2,
            kCVPixelBufferHeightKey: 2,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(kCFAllocatorDefault, 2, 2, kCVPixelFormatType_64RGBAHalf, attributes as CFDictionary, &pixelBuffer),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create RGBA16F pixel buffer.")
            return
        }
        let texture = try makeTexture(width: 2, height: 2, pixel: [120, 40, 20, 255])

        XCTAssertFalse(pixelBuffer.c7.canCopyTextureData(from: texture))
        let output = try HarbethIO(element: pixelBuffer, filter: C7Brightness(brightness: 0.1)).output() as CVPixelBuffer
        XCTAssertEqual(CVPixelBufferGetPixelFormatType(output), kCVPixelFormatType_64RGBAHalf)
    }

    func testBiPlanarPixelBufferContractPrefersDirectPlaneTopLevelAndDirectPlaneBridge() throws {
        let pixelBuffer = try makeBiPlanarPixelBuffer()

        let contract = pixelBuffer.c7.contract
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()

        XCTAssertTrue(contract.planar)
        XCTAssertEqual(contract.planeCount, 2)
        XCTAssertEqual(contract.colorModel, .yCbCrBiPlanar)
        XCTAssertEqual(contract.nativeTextureLayout, .planeTextures)
        XCTAssertEqual(contract.planes[0].width, 4)
        XCTAssertEqual(contract.planes[0].height, 4)
        XCTAssertEqual(contract.planes[0].metalPixelFormat, .r8Unorm)
        XCTAssertEqual(contract.planes[1].width, 2)
        XCTAssertEqual(contract.planes[1].height, 2)
        XCTAssertEqual(contract.planes[1].metalPixelFormat, .rg8Unorm)
        XCTAssertTrue(contract.requiresYCbCrConversion)
        XCTAssertTrue(contract.supportsDirectPlaneTextures)
        XCTAssertEqual(bridgePlan.loadStrategy, .directPlaneTexture)
        XCTAssertTrue(bridgePlan.preservesOwnerReference)
        XCTAssertTrue(bridgePlan.requiresColorConversion)
        XCTAssertEqual(bridgePlan.directPlaneBridgeCount, 2)
        XCTAssertTrue(bridgePlan.supportsDirectPlaneTextures)
        XCTAssertEqual(bridgePlan.primaryDirectPlane?.index, 0)
        XCTAssertEqual(bridgePlan.primaryDirectPlane?.metalPixelFormat, .r8Unorm)
        XCTAssertEqual(bridgePlan.planes.count, 2)
        XCTAssertEqual(bridgePlan.planes[0].conversionStrategy, .directMetalTexture)
        XCTAssertTrue(bridgePlan.planes[0].preservesOwnerReference)
        XCTAssertEqual(bridgePlan.planes[1].metalPixelFormat, .rg8Unorm)
        XCTAssertEqual(bridgePlan.planes[1].conversionStrategy, .directMetalTexture)
        XCTAssertTrue(bridgePlan.planes[1].preservesOwnerReference)
        XCTAssertTrue(bridgePlan.fingerprint.contains("load=directPlaneTexture"))
        XCTAssertTrue(bridgePlan.fingerprint.contains("plane=0|metal=\(MTLPixelFormat.r8Unorm.rawValue)|strategy=directMetalTexture|owner=1"))
        XCTAssertTrue(bridgePlan.fingerprint.contains("plane=1|metal=\(MTLPixelFormat.rg8Unorm.rawValue)|strategy=directMetalTexture|owner=1"))
    }

    func testBiPlanarPixelBufferContractTracksYCbCrMatrixAttachment() throws {
        let pixelBuffer = try makeBiPlanarPixelBuffer()
        CVBufferSetAttachment(
            pixelBuffer,
            kCVImageBufferYCbCrMatrixKey,
            kCVImageBufferYCbCrMatrix_ITU_R_709_2,
            .shouldPropagate
        )

        let contract = pixelBuffer.c7.contract

        XCTAssertEqual(contract.yCbCrMatrixAttachment, .ituR709_2)
        XCTAssertTrue(contract.fingerprint.contains("ycbcrAttachment=ituR709_2"))
    }

    func testBiPlanarPixelBufferContractTracksColorPrimariesAndTransferAttachments() throws {
        let pixelBuffer = try makeBiPlanarPixelBuffer()
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

        let contract = pixelBuffer.c7.contract

        XCTAssertEqual(contract.colorPrimariesAttachment, .p3D65)
        XCTAssertEqual(contract.transferFunctionAttachment, .sRGB)
        XCTAssertEqual(contract.attachmentColorSpace?.gamut, .displayP3)
        XCTAssertEqual(contract.attachmentColorSpace?.transferFunction, .sRGB)
        XCTAssertTrue(contract.fingerprint.contains("primaries=p3D65"))
        XCTAssertTrue(contract.fingerprint.contains("transferAttachment=sRGB"))
    }

    func testBiPlanarPixelBufferContractCanDeriveColorSpaceFromYCbCrMatrixAndTransfer() throws {
        let pixelBuffer = try makeBiPlanarPixelBuffer()
        if #available(iOS 14.0, macOS 11.0, tvOS 14.0, *) {
            CVBufferSetAttachment(
                pixelBuffer,
                kCVImageBufferYCbCrMatrixKey,
                kCVImageBufferYCbCrMatrix_ITU_R_2020,
                .shouldPropagate
            )
            CVBufferSetAttachment(
                pixelBuffer,
                kCVImageBufferTransferFunctionKey,
                kCVImageBufferTransferFunction_ITU_R_2100_HLG,
                .shouldPropagate
            )
        } else {
            throw XCTSkip("BT.2020 / HLG attachments are unavailable on this platform.")
        }

        let contract = pixelBuffer.c7.contract

        XCTAssertNil(contract.colorPrimariesAttachment)
        XCTAssertEqual(contract.yCbCrMatrixAttachment, .ituR2020)
        XCTAssertEqual(contract.transferFunctionAttachment, .ituR2100HLG)
        XCTAssertEqual(contract.attachmentColorSpace?.gamut, .ituR2020)
        XCTAssertEqual(contract.attachmentColorSpace?.transferFunction, .hybridLogGamma)
        XCTAssertEqual(contract.attachmentColorSpace?.name, "ituR2020+ituR2100HLG")
    }

    func testSampleBufferContractTracksFrameBridgeMetadata() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: 4,
            kCVPixelBufferHeightKey: 4,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(kCFAllocatorDefault, 4, 4, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &pixelBuffer),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create pixel buffer.")
            return
        }
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffer.")
            return
        }

        let contract = sampleBuffer.c7.contract

        XCTAssertEqual(contract.pixelBufferContract?.colorModel, .rgba)
        XCTAssertEqual(contract.frameContract.orientation, .up)
        XCTAssertTrue(contract.frameContract.ownerRetained)
        XCTAssertEqual(contract.frameContract.conversionStrategy, .directMetalTexture)
        XCTAssertEqual(contract.frameContract.directPlaneBridgeCount, 1)
        XCTAssertFalse(contract.frameContract.supportsDirectPlaneTextures)
        XCTAssertTrue(contract.fingerprint.contains("frame={"))
    }

    func testBiPlanarSampleBufferContractExposesDirectPlaneBridgeMetadata() throws {
        let pixelBuffer = try makeBiPlanarPixelBuffer()
        CVBufferSetAttachment(
            pixelBuffer,
            kCVImageBufferYCbCrMatrixKey,
            kCVImageBufferYCbCrMatrix_ITU_R_709_2,
            .shouldPropagate
        )
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create bi-planar sample buffer.")
            return
        }

        let contract = sampleBuffer.c7.contract

        XCTAssertEqual(contract.pixelBufferContract?.colorModel, .yCbCrBiPlanar)
        XCTAssertEqual(contract.pixelBufferContract?.yCbCrMatrixAttachment, .ituR709_2)
        XCTAssertEqual(contract.frameContract.conversionStrategy, .directPlaneTexture)
        XCTAssertTrue(contract.frameContract.ownerRetained)
        XCTAssertEqual(contract.frameContract.directPlaneBridgeCount, 2)
        XCTAssertTrue(contract.frameContract.supportsDirectPlaneTextures)
        XCTAssertTrue(contract.fingerprint.contains("ycbcrAttachment=ituR709_2"))
        XCTAssertTrue(contract.fingerprint.contains("directPlanes=2"))
    }

    func testTriPlanarPixelBufferContractPrefersDirectPlaneTopLevelAndThreePlaneBridge() throws {
        let pixelBuffer = try makeTriPlanarPixelBuffer()

        let contract = pixelBuffer.c7.contract
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()

        XCTAssertTrue(contract.planar)
        XCTAssertEqual(contract.colorModel, .yCbCrTriPlanar)
        XCTAssertEqual(contract.planeCount, 3)
        XCTAssertEqual(contract.nativeTextureLayout, .planeTextures)
        XCTAssertTrue(contract.requiresYCbCrConversion)
        XCTAssertTrue(contract.supportsDirectPlaneTextures)
        XCTAssertEqual(contract.preferredMetalPixelFormat, .r8Unorm)
        XCTAssertEqual(contract.planes[0].width, 6)
        XCTAssertEqual(contract.planes[0].height, 4)
        XCTAssertEqual(contract.planes[0].metalPixelFormat, .r8Unorm)
        XCTAssertEqual(contract.planes[1].width, 3)
        XCTAssertEqual(contract.planes[1].height, 2)
        XCTAssertEqual(contract.planes[1].metalPixelFormat, .r8Unorm)
        XCTAssertEqual(contract.planes[2].width, 3)
        XCTAssertEqual(contract.planes[2].height, 2)
        XCTAssertEqual(contract.planes[2].metalPixelFormat, .r8Unorm)

        XCTAssertEqual(bridgePlan.loadStrategy, .directPlaneTexture)
        XCTAssertTrue(bridgePlan.preservesOwnerReference)
        XCTAssertTrue(bridgePlan.requiresColorConversion)
        XCTAssertEqual(bridgePlan.directPlaneBridgeCount, 3)
        XCTAssertTrue(bridgePlan.supportsDirectPlaneTextures)
        XCTAssertEqual(bridgePlan.primaryDirectPlane?.index, 0)
        XCTAssertEqual(bridgePlan.primaryDirectPlane?.metalPixelFormat, .r8Unorm)
        XCTAssertEqual(bridgePlan.planes.count, 3)
        XCTAssertEqual(bridgePlan.planes[0].metalPixelFormat, .r8Unorm)
        XCTAssertEqual(bridgePlan.planes[0].conversionStrategy, .directMetalTexture)
        XCTAssertTrue(bridgePlan.planes[0].preservesOwnerReference)
        XCTAssertEqual(bridgePlan.planes[1].metalPixelFormat, .r8Unorm)
        XCTAssertEqual(bridgePlan.planes[1].conversionStrategy, .directMetalTexture)
        XCTAssertTrue(bridgePlan.planes[1].preservesOwnerReference)
        XCTAssertEqual(bridgePlan.planes[2].metalPixelFormat, .r8Unorm)
        XCTAssertEqual(bridgePlan.planes[2].conversionStrategy, .directMetalTexture)
        XCTAssertTrue(bridgePlan.planes[2].preservesOwnerReference)
        XCTAssertTrue(bridgePlan.fingerprint.contains("load=directPlaneTexture"))
        XCTAssertTrue(bridgePlan.fingerprint.contains("plane=0|metal=\(MTLPixelFormat.r8Unorm.rawValue)|strategy=directMetalTexture|owner=1"))
        XCTAssertTrue(bridgePlan.fingerprint.contains("plane=1|metal=\(MTLPixelFormat.r8Unorm.rawValue)|strategy=directMetalTexture|owner=1"))
        XCTAssertTrue(bridgePlan.fingerprint.contains("plane=2|metal=\(MTLPixelFormat.r8Unorm.rawValue)|strategy=directMetalTexture|owner=1"))
    }

    func testTriPlanarSampleBufferContractExposesDirectPlaneBridgeMetadata() throws {
        let pixelBuffer = try makeTriPlanarPixelBuffer()
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create tri-planar sample buffer.")
            return
        }

        let contract = sampleBuffer.c7.contract

        XCTAssertEqual(contract.pixelBufferContract?.colorModel, .yCbCrTriPlanar)
        XCTAssertEqual(contract.frameContract.conversionStrategy, .directPlaneTexture)
        XCTAssertTrue(contract.frameContract.ownerRetained)
        XCTAssertEqual(contract.frameContract.directPlaneBridgeCount, 3)
        XCTAssertTrue(contract.frameContract.supportsDirectPlaneTextures)
        XCTAssertTrue(contract.fingerprint.contains("directPlanes=3"))
    }

    func testBiPlanarPixelBufferCanRenderThroughTextureLoader() throws {
        let pixelBuffer = try makeBiPlanarPixelBuffer()

        let output: MTLTexture = try HarbethIO(
            element: pixelBuffer,
            filter: C7Brightness(brightness: 0.1)
        ).renderTexture()

        XCTAssertEqual(output.width, 4)
        XCTAssertEqual(output.height, 4)
    }

    func testRenderRequestTracksPixelBufferSourceContract() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: 4,
            kCVPixelBufferHeightKey: 3,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(kCFAllocatorDefault, 4, 3, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &pixelBuffer),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create BGRA pixel buffer.")
            return
        }

        let request = try HarbethIO(element: pixelBuffer, filter: C7Brightness(brightness: 0.1))
            .makeRenderRequest(profile: .stablePreview)
        let renderRecipe = try XCTUnwrap(request.renderRecipe)

        XCTAssertEqual(request.source.kind, "pixelBuffer")
        XCTAssertEqual(request.source.cachePolicy, .persistent)
        XCTAssertEqual(request.compilationSource, .filtersPrimitive)
        XCTAssertEqual(request.source.pixelBufferContract?.colorModel, .rgba)
        XCTAssertEqual(request.source.pixelBufferBridgePlan?.loadStrategy, .directMetalTexture)
        XCTAssertEqual(request.source.pixelBufferBridgePolicy, .directTexturePassthrough)
        XCTAssertNil(request.source.yCbCrDecodeContract)
        XCTAssertTrue(request.source.fingerprint.contains("bridge={"))
        XCTAssertTrue(request.source.fingerprint.contains("bridgePolicy=directTexturePassthrough"))
        XCTAssertEqual(renderRecipe.source.kind, "pixelBuffer")
        XCTAssertEqual(renderRecipe.source.pixelBufferContract?.planeCount, 1)
        XCTAssertEqual(renderRecipe.alphaType, .premultiplied)
        XCTAssertEqual(renderRecipe.orientation, .up)
    }

    func testRenderDiagnosticsTracksBiPlanarPixelBufferInputConversions() throws {
        let pixelBuffer = try makeBiPlanarPixelBuffer()
        let request = try HarbethIO(element: pixelBuffer, filter: C7Brightness(brightness: 0.0))
            .makeRenderRequest(profile: .stablePreview)
        XCTAssertEqual(request.source.yCbCrDecodeContract?.layout, .biPlanar)
        XCTAssertEqual(request.source.yCbCrDecodeContract?.matrix, .bt601FullRange)
        XCTAssertEqual(request.source.yCbCrDecodeContract?.componentBitDepth, 8)
        XCTAssertEqual(request.source.pixelBufferBridgePolicy, .directPlaneDecodeToRGBA)
        XCTAssertTrue(request.source.fingerprint.contains("ycbcrDecode={layout=biPlanar|matrix=bt601FullRange|bitDepth=8"))
        XCTAssertTrue(request.source.fingerprint.contains("bridgePolicy=directPlaneDecodeToRGBA"))

        let diagnostics = try HarbethIO(element: pixelBuffer, filter: C7Brightness(brightness: 0.0)).renderDiagnostics()

        XCTAssertEqual(diagnostics.inputColorConversionCount, 1)
        XCTAssertEqual(diagnostics.inputPixelFormatConversionCount, 1)
        XCTAssertEqual(diagnostics.inputAlphaConversionCount, 0)
        XCTAssertEqual(diagnostics.inputDirectPlaneBridgeCount, 2)
        XCTAssertEqual(diagnostics.inputBridgePolicy, .directPlaneDecodeToRGBA)
        XCTAssertEqual(diagnostics.inputYCbCrDecodeContract?.layout, .biPlanar)
        XCTAssertEqual(diagnostics.inputYCbCrDecodeContract?.matrix, .bt601FullRange)
        XCTAssertEqual(diagnostics.inputYCbCrDecodeContract?.componentBitDepth, 8)
        XCTAssertEqual(diagnostics.colorConversionCount, 0)
        XCTAssertEqual(diagnostics.pixelFormatConversionCount, 0)
        XCTAssertTrue(diagnostics.summary.contains("inputColorConversions=1"))
        XCTAssertTrue(diagnostics.summary.contains("inputPixelFormatConversions=1"))
        XCTAssertTrue(diagnostics.summary.contains("inputDirectPlanes=2"))
        XCTAssertTrue(diagnostics.summary.contains("inputBridgePolicy=directPlaneDecodeToRGBA"))
        XCTAssertTrue(diagnostics.summary.contains("inputYCbCrDecode=layout=biPlanar|matrix=bt601FullRange|bitDepth=8"))
    }

    func testRenderDiagnosticsTracksTriPlanarPixelBufferInputConversions() throws {
        let pixelBuffer = try makeTriPlanarPixelBuffer(width: 6, height: 4)

        let diagnostics = try HarbethIO(element: pixelBuffer, filter: C7Brightness(brightness: 0.0)).renderDiagnostics()

        XCTAssertEqual(diagnostics.inputColorConversionCount, 1)
        XCTAssertEqual(diagnostics.inputPixelFormatConversionCount, 1)
        XCTAssertEqual(diagnostics.inputAlphaConversionCount, 0)
        XCTAssertEqual(diagnostics.inputDirectPlaneBridgeCount, 3)
        XCTAssertEqual(diagnostics.inputBridgePolicy, .directPlaneDecodeToRGBA)
        XCTAssertEqual(diagnostics.inputYCbCrDecodeContract?.layout, .triPlanar)
        XCTAssertEqual(diagnostics.inputYCbCrDecodeContract?.matrix, .bt601FullRange)
        XCTAssertEqual(diagnostics.inputYCbCrDecodeContract?.componentBitDepth, 8)
        XCTAssertEqual(diagnostics.colorConversionCount, 0)
        XCTAssertEqual(diagnostics.pixelFormatConversionCount, 0)
        XCTAssertTrue(diagnostics.summary.contains("inputColorConversions=1"))
        XCTAssertTrue(diagnostics.summary.contains("inputPixelFormatConversions=1"))
        XCTAssertTrue(diagnostics.summary.contains("inputDirectPlanes=3"))
        XCTAssertTrue(diagnostics.summary.contains("inputBridgePolicy=directPlaneDecodeToRGBA"))
        XCTAssertTrue(diagnostics.summary.contains("inputYCbCrDecode=layout=triPlanar|matrix=bt601FullRange"))
    }

    func testRenderDiagnosticsTracksBGRAPixelBufferNoInputConversions() throws {
        let pixelBuffer = try makeBGRAPixelBuffer(width: 3, height: 2)

        let diagnostics = try HarbethIO(element: pixelBuffer).renderDiagnostics()

        XCTAssertEqual(diagnostics.inputColorConversionCount, 0)
        XCTAssertEqual(diagnostics.inputPixelFormatConversionCount, 0)
        XCTAssertEqual(diagnostics.inputAlphaConversionCount, 0)
        XCTAssertEqual(diagnostics.inputDirectPlaneBridgeCount, 1)
        XCTAssertEqual(diagnostics.inputBridgePolicy, .directTexturePassthrough)
        XCTAssertNil(diagnostics.inputYCbCrDecodeContract)
        XCTAssertEqual(diagnostics.inputPixelPrecision, .unorm8)
        XCTAssertFalse(diagnostics.inputIsHDRFriendly)
        XCTAssertTrue(diagnostics.summary.contains("inputColorConversions=0"))
        XCTAssertTrue(diagnostics.summary.contains("inputPixelFormatConversions=0"))
        XCTAssertTrue(diagnostics.summary.contains("inputDirectPlanes=1"))
        XCTAssertTrue(diagnostics.summary.contains("inputBridgePolicy=directTexturePassthrough"))
    }

    func testRenderDiagnosticsTracksHalfFloatPixelBufferInputPrecision() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_64RGBAHalf,
            kCVPixelBufferWidthKey: 4,
            kCVPixelBufferHeightKey: 4,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                4,
                4,
                kCVPixelFormatType_64RGBAHalf,
                attributes as CFDictionary,
                &pixelBuffer
            ),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create RGBA16F pixel buffer.")
            return
        }

        let diagnostics = try HarbethIO(element: pixelBuffer).renderDiagnostics()

        XCTAssertEqual(diagnostics.inputPixelFormat, .init(pixelFormat: .rgba16Float, preservesInput: true))
        XCTAssertEqual(diagnostics.inputPixelPrecision, .float16)
        XCTAssertTrue(diagnostics.inputIsHighPrecision)
        XCTAssertTrue(diagnostics.inputIsHDRFriendly)
        XCTAssertTrue(diagnostics.summary.contains("inputPixel=rgba16Float"))
        XCTAssertTrue(diagnostics.summary.contains("inputPixelPrecision=float16"))
        XCTAssertTrue(diagnostics.summary.contains("inputHDRFriendly=1"))
        XCTAssertTrue(diagnostics.optimizationPlan.prewarmReservations.isEmpty)
        XCTAssertTrue(diagnostics.optimizationPlan.decisions.contains("singleStageNoOptimizationNeeded"))
    }

    func testRenderDiagnosticsTracksSampleBufferBiPlanarInputConversions() throws {
        let pixelBuffer = try makeBiPlanarPixelBuffer()
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create bi-planar sample buffer.")
            return
        }
        let request = try HarbethIO(element: sampleBuffer, filter: C7Brightness(brightness: 0.0))
            .makeRenderRequest(profile: .stablePreview)
        XCTAssertEqual(request.source.yCbCrDecodeContract?.layout, .biPlanar)
        XCTAssertEqual(request.source.yCbCrDecodeContract?.matrix, .bt601FullRange)
        XCTAssertEqual(request.source.pixelBufferBridgePolicy, .directPlaneDecodeToRGBA)

        let diagnostics = try HarbethIO(element: sampleBuffer, filter: C7Brightness(brightness: 0.0)).renderDiagnostics()

        XCTAssertEqual(diagnostics.inputColorConversionCount, 1)
        XCTAssertEqual(diagnostics.inputPixelFormatConversionCount, 1)
        XCTAssertEqual(diagnostics.inputAlphaConversionCount, 0)
        XCTAssertEqual(diagnostics.inputDirectPlaneBridgeCount, 2)
        XCTAssertEqual(diagnostics.inputBridgePolicy, .directPlaneDecodeToRGBA)
        XCTAssertEqual(diagnostics.inputYCbCrDecodeContract?.layout, .biPlanar)
        XCTAssertEqual(diagnostics.sourceKind, "sampleBuffer")
        XCTAssertTrue(diagnostics.summary.contains("origin=sampleBuffer"))
        XCTAssertTrue(diagnostics.summary.contains("inputColorConversions=1"))
        XCTAssertTrue(diagnostics.summary.contains("inputPixelFormatConversions=1"))
        XCTAssertTrue(diagnostics.summary.contains("inputDirectPlanes=2"))
        XCTAssertTrue(diagnostics.summary.contains("inputBridgePolicy=directPlaneDecodeToRGBA"))
        XCTAssertTrue(diagnostics.summary.contains("inputYCbCrDecode=layout=biPlanar"))
    }

    func testRenderDiagnosticsTracksSampleBufferRGBAInputNoInputConversions() throws {
        let pixelBuffer = try makeBGRAPixelBuffer(width: 4, height: 4)
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create RGBA sample buffer.")
            return
        }

        let diagnostics = try HarbethIO(element: sampleBuffer).renderDiagnostics()

        XCTAssertEqual(diagnostics.inputColorConversionCount, 0)
        XCTAssertEqual(diagnostics.inputPixelFormatConversionCount, 0)
        XCTAssertEqual(diagnostics.inputAlphaConversionCount, 0)
        XCTAssertEqual(diagnostics.inputDirectPlaneBridgeCount, 1)
        XCTAssertEqual(diagnostics.inputBridgePolicy, .directTexturePassthrough)
        XCTAssertEqual(diagnostics.sourceKind, "sampleBuffer")
        XCTAssertTrue(diagnostics.summary.contains("origin=sampleBuffer"))
        XCTAssertTrue(diagnostics.summary.contains("inputColorConversions=0"))
        XCTAssertTrue(diagnostics.summary.contains("inputPixelFormatConversions=0"))
        XCTAssertTrue(diagnostics.summary.contains("inputBridgePolicy=directTexturePassthrough"))
        XCTAssertTrue(diagnostics.summary.contains("inputDirectPlanes=1"))
    }

    func testNodeRenderRecipeTracksSampleBufferSourceContract() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: 2,
            kCVPixelBufferHeightKey: 2,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(kCFAllocatorDefault, 2, 2, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &pixelBuffer),
            kCVReturnSuccess
        )
        guard let pixelBuffer,
              var sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffer.")
            return
        }
        sampleBuffer.c7.isNotSync = true

        let node = ImageNode.sampleBuffer(sampleBuffer)
            .applying(C7Brightness(brightness: 0.1))
        let request = try node.makeRenderRequest(profile: .stablePreview)
        let renderRecipe = try XCTUnwrap(request.renderRecipe)

        XCTAssertEqual(request.source.kind, "sampleBuffer")
        XCTAssertEqual(request.source.sampleBufferContract?.attachments.notSync, true)
        XCTAssertEqual(request.source.sampleBufferContract?.pixelBufferContract?.planeCount, 1)
        XCTAssertTrue(request.source.fingerprint.contains("sampleBuffer={"))
        XCTAssertEqual(renderRecipe.source.kind, "sampleBuffer")
        XCTAssertEqual(renderRecipe.source.sampleBufferContract?.attachments.notSync, true)
        XCTAssertEqual(renderRecipe.alphaType, .premultiplied)
        XCTAssertEqual(renderRecipe.orientation, .up)
        XCTAssertEqual(request.diagnostics.compilationSource, .nodeGraph)
    }

    func testImageNodeEditingPreservesOriginalSampleBufferSourceContract() throws {
        let pixelBuffer = try makeBiPlanarPixelBuffer()
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create bi-planar sample buffer.")
            return
        }

        let node = ImageNode
            .sampleBuffer(sampleBuffer)
            .editing(
                EditRecipe(
                    geometry: ImageTransformRecipe(
                        targetSize: CGSize(width: 2, height: 2),
                        aspectPolicy: .fit
                    )
                )
            )
            .applying(C7Brightness(brightness: 0.1))

        let request = try node.makeRenderRequest(profile: .stablePreview)
        let renderRecipe = try XCTUnwrap(request.renderRecipe)

        XCTAssertEqual(request.source.kind, "sampleBuffer")
        XCTAssertEqual(request.source.yCbCrDecodeContract?.layout, .biPlanar)
        XCTAssertEqual(renderRecipe.source.kind, "sampleBuffer")
        XCTAssertEqual(renderRecipe.source.yCbCrDecodeContract?.layout, .biPlanar)
        XCTAssertEqual(renderRecipe.source.sampleBufferContract?.pixelBufferContract?.planeCount, 2)
        XCTAssertEqual(request.diagnostics.compilationSource, .editRecipe)
    }

    func testFilteringSampleBufferPreservesTimingAndAttachments() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: 2,
            kCVPixelBufferHeightKey: 2,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(kCFAllocatorDefault, 2, 2, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &pixelBuffer),
            kCVReturnSuccess
        )
        guard let pixelBuffer,
              var sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffer.")
            return
        }
        sampleBuffer.c7.isNotSync = true

        let output: CMSampleBuffer = try HarbethIO(
            element: sampleBuffer,
            filter: C7Brightness(brightness: 0.1)
        ).output()

        XCTAssertEqual(output.c7.presentationTimeStamp, sampleBuffer.c7.presentationTimeStamp)
        XCTAssertEqual(output.c7.decodeTimeStamp, sampleBuffer.c7.decodeTimeStamp)
        XCTAssertEqual(output.c7.duration, sampleBuffer.c7.duration)
        XCTAssertEqual(output.c7.isNotSync, true)
        XCTAssertEqual(output.c7.contract.attachments.notSync, true)
        XCTAssertEqual(output.c7.contract.pixelBufferContract?.planeCount, 1)
    }

    func testToCMSampleBufferReferenceCopiesImageBufferColorAttachments() throws {
        let referencePixelBuffer = try makeBGRAPixelBuffer(width: 2, height: 2)
        CVBufferSetAttachment(
            referencePixelBuffer,
            kCVImageBufferColorPrimariesKey,
            kCVImageBufferColorPrimaries_P3_D65,
            .shouldPropagate
        )
        CVBufferSetAttachment(
            referencePixelBuffer,
            kCVImageBufferTransferFunctionKey,
            kCVImageBufferTransferFunction_sRGB,
            .shouldPropagate
        )
        guard let referenceSampleBuffer = referencePixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create reference sample buffer.")
            return
        }

        let outputPixelBuffer = try makeBGRAPixelBuffer(width: 2, height: 2)
        XCTAssertNil(outputPixelBuffer.c7.contract.colorPrimariesAttachment)
        XCTAssertNil(outputPixelBuffer.c7.contract.transferFunctionAttachment)

        guard let derivedSampleBuffer = outputPixelBuffer.c7.toCMSampleBuffer(reference: referenceSampleBuffer) else {
            XCTFail("Failed to create derived sample buffer.")
            return
        }

        XCTAssertEqual(outputPixelBuffer.c7.contract.colorPrimariesAttachment, .p3D65)
        XCTAssertEqual(outputPixelBuffer.c7.contract.transferFunctionAttachment, .sRGB)
        XCTAssertEqual(derivedSampleBuffer.c7.contract.pixelBufferContract?.colorPrimariesAttachment, .p3D65)
        XCTAssertEqual(derivedSampleBuffer.c7.contract.pixelBufferContract?.transferFunctionAttachment, .sRGB)
    }

    func testRenderPixelBufferPreservesSourceSampleBufferColorAttachments() throws {
        let pixelBuffer = try makeBGRAPixelBuffer(width: 2, height: 2)
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
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffer.")
            return
        }

        let output = try HarbethIO(
            element: sampleBuffer,
            filter: C7Brightness(brightness: 0.1)
        ).renderPixelBuffer()

        XCTAssertEqual(output.c7.contract.colorPrimariesAttachment, .p3D65)
        XCTAssertEqual(output.c7.contract.transferFunctionAttachment, .sRGB)
        XCTAssertEqual(output.c7.contract.attachmentColorSpace?.gamut, .displayP3)
        XCTAssertEqual(output.c7.contract.attachmentColorSpace?.transferFunction, .sRGB)
    }

    func testRenderPixelBufferSynthesizesPrimariesFromSampleBufferYCbCrMatrixWhenMissing() throws {
        let pixelBuffer = try makeBiPlanarPixelBuffer()
        if #available(iOS 14.0, macOS 11.0, tvOS 14.0, *) {
            CVBufferSetAttachment(
                pixelBuffer,
                kCVImageBufferYCbCrMatrixKey,
                kCVImageBufferYCbCrMatrix_ITU_R_2020,
                .shouldPropagate
            )
            CVBufferSetAttachment(
                pixelBuffer,
                kCVImageBufferTransferFunctionKey,
                kCVImageBufferTransferFunction_ITU_R_2100_HLG,
                .shouldPropagate
            )
        } else {
            throw XCTSkip("BT.2020 / HLG attachments are unavailable on this platform.")
        }
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffer.")
            return
        }

        let output = try HarbethIO(
            element: sampleBuffer,
            filter: C7Brightness(brightness: 0.1)
        ).renderPixelBuffer()

        XCTAssertEqual(output.c7.contract.colorPrimariesAttachment, .ituR2020)
        XCTAssertEqual(output.c7.contract.transferFunctionAttachment, .ituR2100HLG)
        XCTAssertEqual(output.c7.contract.attachmentColorSpace?.gamut, .ituR2020)
        XCTAssertEqual(output.c7.contract.attachmentColorSpace?.transferFunction, .hybridLogGamma)
        XCTAssertEqual(output.c7.contract.attachmentColorSpace?.name, "ituR2020+ituR2100HLG")
    }

    func testRenderPixelBufferAppliesExplicitRenderOutputColorAttachments() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [64, 96, 128, 255])

        let output = try HarbethIO(
            element: input,
            filter: PixelBufferOutputColorSpaceRenderFilter()
        ).renderPixelBuffer()

        XCTAssertEqual(output.c7.contract.colorPrimariesAttachment, .p3D65)
        XCTAssertEqual(output.c7.contract.transferFunctionAttachment, .sRGB)
        XCTAssertEqual(output.c7.contract.attachmentColorSpace?.gamut, .displayP3)
        XCTAssertEqual(output.c7.contract.attachmentColorSpace?.transferFunction, .sRGB)
    }

    func testFilteringSampleBufferAppliesExplicitRenderOutputColorAttachments() throws {
        let pixelBuffer = try makeBGRAPixelBuffer(width: 2, height: 2)
        CVBufferSetAttachment(
            pixelBuffer,
            kCVImageBufferColorPrimariesKey,
            kCVImageBufferColorPrimaries_ITU_R_709_2,
            .shouldPropagate
        )
        CVBufferSetAttachment(
            pixelBuffer,
            kCVImageBufferTransferFunctionKey,
            kCVImageBufferTransferFunction_sRGB,
            .shouldPropagate
        )
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffer.")
            return
        }

        let output: CMSampleBuffer = try HarbethIO(
            element: sampleBuffer,
            filter: PixelBufferOutputColorSpaceRenderFilter()
        ).output()

        XCTAssertEqual(output.c7.contract.pixelBufferContract?.colorPrimariesAttachment, .p3D65)
        XCTAssertEqual(output.c7.contract.pixelBufferContract?.transferFunctionAttachment, .sRGB)
        XCTAssertEqual(output.c7.contract.pixelBufferContract?.attachmentColorSpace?.gamut, .displayP3)
        XCTAssertEqual(output.c7.contract.pixelBufferContract?.attachmentColorSpace?.transferFunction, .sRGB)
    }

    func testFilteringPixelBufferResizeThrowsTextureSizeMismatch() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: 4,
            kCVPixelBufferHeightKey: 4,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                4,
                4,
                kCVPixelFormatType_32BGRA,
                attributes as CFDictionary,
                &pixelBuffer
            ),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create pixel buffer.")
            return
        }

        XCTAssertThrowsError(
            try HarbethIO(element: pixelBuffer, filter: C7Resize(width: 2, height: 2)).output() as CVPixelBuffer
        ) { error in
            guard case .textureSizeMismatch? = error.asHarbethError else {
                return XCTFail("Expected textureSizeMismatch, got \(error)")
            }
        }
    }

    func testFilteringPixelBufferResizeAsyncReturnsTextureSizeMismatch() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: 4,
            kCVPixelBufferHeightKey: 4,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                4,
                4,
                kCVPixelFormatType_32BGRA,
                attributes as CFDictionary,
                &pixelBuffer
            ),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create pixel buffer.")
            return
        }

        let expectation = expectation(description: "pixelBuffer copy-back failure")
        HarbethIO(element: pixelBuffer, filter: C7Resize(width: 2, height: 2)).transmitOutput { (result: Result<CVPixelBuffer, HarbethError>) in
            switch result {
            case .success:
                XCTFail("Expected resize to fail for in-place pixel buffer copy-back.")
            case .failure(let error):
                guard case .textureSizeMismatch = error else {
                    return XCTFail("Expected textureSizeMismatch, got \(error)")
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    private func makeTexture(width: Int, height: Int, pixel: [UInt8]) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = Shared.shared.defaultDevice.device.makeTexture(descriptor: descriptor) else {
            throw HarbethError.makeTexture
        }
        var pixels = Array(repeating: UInt8(0), count: width * height * 4)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            pixels[index] = pixel[0]
            pixels[index + 1] = pixel[1]
            pixels[index + 2] = pixel[2]
            pixels[index + 3] = pixel[3]
        }
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: width * 4
        )
        return texture
    }

    private func makeBiPlanarPixelBuffer(width: Int = 4, height: Int = 4) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            attributes as CFDictionary,
            &pixelBuffer
        )
        try XCTSkipIf(
            status != kCVReturnSuccess,
            "Bi-planar pixel buffer is unavailable in this environment. CVPixelBufferCreate status=\(status)."
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create bi-planar pixel buffer.")
            throw XCTSkip()
        }
        return pixelBuffer
    }

    private func makeBGRAPixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        try XCTSkipIf(
            status != kCVReturnSuccess,
            "BGRA pixel buffer is unavailable in this environment. CVPixelBufferCreate status=\(status)."
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create BGRA pixel buffer.")
            throw XCTSkip()
        }
        return pixelBuffer
    }

    private func makeTriPlanarPixelBuffer(width: Int = 6, height: Int = 4) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8PlanarFullRange,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
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
            throw XCTSkip()
        }
        return pixelBuffer
    }
}

private struct PixelBufferOutputColorSpaceRenderFilter: RenderProtocol {
    var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "basicFragment")
    }

    var renderOutputContract: RenderOutputContract {
        RenderOutputContract(colorSpace: .displayP3)
    }
}
