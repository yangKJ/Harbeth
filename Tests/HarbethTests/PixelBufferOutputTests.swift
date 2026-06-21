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

    func testBiPlanarPixelBufferContractExposesFallbackTopLevelAndDirectPlaneBridge() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
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
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                attributes as CFDictionary,
                &pixelBuffer
            ),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create bi-planar pixel buffer.")
            return
        }

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
        XCTAssertEqual(bridgePlan.loadStrategy, .cgImageFallback)
        XCTAssertFalse(bridgePlan.preservesOwnerReference)
        XCTAssertTrue(bridgePlan.requiresColorConversion)
        XCTAssertEqual(bridgePlan.directPlaneBridgeCount, 2)
        XCTAssertTrue(bridgePlan.supportsDirectPlaneTextures)
        XCTAssertEqual(bridgePlan.planes.count, 2)
        XCTAssertEqual(bridgePlan.planes[0].conversionStrategy, .directMetalTexture)
        XCTAssertTrue(bridgePlan.planes[0].preservesOwnerReference)
        XCTAssertEqual(bridgePlan.planes[1].metalPixelFormat, .rg8Unorm)
        XCTAssertEqual(bridgePlan.planes[1].conversionStrategy, .directMetalTexture)
        XCTAssertTrue(bridgePlan.planes[1].preservesOwnerReference)
        XCTAssertTrue(bridgePlan.fingerprint.contains("load=cgImageFallback"))
        XCTAssertTrue(bridgePlan.fingerprint.contains("plane=0|metal=\(MTLPixelFormat.r8Unorm.rawValue)|strategy=directMetalTexture|owner=1"))
        XCTAssertTrue(bridgePlan.fingerprint.contains("plane=1|metal=\(MTLPixelFormat.rg8Unorm.rawValue)|strategy=directMetalTexture|owner=1"))
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
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
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
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                attributes as CFDictionary,
                &pixelBuffer
            ),
            kCVReturnSuccess
        )
        guard let pixelBuffer,
              let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create bi-planar sample buffer.")
            return
        }

        let contract = sampleBuffer.c7.contract

        XCTAssertEqual(contract.pixelBufferContract?.colorModel, .yCbCrBiPlanar)
        XCTAssertEqual(contract.frameContract.conversionStrategy, .cgImageFallback)
        XCTAssertFalse(contract.frameContract.ownerRetained)
        XCTAssertEqual(contract.frameContract.directPlaneBridgeCount, 2)
        XCTAssertTrue(contract.frameContract.supportsDirectPlaneTextures)
        XCTAssertTrue(contract.fingerprint.contains("directPlanes=2"))
    }

    func testBiPlanarPixelBufferCanRenderThroughTextureLoader() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
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
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                attributes as CFDictionary,
                &pixelBuffer
            ),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create bi-planar pixel buffer.")
            return
        }

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
        XCTAssertTrue(request.source.fingerprint.contains("bridge={"))
        XCTAssertEqual(renderRecipe.source.kind, "pixelBuffer")
        XCTAssertEqual(renderRecipe.source.pixelBufferContract?.planeCount, 1)
        XCTAssertEqual(renderRecipe.alphaType, .premultiplied)
        XCTAssertEqual(renderRecipe.orientation, .up)
    }

    func testRenderDiagnosticsTracksBiPlanarPixelBufferInputConversions() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
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
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                attributes as CFDictionary,
                &pixelBuffer
            ),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create bi-planar pixel buffer.")
            return
        }

        let diagnostics = try HarbethIO(element: pixelBuffer, filter: C7Brightness(brightness: 0.0)).renderDiagnostics()

        XCTAssertEqual(diagnostics.inputColorConversionCount, 1)
        XCTAssertEqual(diagnostics.inputPixelFormatConversionCount, 1)
        XCTAssertEqual(diagnostics.inputAlphaConversionCount, 0)
        XCTAssertEqual(diagnostics.colorConversionCount, 0)
        XCTAssertEqual(diagnostics.pixelFormatConversionCount, 0)
        XCTAssertTrue(diagnostics.summary.contains("inputColorConversions=1"))
        XCTAssertTrue(diagnostics.summary.contains("inputPixelFormatConversions=1"))
    }

    func testRenderDiagnosticsTracksBGRAPixelBufferNoInputConversions() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: 3,
            kCVPixelBufferHeightKey: 2,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                3,
                2,
                kCVPixelFormatType_32BGRA,
                attributes as CFDictionary,
                &pixelBuffer
            ),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create BGRA pixel buffer.")
            return
        }

        let diagnostics = try HarbethIO(element: pixelBuffer).renderDiagnostics()

        XCTAssertEqual(diagnostics.inputColorConversionCount, 0)
        XCTAssertEqual(diagnostics.inputPixelFormatConversionCount, 0)
        XCTAssertEqual(diagnostics.inputAlphaConversionCount, 0)
        XCTAssertTrue(diagnostics.summary.contains("inputColorConversions=0"))
        XCTAssertTrue(diagnostics.summary.contains("inputPixelFormatConversions=0"))
    }

    func testRenderDiagnosticsTracksSampleBufferBiPlanarInputConversions() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
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
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                attributes as CFDictionary,
                &pixelBuffer
            ),
            kCVReturnSuccess
        )
        guard let pixelBuffer,
              let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create bi-planar sample buffer.")
            return
        }

        let diagnostics = try HarbethIO(element: sampleBuffer, filter: C7Brightness(brightness: 0.0)).renderDiagnostics()

        XCTAssertEqual(diagnostics.inputColorConversionCount, 1)
        XCTAssertEqual(diagnostics.inputPixelFormatConversionCount, 1)
        XCTAssertEqual(diagnostics.inputAlphaConversionCount, 0)
        XCTAssertEqual(diagnostics.sourceKind, "sampleBuffer")
        XCTAssertTrue(diagnostics.summary.contains("origin=sampleBuffer"))
        XCTAssertTrue(diagnostics.summary.contains("inputColorConversions=1"))
        XCTAssertTrue(diagnostics.summary.contains("inputPixelFormatConversions=1"))
    }

    func testRenderDiagnosticsTracksSampleBufferRGBAInputNoInputConversions() throws {
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
        guard let pixelBuffer,
              let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create RGBA sample buffer.")
            return
        }

        let diagnostics = try HarbethIO(element: sampleBuffer).renderDiagnostics()

        XCTAssertEqual(diagnostics.inputColorConversionCount, 0)
        XCTAssertEqual(diagnostics.inputPixelFormatConversionCount, 0)
        XCTAssertEqual(diagnostics.inputAlphaConversionCount, 0)
        XCTAssertEqual(diagnostics.sourceKind, "sampleBuffer")
        XCTAssertTrue(diagnostics.summary.contains("origin=sampleBuffer"))
        XCTAssertTrue(diagnostics.summary.contains("inputColorConversions=0"))
        XCTAssertTrue(diagnostics.summary.contains("inputPixelFormatConversions=0"))
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
}
