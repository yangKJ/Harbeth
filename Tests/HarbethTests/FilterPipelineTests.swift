import XCTest
import Metal
@testable import Harbeth

final class FilterPipelineTests: XCTestCase {

    func testNestedPipelineExecutesChildrenThroughErasedProtocol() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        HarbethContext.shared.recoverExecution()
        let library = try device.makeLibrary(source: """
        #include <metal_stdlib>
        using namespace metal;
        kernel void pipelineRegressionAdd(texture2d<half, access::write> dst [[texture(0)]],
            texture2d<half, access::read> src [[texture(1)]], uint2 p [[thread_position_in_grid]]) {
            if (p.x >= dst.get_width() || p.y >= dst.get_height()) return;
            half4 v = src.read(p); dst.write(half4(v.rgb + half3(0.125h), v.a), p);
        }
        kernel void pipelineRegressionCopy(texture2d<half, access::write> dst [[texture(0)]],
            texture2d<half, access::read> src [[texture(1)]],
            texture2d<half, access::read> child [[texture(2)]], uint2 p [[thread_position_in_grid]]) {
            if (p.x >= dst.get_width() || p.y >= dst.get_height()) return;
            dst.write(child.read(p), p);
        }
        kernel void pipelineRegressionMean(texture2d<half, access::write> dst [[texture(0)]],
            texture2d<half, access::read> src [[texture(1)]],
            texture2d<half, access::read> a [[texture(2)]],
            texture2d<half, access::read> b [[texture(3)]], uint2 p [[thread_position_in_grid]]) {
            if (p.x >= dst.get_width() || p.y >= dst.get_height()) return;
            dst.write((a.read(p) + b.read(p)) * half(0.5), p);
        }
        """, options: nil)
        let provider = PipelineRegressionLibrary(library: library)
        XCTAssertTrue(Device.registerExternalLibraryProvider(provider))
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: 1, height: 1, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead, .shaderWrite]
        let input = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let pixel: [Float16] = [0.25, 0.375, 0.5, 0.5]
        pixel.withUnsafeBytes { input.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 8) }
        let child = PipelineRegressionFilter(filters: [PipelineLeafFilter(modifier: .compute(kernel: "pipelineRegressionAdd"))])
        for style in [FilterPipelineExecutionStyle.sequential, .parallelFromSource] {
            let erased: C7FilterProtocol = PipelineRegressionFilter(filters: [child, child], style: style)
            let destination = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
            let command = try XCTUnwrap(device.makeCommandQueue()?.makeCommandBuffer())
            let output = try erased.applyAtTexture(form: input, to: destination, for: command)
            let readback = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
            let blit = try XCTUnwrap(command.makeBlitCommandEncoder())
            blit.copy(from: output, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                sourceSize: MTLSize(width: 1, height: 1, depth: 1), to: readback, destinationSlice: 0,
                destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
            blit.endEncoding(); command.commit(); command.waitUntilCompleted()
            XCTAssertNil(command.error)
            var actual = [Float16](repeating: 0, count: 4)
            actual.withUnsafeMutableBytes { readback.getBytes($0.baseAddress!, bytesPerRow: 8, from: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0) }
            let increase: Float16 = style == .sequential ? 0.25 : 0.125
            XCTAssertEqual(actual, [pixel[0] + increase, pixel[1] + increase, pixel[2] + increase, pixel[3]])
        }
    }

    func testCombinationFiltersUsePipelineProtocol() {
        let filter = C7CombinationCinematic(intensity: 0.7)
        let erased: C7FilterProtocol = filter

        XCTAssertTrue(erased is C7FilterPipelineProtocol)
        XCTAssertEqual(filter.pipelineExecutionStyle, .sequential)
        XCTAssertEqual(filter.pipelineFilters.count, 5)
    }

    func testRecipeDescriptorTracksPipelineFingerprintChanges() {
        let filter = C7CombinationVintage(intensity: 0.8)
        let initialDescriptor = filter.recipeDescriptor

        filter.dustIntensity = 0.55
        let updatedDescriptor = filter.recipeDescriptor

        XCTAssertNotEqual(initialDescriptor.fingerprint, updatedDescriptor.fingerprint)
        XCTAssertFalse(updatedDescriptor.pipelineFilterFingerprints.isEmpty)
        XCTAssertNotNil(updatedDescriptor.finalFilterFingerprint)
    }

    func testRenderGraphMarksPipelineFilterAsCombinationNode() {
        let plan = GraphCompiler.compile(
            filters: [C7CombinationBeautiful(intensity: 0.6)],
            inputSize: C7Size(width: 32, height: 32),
            profile: .stablePreview
        )

        XCTAssertEqual(plan.graph.nodes.count, 1)
        XCTAssertEqual(plan.graph.nodes.first?.kind, .combination)
        XCTAssertTrue(plan.graph.nodes.first?.breaksFusion ?? false)
    }

    func testPipelineCombinationRendersTexture() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()

        let input = try TextureLoader.makeTexture(
            width: 8,
            height: 6,
            options: [.texturePixelFormat: MTLPixelFormat.rgba8Unorm],
            identifier: "filter-pipeline-input"
        )

        let output: MTLTexture = try HarbethIO(element: input, filters: [C7CombinationVintageFilm(intensity: 0.75)])
            .renderTexture(profile: .stablePreview)

        XCTAssertEqual(output.width, 8)
        XCTAssertEqual(output.height, 6)
    }

    func testPipelineProtocolDefaultApplyAtTextureSupportsCustomPipelineFilter() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        HarbethContext.shared.recoverExecution()

        let input = try TextureLoader.makeTexture(
            width: 6,
            height: 4,
            options: [.texturePixelFormat: MTLPixelFormat.rgba8Unorm],
            identifier: "filter-pipeline-default-apply-input"
        )

        let output: MTLTexture = try HarbethIO(element: input, filters: [TestDefaultPipelineFilter()]).renderTexture(
            profile: .stablePreview
        )

        XCTAssertEqual(output.width, 6)
        XCTAssertEqual(output.height, 4)
    }
}

private struct TestDefaultPipelineFilter: C7FilterPipelineProtocol {
    var pipelineFilters: [C7FilterProtocol] { [C7Brightness(brightness: 0.05)] }

    func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? {
        PipelineLeafFilter(modifier: .compute(kernel: "C7Contrast"), factors: [1.02])
    }
}

private struct PipelineRegressionFilter: C7FilterPipelineProtocol {
    let filters: [C7FilterProtocol]
    var style: FilterPipelineExecutionStyle = .sequential
    var pipelineFilters: [C7FilterProtocol] { filters }
    var pipelineExecutionStyle: FilterPipelineExecutionStyle { style }
    func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? {
        PipelineLeafFilter(modifier: .compute(kernel: style == .sequential ? "pipelineRegressionCopy" : "pipelineRegressionMean"), otherInputTextures: otherInputTextures ?? [])
    }
}

private struct PipelineRegressionLibrary: ExternalMTLLibraryProvider {
    let library: MTLLibrary
    let providerIdentifier = "pipeline.regression." + UUID().uuidString
    func provideLibrary(for device: MTLDevice) -> MTLLibrary? {
        library.device.registryID == device.registryID ? library : nil
    }
}
