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
        let swiftUIView = HarbethRenderView(texture: nil)
        _ = renderView
        _ = swiftUIView
    }
}
