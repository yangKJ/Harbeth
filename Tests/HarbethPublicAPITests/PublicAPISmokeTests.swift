import XCTest
import CoreImage
import Metal
import SwiftUI
import Harbeth

final class PublicAPISmokeTests: XCTestCase {
    func testCanonicalHarbethIOSurfaceCompiles() {
        let render: (MTLTexture) throws -> MTLTexture = { texture in
            try HarbethIO(element: texture, filters: []).output()
        }
        let transmit: (MTLTexture) -> Void = { texture in
            HarbethIO(element: texture, filters: []).transmitOutput(outputColorSpace: nil, complete: { _ in })
        }
        let configureRealTimeCommit: (MTLTexture) -> HarbethIO<MTLTexture> = { texture in
            var io = HarbethIO(element: texture, filters: [])
            io.transmitOutputRealTimeCommit = true
            return io
        }
        let configurePixelFormat: (MTLTexture, MTLPixelFormat?) -> HarbethIO<MTLTexture> = { texture, pixelFormat in
            var io = HarbethIO(element: texture, filters: [])
            io.bufferPixelFormat = pixelFormat
            return io
        }
        let configureLegacyCIImageOrientation: (CIImage) -> HarbethIO<CIImage> = { image in
            var io = HarbethIO(element: image, filters: [])
            io.mirrored = true
            return io
        }
        let textureBackedFrame: (CIImage) throws -> TextureBackedCIImageFrame = { image in
            try HarbethIO(element: image, filters: []).outputTextureBackedFrame()
        }
        _ = render
        _ = transmit
        _ = configureRealTimeCommit
        _ = configurePixelFormat
        _ = configureLegacyCIImageOrientation
        _ = textureBackedFrame
    }

    func testCanonicalImageNodeSurfaceCompiles() {
        let build: (MTLTexture) -> ImageNode = { texture in ImageNode.texture(texture).withCachePolicy(.transient) }
        let capability: (ImageNode) throws -> FrameProcessingCapability = { node in
            try node.makeFrameProcessingCapability(for: .dynamicFrame)
        }
        let pageCurl: (MTLTexture, MTLTexture) -> ImageNode = { from, to in
            ImageNode.transition(
                from: .texture(from),
                to: .texture(to),
                kernel: .pageCurl(angleDegrees: 15, radius: 0.2, shadowStrength: 0.6),
                progress: 0.5
            )
        }
        _ = build
        _ = capability
        _ = pageCurl
    }

    func testRenderSubmissionSurfaceCompiles() {
        let policy = RenderSubmissionPolicy.latestOnly(scopeIdentifier: "editor.preview")
        let transmit: (MTLTexture) -> RenderSubmissionHandle = { texture in
            var io = HarbethIO(element: texture, filters: [C7Brightness(brightness: 0.1)])
            io.submissionPolicy = policy
            return io.transmitOutput(outputColorSpace: nil, complete: { _ in })
        }
        let inspect: (RenderSubmissionHandle) -> RenderSubmissionSnapshot = { handle in
            handle.snapshot
        }
        let cancel: (RenderSubmissionHandle) -> Void = { handle in
            handle.cancel()
        }
        _ = (transmit, inspect, cancel)
    }

    func testSIMDValueConversionSurfaceCompiles() {
        let color = C7Color(red: 0.25, green: 0.5, blue: 0.75, alpha: 1)
        let rgb: SIMD3<Float> = color.c7.toSIMD3()
        let rgba: SIMD4<Float> = color.c7.toSIMD4()
        let point: SIMD2<Float> = C7Point2D.center.toSIMD2()
        let freePoint: SIMD2<Float> = FreePoint2D(x: -0.5, y: 1.5).toSIMD2()
        _ = (rgb, rgba, point, freePoint)
    }

    func testEncodeOnlyAttachmentInteropSurfaceCompiles() {
        let encode: (RenderAuxiliaryLuminance, MTLTexture, MTLCommandBuffer) throws -> RenderedAttachmentSet = {
            filter, texture, commandBuffer in
            try filter.encodeAttachmentSet(from: texture, commandBuffer: commandBuffer)
        }
        _ = encode
    }

    func testDerivedResourceGovernanceSurfaceCompiles() {
        let configuration = DerivedResourceCacheConfiguration(byteLimit: 64 * 1024 * 1024, countLimit: 128)
        let configure: (HarbethContext) -> Void = { context in
            context.configureDerivedResourceCache(configuration)
            context.setDerivedResourceNamespace("document-session")
            context.invalidateDerivedResources(domain: .outputContract, namespace: "document-session")
        }
        let identity: (HarbethContext) -> DerivedResourceIdentity = { context in
            context.makeDerivedResourceIdentity(domain: .lookupTable, fingerprint: "lut-resource")
        }
        _ = configure
        _ = identity
    }

