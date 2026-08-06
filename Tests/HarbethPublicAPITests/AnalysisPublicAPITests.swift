import XCTest
import Metal
import Harbeth

final class AnalysisPublicAPITests: XCTestCase {
    func testAnalysisContractsCompileFromPublicModule() {
        let range = TextureAnalysisValueRange(minimum: -0.5, maximum: 4)
        let scope = TextureAnalysisScope(
            luminanceRange: TextureLuminanceRange(minimum: -0.25, maximum: 2),
            valueRange: range
        )
        let configuration = TextureImageScopeConfiguration(
            kind: .rgbWaveform,
            valueRange: range,
            normalizesDensity: true
        )
        let encode: (MTLTexture, MTLCommandBuffer) throws -> RenderedTextureImageScope = { texture, commandBuffer in
            try texture.c7.encodeImageScope(configuration, into: commandBuffer)
        }

        XCTAssertEqual(scope.valueRange, range)
        XCTAssertEqual(configuration.valueRange, range)
        XCTAssertEqual(TextureAnalysisComponentDomain.textureStorage.rawValue, "textureStorage")
        _ = encode
    }
}
