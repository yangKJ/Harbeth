import Harbeth
import Metal
import XCTest

final class GPUPrimitivePublicAPITests: XCTestCase {

    func testPipelineFiltersArePubliclyConstructible() {
        let smoothing: any C7FilterProtocol = C7HighPassSkinSmoothing(amount: 0.5, radius: 6, sharpnessFactor: 0.2)
        let document: any C7FilterProtocol = C7DocumentBinarization(radius: 16, threshold: 0.1)
        let highlightShadow: any C7FilterProtocol = C7HighlightShadowTone(shadows: 0.2, highlights: -0.1, radius: 18)
        let bokeh: any C7FilterProtocol = C7HexagonalBokehBlur(radius: 8, brightness: 0.4, angle: 15)

        XCTAssertFalse([smoothing, document, highlightShadow, bokeh].contains { $0.identifier.isEmpty })
    }

    func testMPSAndRenderPrimitivesArePubliclyConstructible() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 2,
            height: 2,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))

        let convolution: any C7FilterProtocol = try MPSConvolution(
            kernelWidth: 3,
            kernelHeight: 3,
            weights: [0, 0, 0, 0, 1, 0, 0, 0, 0]
        )
        let lanczos: any C7FilterProtocol = try MPSLanczosResize(width: 4, height: 3)
        let morphology: any C7FilterProtocol = MPSMorphology(operation: .dilate)
        let mesh: any C7FilterProtocol = try RenderMeshWarp.identity(rows: 2, columns: 2)
        let layer: any C7FilterProtocol = try RenderLayerComposite(layerTexture: texture)
        let mask: any C7FilterProtocol = try RenderVectorMask(points: [
            .init(x: 0, y: 0), .init(x: 1, y: 0), .init(x: 0, y: 1)
        ])

        XCTAssertFalse([convolution, lanczos, morphology, mesh, layer, mask].contains { $0.identifier.isEmpty })
    }
}
