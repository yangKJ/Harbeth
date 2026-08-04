import XCTest
import CoreImage
import Metal
@testable import Harbeth

final class CIImageSourceTests: XCTestCase {
    func testHarbethIOProcessesCIImageAndReturnsCIImage() throws {
        try requireMetal()
        let source = makeCIImage(width: 4, height: 3)

        let output: CIImage = try HarbethIO(
            element: source,
            filters: [C7Brightness(brightness: 0)]
        ).output()

        XCTAssertEqual(output.extent, CGRect(x: 0, y: 0, width: 4, height: 3))
        XCTAssertNotNil(output.cgImage)
    }

    func testTypedTextureBackedFrameMaterializesEmptyFilterChainOnGPU() throws {
        try requireMetal()
        let source = makeCIImage(width: 4, height: 3)

        let output = try HarbethIO(element: source, filters: []).outputTextureBackedFrame()

        XCTAssertEqual(output.image.extent, source.extent)
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, *) {
            XCTAssertNotNil(output.image.metalTexture)
            XCTAssertNil(output.image.cgImage)
        }
    }

    func testTextureLoaderKeepsFiniteCIImageInputOnGPU() throws {
        try requireMetal()
        let source = makeCIImage(width: 4, height: 3)

        let texture = try TextureLoader(with: source).texture

        XCTAssertEqual(texture.width, 4)
        XCTAssertEqual(texture.height, 3)
    }

    func testTypedTextureBackedFrameRetainsOutputContracts() throws {
        try requireMetal()
        let source = makeCIImage(width: 4, height: 3)
            .transformed(by: CGAffineTransform(translationX: 7, y: 11))

        let output = try HarbethIO(
            element: source,
            filters: [C7PremultiplyAlpha()]
        )
        .configured(for: .responseLatency)
        .outputTextureBackedFrame(outputColorSpace: .displayP3)

        XCTAssertEqual(output.image.extent, source.extent)
        XCTAssertEqual(output.sourceDescriptor.kind, "ciImage")
        XCTAssertEqual(output.outputColorSpaceContract, .displayP3)
        XCTAssertEqual(output.outputDynamicRange, .standardDynamicRange)
        XCTAssertEqual(output.outputToneMappingPolicy, .preserveInput)
        XCTAssertEqual(output.profile, .responseLatency)
        XCTAssertNil(output.image.cgImage)
        XCTAssertEqual(output.texture.width, 4)
        XCTAssertEqual(output.texture.height, 3)
    }

    func testTypedTextureBackedFrameOwnsManagedTextureLease() throws {
        try requireMetal()
        HarbethContext.shared.recoverExecution()
        var output: TextureBackedCIImageFrame? = try HarbethIO(
            element: makeCIImage(width: 9, height: 7),
            filters: [C7Brightness(brightness: 0.1)]
        ).outputTextureBackedFrame()
        let texture = try XCTUnwrap(output?.texture)

        XCTAssertNil(
            HarbethContext.shared.texturePool.dequeueExactTexture(
                width: texture.width,
                height: texture.height,
                pixelFormat: texture.pixelFormat
            )
        )

        output = nil

        let reused = HarbethContext.shared.texturePool.dequeueExactTexture(
            width: texture.width,
            height: texture.height,
            pixelFormat: texture.pixelFormat
        )
        XCTAssertTrue(reused === texture)
    }

    func testHarbethIOTransmitsCIImageAsynchronously() throws {
        try requireMetal()
        let expectation = expectation(description: "CIImage asynchronous output")
        let source = makeCIImage(width: 4, height: 3)

        HarbethIO(element: source, filters: [C7Brightness(brightness: 0)])
            .transmitOutput { (result: Result<CIImage, HarbethError>) in
                switch result {
                case .success(let output):
                    XCTAssertEqual(output.extent, CGRect(x: 0, y: 0, width: 4, height: 3))
                case .failure(let error):
                    XCTFail("Unexpected CIImage output failure: \(error)")
                }
                expectation.fulfill()
            }

        wait(for: [expectation], timeout: 2)
    }

    func testCIImageOperatorsRemainCompatible() throws {
        try requireMetal()
        let source = makeCIImage(width: 4, height: 3)

        let single = source ->> C7Brightness(brightness: 0)
        let grouped = source -->>> [C7Brightness(brightness: 0)]

        XCTAssertEqual(single.extent, CGRect(x: 0, y: 0, width: 4, height: 3))
        XCTAssertEqual(grouped.extent, CGRect(x: 0, y: 0, width: 4, height: 3))
    }

    func testHarbethIORenderFrameAcceptsCIImage() throws {
        try requireMetal()

        let frame = try HarbethIO(element: makeCIImage(width: 5, height: 2), filters: [])
            .renderFrame(profile: .stablePreview)

        XCTAssertEqual(frame.sourceDescriptor.kind, "ciImage")
        XCTAssertEqual(frame.texture.width, 5)
        XCTAssertEqual(frame.texture.height, 2)
    }

    func testImageNodeAcceptsCIImage() throws {
        try requireMetal()

        let texture = try ImageNode
            .ciImage(makeCIImage(width: 6, height: 4))
            .applying(C7Brightness(brightness: 0))
            .makeTexture(profile: .stablePreview)

        XCTAssertEqual(texture.width, 6)
        XCTAssertEqual(texture.height, 4)
    }

    func testPluginOutputTreatsCIImageAsSource() throws {
        try requireMetal()
        let output = PluginOutput.ciImage(makeCIImage(width: 3, height: 2))

        XCTAssertTrue(output.isSourceLike)
        XCTAssertEqual(output.kind, "ciImage")
        XCTAssertEqual(try output.sourceDescriptor().kind, "ciImage")

        let texture = try ImageNode
            .texture(try TextureLoader.makeTexture(width: 1, height: 1))
            .applying(pluginOutput: output)
            .makeTexture(profile: .stablePreview)
        XCTAssertEqual(texture.width, 3)
        XCTAssertEqual(texture.height, 2)
    }

    func testInfiniteExtentCIImageFailsExplicitly() throws {
        try requireMetal()
        let source = CIImage(color: CIColor(red: 1, green: 0, blue: 0))

        XCTAssertThrowsError(try ImageSource.ciImage(source).makeTexture()) { error in
            guard case HarbethError.configurationInvalid(let message) = error else {
                return XCTFail("Expected configurationInvalid, got \(error)")
            }
            XCTAssertTrue(message.contains("finite"))
        }
    }

    private func makeCIImage(width: Int, height: Int) -> CIImage {
        CIImage(color: CIColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 1))
            .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    }

    private func requireMetal() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")
    }
}