    func testRuntimeResourceSurfaceCompiles() {
        let configure: (HarbethContext) -> Void = { context in
            context.textureAllocationStrategy = .exact
            context.enablePerformanceMonitor = false
            context.maxConcurrentRenderTasks = context.maxConcurrentRenderTasks
            _ = context.makeCommandBuffer()
            _ = context.capabilityReport(.heapTexturePool)
            _ = context.debugCacheSnapshot()
            let texturePoolStatistics: TexturePoolStatistics = context.texturePoolStatistics
            _ = texturePoolStatistics
            _ = context.executionGeneration
        }
        let recover: (HarbethContext) -> UInt64 = { context in
            context.recoverExecution()
        }
        _ = configure
        _ = recover
    }

    func testProfessionalMaskRuntimeSurfaceCompiles() {
        let plane: (MTLTexture) -> MaskPlane = { texture in
            MaskPlane(
                texture: texture,
                coordinateSpace: .sourcePixels,
                sampling: .softCoverage,
                resourceIdentity: MaskResourceIdentity(identifier: "public-mask")
            )
        }
        let expression: (MTLTexture) -> MaskExpressionPlan = { texture in
            let source = MaskExpression.source(plane(texture).maskDescriptor())
            return MaskExpression.intersect(source, .invert(source)).compiledPlan
        }
        let canvas: () throws -> IncrementalMaskCanvas = {
            try IncrementalMaskCanvas(size: C7Size(width: 64, height: 64))
        }
        let refinement: [MaskDerivedOperation] = [
            .shiftEdge(pixels: -1, maxDistance: 32),
            .feather(innerRadius: 1, outerRadius: 2, maxDistance: 32),
            .smartFeather(radius: 8, edgeSensitivity: 0.7)
        ]
        let derived: (MTLTexture) -> MaskDerivedRecipe = { texture in
            MaskDerivedRecipe(
                baseMask: plane(texture).maskDescriptor(),
                sourceIdentifier: "public-derived-mask",
                guideTexture: texture,
                guideConfidenceTexture: texture,
                operations: refinement
            )
        }
        let executeTransient: (MaskDerivedRecipe) throws -> MaskDerivedResult = { recipe in
            try recipe.execute(cachePolicy: .transient)
        }
        let inspect: () -> MaskTopologyRecipe = { MaskTopologyRecipe(connectivity: 8) }
        let decontaminate: (ImageNode, MaskDescriptor) throws -> ImageNode = { node, mask in
            try node.decontaminating(mask: mask)
        }
        let auxiliary: (MTLTexture) throws -> MaskAuxiliaryPlane = { texture in
            try MaskAuxiliaryPlane(texture: texture, semantic: .confidence)
        }
        let warp: (MTLTexture) -> MaskWarpRecipe = { texture in MaskWarpRecipe(flowTexture: texture) }
        _ = expression
        _ = canvas
        _ = refinement
        _ = derived
        _ = executeTransient
        _ = inspect
        _ = decontaminate
        _ = auxiliary
        _ = warp
    }

    func testRecentAtomicFilterSurfaceCompiles() {
        let toneMapping = C7ToneMapping(
            inputNitsPerUnit: 10_000,
            sourcePeakNits: 1_000,
            targetReferenceWhiteNits: 203,
            targetPeakNits: 400
        )
        let displacement: (MTLTexture) -> C7DisplacementMap = { texture in
            C7DisplacementMap(
                displacementTexture: texture,
                scale: 1,
                unit: .pixels,
                encoding: .signed,
                samplingMode: .adaptive,
                edgeMode: .clamp
            )
        }
        let recent: [C7FilterProtocol] = [
            C7ColorGrading(),
            C7SelectiveHSL(),
            C7WhitesBlacks(),
            C7OutputQuantization(),
            C7Palettize(palette: [
                .init(red: 0.05, green: 0.08, blue: 0.12),
                .init(red: 0.95, green: 0.88, blue: 0.72)
            ]),
            C7CMYKHalftone(fractionalWidth: 0.03),
            toneMapping
        ]

        _ = displacement
        _ = recent
        _ = KernelDynamicRangeBehavior.toneMapsToEDR
    }

    @MainActor
    func testPreviewHostSurfacesCompile() {
        let renderView = RenderView(frame: .zero, device: nil)
        renderView.resizingMode = .aspectFit
        renderView.dynamicRangePolicy = .automatic
        renderView.onPreviewDisplayStateUpdated = { _ in }
        _ = renderView.currentPreviewDisplayState
        let swiftUIView = HarbethRenderView(
            texture: nil,
            dynamicRangePolicy: .standard,
            onPreviewDisplayState: { _ in }
        )
        _ = renderView
        _ = swiftUIView
    }
}
