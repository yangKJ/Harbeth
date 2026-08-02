import XCTest
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
        let configure: (MTLTexture) -> HarbethIO<MTLTexture> = { texture in
            HarbethIO(element: texture, filters: []).configured(for: .interactiveLatency)
        }
        _ = render
        _ = transmit
        _ = configure
    }

    func testCanonicalImageNodeSurfaceCompiles() {
        let build: (MTLTexture) -> ImageNode = { texture in ImageNode.texture(texture).withCachePolicy(.transient) }
        _ = build
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
            context.performanceMonitor.configure(.init(enabled: false))
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
