import XCTest
import ImageIO
@testable import Harbeth

final class HarbethIOAsyncTests: XCTestCase {

    func testFilterMetadataDefaultsStayNonBreaking() {
        let filter = C7Brightness(brightness: 0.2)
        XCTAssertEqual(filter.stableTypeID, "C7Brightness")
        XCTAssertTrue(filter.parameterDescriptors.isEmpty)
        XCTAssertNil(filter.intensityHint)
    }

    func testBufferPixelFormatRemainsTheSinglePublicOverride() {
        var io = HarbethIO(element: "seed", filters: [])

        XCTAssertNil(io.bufferPixelFormat)

        io.bufferPixelFormat = .bgra8Unorm

        XCTAssertEqual(io.bufferPixelFormat, .bgra8Unorm)
    }

    func testDoubleBufferHonorsExplicitOutputPixelFormat() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
        let input = try makeTexture(width: 4, height: 4, pixel: [80, 100, 120, 255])
        var io = HarbethIO(
            element: input,
            filters: [
                C7Brightness(brightness: 0.1),
                C7Contrast(contrast: 1.05)
            ]
        )
        io.bufferPixelFormat = .rgba16Float

        let output = try io.output()

        XCTAssertEqual(output.pixelFormat, .rgba16Float)
    }

    func testRenderProfileDrivesExecutionPolicies() {
        let base = HarbethIO(element: "seed", filters: [])

        let interactive = base.configured(for: .interactiveLatency)
        XCTAssertFalse(interactive.transmitOutputRealTimeCommit)
        XCTAssertEqual(interactive.renderProfile, .interactiveLatency)
        XCTAssertTrue(RenderProfile.interactiveLatency.requestsScheduledTextureDelivery)
        XCTAssertFalse(RenderProfile.interactiveLatency.enablesDoubleBuffer)
        XCTAssertFalse(RenderProfile.interactiveLatency.createsDestinationTexture)

        let stable = base.configured(for: .stablePreview)
        XCTAssertFalse(stable.transmitOutputRealTimeCommit)
        XCTAssertEqual(stable.renderProfile, .stablePreview)
        XCTAssertFalse(RenderProfile.stablePreview.requestsScheduledTextureDelivery)
        XCTAssertTrue(RenderProfile.stablePreview.enablesDoubleBuffer)
        XCTAssertTrue(RenderProfile.stablePreview.createsDestinationTexture)

        let export = base.configured(for: .exportQuality)
        XCTAssertFalse(export.transmitOutputRealTimeCommit)
        XCTAssertEqual(export.renderProfile, .exportQuality)
        XCTAssertTrue(RenderProfile.exportQuality.enablesDoubleBuffer)
        XCTAssertTrue(RenderProfile.exportQuality.createsDestinationTexture)
    }

    func testRealTimeCommitRemainsTheOnlyPublicDeliverySwitch() {
        var io = HarbethIO(element: "seed", filters: [])

        XCTAssertFalse(io.transmitOutputRealTimeCommit)

        io.transmitOutputRealTimeCommit = true

        XCTAssertTrue(io.transmitOutputRealTimeCommit)
    }

    func testAsyncTransmitOutputMatchesCallbackResult() async throws {
        let io = HarbethIO(element: "seed", filters: [])

        let callbackValue = try await withCheckedThrowingContinuation { continuation in
            io.transmitOutput(complete: { result in
                continuation.resume(with: result)
            })
        }

        let asyncValue = try await io.transmitOutput()

        XCTAssertEqual(callbackValue, "seed")
        XCTAssertEqual(asyncValue, callbackValue)
    }

    func testFilteredTransmitOutputUsesRenderOperationQueue() async throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        let input = try makeTexture(width: 4, height: 4, pixel: [80, 100, 120, 255])
        let io = HarbethIO(element: input, filters: [C7Brightness(brightness: 0.1)])
        let queue = HarbethContext.shared.renderOperationQueue
        let state = HarbethIOCallbackState()
        let completion = HarbethUncheckedTransfer(value: expectation(description: "filtered transmit output"))

        queue.isSuspended = true
        defer { queue.isSuspended = false }

        io.transmitOutput { result in
            state.didComplete = true
            if case .failure(let error) = result { state.error = error }
            completion.value.fulfill()
        }

        XCTAssertFalse(state.didComplete, "有滤镜的 transmitOutput 不应在提交调用栈内同步执行。")
        queue.isSuspended = false
        await fulfillment(of: [completion.value], timeout: 3.0)
        XCTAssertTrue(state.didComplete)
        XCTAssertNil(state.error)
    }

    func testImageNodeMakeFrameAsyncMatchesCallbackResult() async throws {
        let texture = try makeTexture(width: 4, height: 4, pixel: [110, 90, 70, 255])
        let node = ImageNode.texture(texture).applying(C7Brightness(brightness: 0.1))

        let callbackFrame = try await withCheckedThrowingContinuation { continuation in
            node.transmitFrame { result in
                continuation.resume(with: result)
            }
        }

        let asyncFrame = try await node.makeFrameAsync()

        XCTAssertEqual(asyncFrame.texture.width, callbackFrame.texture.width)
        XCTAssertEqual(asyncFrame.texture.height, callbackFrame.texture.height)
        XCTAssertEqual(asyncFrame.identifier, callbackFrame.identifier)
    }

    func testAsyncTransmitManagedTexturePrewarmsLifecycleReservations() async throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()
        defer { HarbethContext.shared.recoverExecution() }

        let input = try makeTexture(width: 32, height: 24, pixel: [120, 80, 40, 255])
        let io = HarbethIO(
            element: input,
            filters: [
                C7Brightness(brightness: 0.1),
                C7Resize(width: 16, height: 12),
                C7Contrast(contrast: 1.1)
            ]
        ).configured(for: .stablePreview)

        let output = try await withCheckedThrowingContinuation { continuation in
            io.transmitManagedTexture { result in
                continuation.resume(with: result)
            }
        }

        let snapshot = HarbethContext.shared.textureAllocator.makeSnapshot()

        XCTAssertGreaterThan(snapshot.textureReuseHitCount, 0)
        XCTAssertGreaterThan(snapshot.textureRequestCount, 0)
        XCTAssertNotNil(output.lease)
        output.lease?.release()
    }

    func testAsyncTransmitManagedTexturePrewarmsDoubleBufferReservations() async throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()
        _ = HarbethContext.shared.runtimeDevice
        HarbethContext.shared.resetTexturePoolStatistics()
        defer { HarbethContext.shared.recoverExecution() }

        let input = try makeTexture(width: 32, height: 24, pixel: [60, 80, 120, 255])
        let io = HarbethIO(
            element: input,
            filters: [
                C7Brightness(brightness: 0.1),
                C7Contrast(contrast: 1.05)
            ]
        ).configured(for: .stablePreview)

        let output = try await withCheckedThrowingContinuation { continuation in
            io.transmitManagedTexture { result in
                continuation.resume(with: result)
            }
        }

        XCTAssertEqual(output.texture.width, 32)
        XCTAssertEqual(output.texture.height, 24)
        XCTAssertGreaterThan(HarbethContext.shared.texturePoolStatistics.totalTexturesReused, 0)
        XCTAssertNotNil(output.lease)
        output.lease?.release()
    }

    func testSuppressedRawDeliveryRecyclesFinalOutput() throws {
        let output = try makeTexture(width: 2, height: 2, pixel: [10, 20, 30, 255])
        let intermediate = try makeTexture(width: 2, height: 2, pixel: [40, 50, 60, 255])
        let rendering = RawTextureRendering(output: output, successRecycling: [intermediate], failureRecycling: [intermediate, output])

        let delivered = rendering.recycling(deliverySucceeded: true)
        let suppressed = rendering.recycling(deliverySucceeded: false)

        XCTAssertEqual(delivered.count, 1)
        XCTAssertTrue(delivered[0] === intermediate)
        XCTAssertEqual(suppressed.count, 2)
        XCTAssertTrue(suppressed.contains(where: { $0 === output }))
    }

    func testScheduledCleanupWaitsForCompletionAndDeliveryDecision() {
        let completionFirst = RawTextureScheduledCleanupState()
        XCTAssertNil(completionFirst.recordCompletion())
        XCTAssertEqual(completionFirst.recordDelivery(false), false)
        XCTAssertNil(completionFirst.recordCompletion())

        let deliveryFirst = RawTextureScheduledCleanupState()
        XCTAssertNil(deliveryFirst.recordDelivery(true))
        XCTAssertEqual(deliveryFirst.recordCompletion(), true)
        XCTAssertNil(deliveryFirst.recordDelivery(true))
    }

    func testSingleFilterManagedEncodingUsesOneOutputLease() throws {
        let input = try makeTexture(width: 8, height: 8, pixel: [70, 80, 90, 255])
        let io = HarbethIO(element: input, filters: [C7Brightness(brightness: 0.1)]).configured(for: .stablePreview)
        let program = io.makeRenderProgram(input: input)
        let commandBuffer = try XCTUnwrap(HarbethContext.shared.makeCommandBuffer())
        let encoded = try io.encodeManagedRenderProgram(program, commandBuffer: commandBuffer)

        XCTAssertEqual(encoded.producedLeases.count, 1)
        XCTAssertTrue(encoded.producedLeases[0] === encoded.result.lease)

        encoded.releaseAll()
        HarbethContext.shared.recycleCommandBuffer(commandBuffer)
    }

    func testFilterRecipeDescriptorUsesStableFingerprint() {
        let filter = C7Brightness(brightness: 0.2)
        let descriptor = filter.recipeDescriptor

        XCTAssertEqual(descriptor.stableTypeID, "C7Brightness")
        XCTAssertEqual(descriptor.modifier, "compute:C7Brightness")
        XCTAssertEqual(descriptor.parameterValues, ["0.200000"])
        XCTAssertTrue(descriptor.fingerprint.contains("C7Brightness"))
    }

    func testRenderRecipeCarriesProfileAlphaOrientationAndFilterChain() throws {
        let image = try makeFixtureCGImage()
        let io = HarbethIO<CGImage>(
            element: image,
            filters: [C7Brightness(brightness: 0.2), C7Contrast(contrast: 1.1)]
        )

        let recipe: RenderRecipe = try io.renderRecipe(profile: RenderProfile.stablePreview)

        XCTAssertEqual(recipe.renderProfile, "stablePreview")
        XCTAssertEqual(recipe.renderIntent, .stable)
        XCTAssertEqual(recipe.source.kind, "cgImage")
        XCTAssertEqual(recipe.source.sourceTier, .original)
        XCTAssertEqual(recipe.source.cachePolicy, ImageCachePolicy.transient)
        XCTAssertEqual(recipe.source.semantic, .sourceOriginal)
        XCTAssertEqual(recipe.outputCachePolicy, ImageCachePolicy.transient)
        XCTAssertEqual(recipe.outputSemantic.role, .derivative)
        XCTAssertEqual(recipe.outputSemantic.purpose, .stable)
        XCTAssertEqual(recipe.outputSemantic.fidelity, .displayOptimized)
        XCTAssertEqual(recipe.alphaType, AlphaType.premultiplied)
        XCTAssertEqual(recipe.orientation, FrameOrientation.up)
        XCTAssertEqual(recipe.filters.count, 2)
        XCTAssertTrue(recipe.fingerprint.contains("C7Brightness"))
        XCTAssertTrue(recipe.fingerprint.contains("C7Contrast"))
        XCTAssertTrue(recipe.fingerprint.contains("intent=stable"))
        XCTAssertTrue(recipe.fingerprint.contains("outputCache=transient"))
        XCTAssertTrue(recipe.fingerprint.contains("purpose=stable"))
    }

    func testRenderRecipeCanCarryDerivativeSpec() throws {
        let image = try makeFixtureCGImage()
        let io = HarbethIO<CGImage>(
            element: image,
            filters: [C7Brightness(brightness: 0.2)]
        )
        let derivative = ImageDerivativeSpec(
            name: "panelThumbnail",
            renderIntent: .delivery,
            sourceTier: .thumbnail,
            semantic: ImageSemanticDescriptor(role: .derivative, purpose: .thumbnail, fidelity: .thumbnailOptimized),
            outputSizePolicy: .maxPixelSize(160)
        )

        let recipe = try io.renderRecipe(profile: .stablePreview, derivative: derivative)

        XCTAssertEqual(recipe.renderIntent, .delivery)
        XCTAssertEqual(recipe.outputDerivative.name, "panelThumbnail")
        XCTAssertEqual(recipe.outputDerivative.sourceTier, .thumbnail)
        XCTAssertEqual(recipe.outputDerivative.outputSizePolicy, .maxPixelSize(160))
        XCTAssertTrue(recipe.fingerprint.contains("name=panelThumbnail"))
        XCTAssertTrue(recipe.fingerprint.contains("output=maxPixel:160"))
    }

    func testHarbethIODiagnosticsRecipeAndRequestShareDerivativeContract() throws {
        let input = try makeTexture(width: 4, height: 4, pixel: [120, 40, 20, 255])
        let derivative = ImageDerivativeSpec(
            name: "tinyPreview",
            renderIntent: .stable,
            sourceTier: .thumbnail,
            semantic: RenderProfile.stablePreview.defaultImageSemantic,
            outputSizePolicy: .exact(C7Size(width: 2, height: 2))
        )
        let io = HarbethIO(
            element: input,
            filters: []
        )

        let diagnostics = try io.renderDiagnostics(profile: .stablePreview, derivative: derivative)
        let recipe = try io.renderRecipe(profile: .stablePreview, derivative: derivative)
        let request = try io.makeRenderRequest(profile: .stablePreview, derivative: derivative)
        let requestRecipe = try XCTUnwrap(request.renderRecipe)
        let frame = try request.renderFrame()

        XCTAssertEqual(diagnostics.outputSize, C7Size(width: 2, height: 2))
        XCTAssertTrue(diagnostics.containsDerivativeResize)
        XCTAssertEqual(recipe.outputDerivative.name, "tinyPreview")
        XCTAssertTrue(recipe.filters.isEmpty, "Derivative output policy belongs to outputDerivative, not the authored filter chain.")
        XCTAssertEqual(requestRecipe.outputDerivative, recipe.outputDerivative)
        XCTAssertEqual(requestRecipe.filters, recipe.filters)
        XCTAssertEqual(request.diagnostics.outputSize, C7Size(width: 2, height: 2))
        XCTAssertEqual(frame.resolvedOutputSize, C7Size(width: 2, height: 2))
    }

    func testRenderRequestCarriesStableContractsAndDeferredExecution() throws {
        let image = try makeFixtureCGImage()
        let io = HarbethIO<CGImage>(
            element: image,
            filters: [C7Brightness(brightness: 0.2)]
        )

        let request = try io.makeRenderRequest(profile: .stablePreview)
        let frame = try request.renderFrame(metadata: ["request": "deferred"])

        XCTAssertEqual(request.compilationSource, .nodeGraph)
        XCTAssertEqual(request.profile, .stablePreview)
        XCTAssertEqual(request.derivative.renderIntent, .stable)
        XCTAssertEqual(request.source.kind, "cgImage")
        XCTAssertEqual(request.outputCachePolicy, .transient)
        XCTAssertEqual(request.renderRecipe?.renderIntent, .stable)
        XCTAssertEqual(frame.metadata["request"], "deferred")
        XCTAssertEqual(frame.profile, .stablePreview)
    }

    func testRenderRequestBridgesDeferredAttachmentOutputsForRenderPrimitive() throws {
        let image = try makeFixtureCGImage()
        let request = try HarbethIO<CGImage>(
            element: image,
            filters: [RenderAuxiliaryLuminance()]
        ).makeRenderRequest(profile: .readbackQuality)

        let attachmentSet = try XCTUnwrap(request.renderAttachmentSet())
        let bundle = try XCTUnwrap(
            request.renderAttachmentAnalysisBundle(
                bins: 4,
                histogramHeight: 16,
                preferredMethod: .gpuMPS
            )
        )

        XCTAssertEqual(attachmentSet.debugPolicies.map(\.label), ["primaryColor", "luminance"])
        XCTAssertEqual(bundle.debugPolicies.map(\.label), ["primaryColor", "luminance"])
        XCTAssertEqual(bundle.analysis(for: .luminance)?.histogram?.channel, .luminance)
    }

    func testRenderRequestBridgesDeferredAnalysisBundleAndColorProbe() throws {
        let image = try makeFixtureCGImage()
        let request = try HarbethIO<CGImage>(
            element: image,
            filters: [C7Brightness(brightness: 0.0)]
        ).makeRenderRequest(profile: .readbackQuality)

        let bundle = try XCTUnwrap(
            request.renderAnalysisBundle(
                channel: .red,
                bins: 4,
                histogramHeight: 16,
                preferredMethod: .cpuReadback
            )
        )
        let probe = try XCTUnwrap(
            request.renderColorProbe(x: 0, y: 0)
        )

        XCTAssertEqual(bundle.histogram?.channel, .red)
        XCTAssertEqual(bundle.statistics?.sampleCount, 1)
        XCTAssertEqual(bundle.colorProbe?.sampleCount, 1)
        XCTAssertEqual(probe.sampleCount, 1)
        XCTAssertEqual(probe.meanColor8.x, 255)
    }

    func testRenderRequestBridgesDeferredColorRangeAnalysisScope() throws {
        let texture = try makeTexture(width: 3, height: 1, pixels: [
            [255, 0, 0, 255],
            [0, 255, 0, 255],
            [255, 255, 255, 255]
        ])
        let request = try HarbethIO<MTLTexture>(
            element: texture,
            filters: [C7Brightness(brightness: 0.0)]
        ).makeRenderRequest(profile: .readbackQuality)
        let scope = TextureAnalysisScope(
            colorRange: TextureColorRange(
                hue: TextureComponentRange(minimum: 0.95, maximum: 0.05, wrapsAroundUnit: true),
                saturation: TextureComponentRange(minimum: 0.8, maximum: 1.0)
            )
        )

        let bundle = try XCTUnwrap(
            request.renderAnalysisBundle(
                channel: .red,
                bins: 4,
                histogramHeight: 16,
                scope: scope,
                preferredMethod: .cpuReadback
            )
        )
        let probe = try XCTUnwrap(request.renderColorProbe(scope: scope))

        XCTAssertEqual(bundle.histogram?.totalSampleCount, 1)
        XCTAssertEqual(bundle.statistics?.sampleCount, 1)
        XCTAssertEqual(bundle.colorProbe?.sampleCount, 1)
        XCTAssertEqual(bundle.colorProbe?.meanColor8.x, 255)
        XCTAssertEqual(bundle.colorProbe?.meanColor8.y, 0)
        XCTAssertEqual(bundle.colorProbe?.meanColor8.z, 0)
        XCTAssertEqual(probe.meanColor8.x, 255)
        XCTAssertEqual(bundle.analysisScopeFingerprint, scope.fingerprint)
    }

    func testRenderRequestCanMaterializeColorRangeMaskDescriptor() throws {
        let texture = try makeTexture(width: 3, height: 1, pixels: [
            [255, 0, 0, 255],
            [0, 255, 0, 255],
            [255, 255, 255, 255]
        ])
        let request = try HarbethIO<MTLTexture>(
            element: texture,
            filters: [C7Brightness(brightness: 0.0)]
        ).makeRenderRequest(profile: .readbackQuality)
        let scope = TextureAnalysisScope(
            colorRange: TextureColorRange(
                hue: TextureComponentRange(minimum: 0.95, maximum: 0.05, wrapsAroundUnit: true),
                saturation: TextureComponentRange(minimum: 0.8, maximum: 1.0)
            )
        )

        let mask = try XCTUnwrap(request.renderMaskDescriptor(scope: scope))
        let bytes = try XCTUnwrap(mask.texture.c7.bytes())

        XCTAssertEqual(mask.component, .red)
        XCTAssertEqual(Array(bytes[0..<4]), [255, 255, 255, 255])
        XCTAssertEqual(Array(bytes[4..<8]), [0, 0, 0, 255])
        XCTAssertEqual(Array(bytes[8..<12]), [0, 0, 0, 255])
    }

    func testImageNodeCanMaterializeColorRangeMaskDescriptor() throws {
        let texture = try makeTexture(width: 3, height: 1, pixels: [
            [255, 0, 0, 255],
            [0, 255, 0, 255],
            [255, 255, 255, 255]
        ])
        let request = try ImageNode.texture(texture)
            .applying(C7Brightness(brightness: 0.0))
            .makeRenderRequest(profile: .readbackQuality)
        let scope = TextureAnalysisScope(
            colorRange: TextureColorRange(
                hue: TextureComponentRange(minimum: 0.95, maximum: 0.05, wrapsAroundUnit: true),
                saturation: TextureComponentRange(minimum: 0.8, maximum: 1.0)
            )
        )

        let mask = try XCTUnwrap(request.renderMaskDescriptor(scope: scope))
        let bytes = try XCTUnwrap(mask.texture.c7.bytes())

        XCTAssertEqual(mask.component, .red)
        XCTAssertEqual(Array(bytes[0..<4]), [255, 255, 255, 255])
        XCTAssertEqual(Array(bytes[4..<8]), [0, 0, 0, 255])
        XCTAssertEqual(Array(bytes[8..<12]), [0, 0, 0, 255])
    }

    func testImageNodeCanMaterializeAttachmentMaskDescriptor() throws {
        let image = try makeFixtureCGImage()
        let request = try ImageNode.cgImage(image)
            .applying(RenderAuxiliaryLuminance())
            .makeRenderRequest(profile: .readbackQuality)
        let scope = TextureAnalysisScope(region: MTLRegionMake2D(0, 0, 8, 8))

        let attachmentSet = try XCTUnwrap(request.renderAttachmentSet())
        let mask = try XCTUnwrap(attachmentSet.makeMaskDescriptor(for: .luminance, scope: scope))

        XCTAssertEqual(mask.component, .red)
        XCTAssertEqual(mask.texture.width, image.width)
        XCTAssertEqual(mask.texture.height, image.height)
    }

    func testHarbethIOC7ImageOutputAppliesExplicitRenderOutputColorSpace() throws {
        let cgImage = try makeFixtureCGImage()
        let image = C7Image(cgImage: cgImage)

        let output: C7Image = try HarbethIO(
            element: image,
            filters: [HarbethIOC7ImageDisplayP3RenderFilter()]
        ).output()

        XCTAssertEqual(output.c7.toCGImage()?.colorSpace?.name as String?, CGColorSpace.displayP3 as String)
    }

    func testHarbethIOC7ImageOutputPreservesSourceColorSpaceWithoutExplicitContract() throws {
        let displayP3 = try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))
        let cgImage = try makeFixtureCGImage(colorSpace: displayP3)
        let image = C7Image(cgImage: cgImage)

        let output: C7Image = try HarbethIO(
            element: image,
            filters: [C7Brightness(brightness: 0.0)]
        ).output()

        XCTAssertEqual(output.c7.toCGImage()?.colorSpace?.name as String?, CGColorSpace.displayP3 as String)
    }

    func testC7ImageEncodedPNGDataPreservesDisplayP3ColorSpace() throws {
        let displayP3 = try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))
        let image = C7Image(cgImage: try makeFixtureCGImage(colorSpace: displayP3))

        let data = try XCTUnwrap(image.c7.encodedPNGData())

        XCTAssertEqual(decodedImageColorSpaceName(from: data), CGColorSpace.displayP3 as String)
    }

    private func makeFixtureCGImage(colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()) throws -> CGImage {
        let bytes: [UInt8] = [255, 0, 0, 255]
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(width: 1,
                                  height: 1,
                                  bitsPerComponent: 8,
                                  bitsPerPixel: 32,
                                  bytesPerRow: 4,
                                  space: colorSpace,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider,
                                  decode: nil,
                                  shouldInterpolate: false,
                                  intent: .defaultIntent) else {
            throw XCTSkip("Failed to create CGImage fixture.")
        }
        return image
    }

    private func decodedImageColorSpaceName(from data: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return image.colorSpace?.name as String?
    }

    private func makeTexture(width: Int, height: Int, pixel: [UInt8]) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = HarbethContext.shared.device.makeTexture(descriptor: descriptor) else {
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

    private func makeTexture(width: Int, height: Int, pixels: [[UInt8]]) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = HarbethContext.shared.device.makeTexture(descriptor: descriptor) else {
            throw HarbethError.makeTexture
        }
        let bytes = pixels.flatMap { $0 }
        XCTAssertEqual(bytes.count, width * height * 4)
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: width * 4
        )
        return texture
    }
}

private final class HarbethIOCallbackState: @unchecked Sendable {
    private let lock = NSLock()
    private var storedDidComplete = false
    private var storedError: HarbethError?

    var didComplete: Bool {
        get { lock.withLock { storedDidComplete } }
        set { lock.withLock { storedDidComplete = newValue } }
    }

    var error: HarbethError? {
        get { lock.withLock { storedError } }
        set { lock.withLock { storedError = newValue } }
    }
}

private struct HarbethIOC7ImageDisplayP3RenderFilter: RenderProtocol {
    var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "basicFragment")
    }

    var renderSamplerConsumption: RenderSamplerConsumption { .runtimeBound }

    var renderOutputContract: RenderOutputContract {
        RenderOutputContract(colorSpace: .displayP3)
    }
}
