import CoreGraphics
import Harbeth
import Metal
import XCTest

final class GPUPrimitivePublicAPITests: XCTestCase {

    func testSharedColorDepthAndGridContractsRequireOnlyHarbeth() throws {
        let rgb = SIMD3<Float>(0.2, 0.6, 0.9)
        let restored = RGBColorMath.rgb(fromOKLab: RGBColorMath.oklab(rgb, space: .sRGB), space: .sRGB)
        for channel in 0..<3 { XCTAssertEqual(restored[channel], rgb[channel], accuracy: 0.0001) }
        let depth = C7DepthLensBlur.deferred(DepthLensBlurDescriptor(blurRadius: 11))
        XCTAssertEqual(depth.computeKernelLibrarySource, .harbethFramework)
        XCTAssertEqual(depth.kernelPixelContract.samplingFootprint, .neighborhood(radius: 22))
        let grid = try InverseCoordinateGrid(width: 2, height: 2, points: [
            CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1)
        ])
        let extent = CGRect(x: 0, y: 0, width: 32, height: 32)
        XCTAssertEqual(grid.sourceRegion(for: extent, extent: extent), extent)
    }

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
        let gaussian: any C7FilterProtocol = try MPSGaussianBlur(sigma: 2.1)
        let lanczos: any C7FilterProtocol = try MPSLanczosResize(width: 4, height: 3)
        let morphology: any C7FilterProtocol = MPSMorphology(operation: .dilate)
        let mesh: any C7FilterProtocol = try RenderMeshWarp.identity(rows: 2, columns: 2)
        let layer: any C7FilterProtocol = try RenderLayerComposite(layerTexture: texture)
        let mask: any C7FilterProtocol = try RenderVectorMask(points: [
            .init(x: 0, y: 0), .init(x: 1, y: 0), .init(x: 0, y: 1)
        ])

        XCTAssertFalse([convolution, gaussian, lanczos, morphology, mesh, layer, mask].contains { $0.identifier.isEmpty })
    }
}
