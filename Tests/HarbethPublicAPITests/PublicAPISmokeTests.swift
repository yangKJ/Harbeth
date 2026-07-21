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

    @MainActor
    func testPreviewHostSurfacesCompile() {
        let renderView = RenderView(frame: .zero, device: nil)
        renderView.resizingMode = .aspectFit
        let swiftUIView = HarbethRenderView(texture: nil)
        _ = renderView
        _ = swiftUIView
    }
}
