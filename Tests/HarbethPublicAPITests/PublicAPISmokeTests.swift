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

    @MainActor
    func testPreviewHostSurfacesCompile() {
        let renderView = RenderView(frame: .zero, device: nil)
        renderView.resizingMode = .aspectFit
        let swiftUIView = HarbethRenderView(texture: nil)
        _ = renderView
        _ = swiftUIView
    }
}
