import XCTest
import ImageIO
@testable import Harbeth

final class ImageLoadingOptionsTests: XCTestCase {

    func testLoadingOptionsFingerprintChangesWithSizePolicy() {
        let original = ImageLoadingOptions()
        let downsampled = ImageLoadingOptions(sizePolicy: .maxPixelSize(1024))
        let flipped = ImageLoadingOptions(sizePolicy: .maxPixelSize(1024), flipsVertically: true)

        XCTAssertNotEqual(original.fingerprint, downsampled.fingerprint)
        XCTAssertNotEqual(downsampled.fingerprint, flipped.fingerprint)
        XCTAssertTrue(downsampled.fingerprint.contains("size=maxPixel:1024"))
        XCTAssertTrue(flipped.fingerprint.contains("flip=1"))
    }

    func testDataLoadingOptionsCanDownsampleBeforeTextureUpload() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let image = try makeFixtureCGImage(width: 8, height: 4)
        let data = try makePNGData(from: image)

        let texture = try TextureLoader(
            with: data,
            loadingOptions: ImageLoadingOptions(sizePolicy: .maxPixelSize(2))
        ).texture

        XCTAssertEqual(texture.width, 2)
        XCTAssertEqual(texture.height, 1)
    }

    func testImageAssetDescriptorIncludesLoadingFingerprint() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let image = try makeFixtureCGImage(width: 8, height: 4)
        let asset = ImageAsset(
            storage: .cgImage(image),
            loadingOptions: ImageLoadingOptions(sizePolicy: .fit(width: 3, height: 3), flipsVertically: true),
            sourceTier: .thumbnail
        )

        let descriptor = ImageSource.asset(asset).descriptor

        XCTAssertEqual(descriptor.kind, "cgImageAsset")
        XCTAssertEqual(descriptor.sourceTier, .thumbnail)
        XCTAssertEqual(descriptor.loadingOptions.sizePolicy, .fit(width: 3, height: 3))
        XCTAssertTrue(descriptor.fingerprint.contains("tier=thumbnail"))
        XCTAssertTrue(descriptor.fingerprint.contains("size=fit:3x3"))
        XCTAssertTrue(descriptor.fingerprint.contains("flip=1"))
    }

    func testHarbethIOCanAcceptURLAssetSource() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let image = try makeFixtureCGImage(width: 8, height: 4)
        let data = try makePNGData(from: image)
        let url = try writeTemporaryPNG(data: data)

        let asset = ImageAsset(
            storage: .url(url),
            loadingOptions: ImageLoadingOptions(sizePolicy: .maxPixelSize(4)),
            sourceTier: .stableReusable
        )
        let frame = try HarbethIO(element: asset, filters: [])
            .renderFrame(profile: .stablePreview)

        XCTAssertEqual(frame.size.width, 4)
        XCTAssertEqual(frame.size.height, 2)
        XCTAssertEqual(frame.sourceTier, .stableReusable)
        XCTAssertEqual(frame.renderIntent, .stable)
    }

    func testImageNodeCanAcceptDataSource() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let image = try makeFixtureCGImage(width: 8, height: 4)
        let data = try makePNGData(from: image)

        let texture = try ImageNode
            .data(data)
            .applying(C7Brightness(brightness: 0))
            .makeTexture(profile: .stablePreview)

        XCTAssertEqual(texture.width, 8)
        XCTAssertEqual(texture.height, 4)
    }

    func testImageNodeCanAcceptAssetSourceWithLoadingOptions() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let image = try makeFixtureCGImage(width: 8, height: 4)
        let asset = ImageAsset(
            storage: .cgImage(image),
            loadingOptions: ImageLoadingOptions(sizePolicy: .maxPixelSize(4)),
            sourceTier: .thumbnail
        )

        let frame = try ImageNode
            .asset(asset)
            .applying(C7Brightness(brightness: 0))
            .makeFrame(profile: .stablePreview)

        XCTAssertEqual(frame.size.width, 4)
        XCTAssertEqual(frame.size.height, 2)
        XCTAssertEqual(frame.sourceTier, .thumbnail)
    }

    func testHarbethIOCGImageOutputAppliesExplicitRenderOutputColorSpace() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let image = try makeFixtureCGImage(width: 4, height: 4)
        let output: CGImage = try HarbethIO(
            element: image,
            filters: [CGImageDisplayP3RenderFilter()]
        ).output()

        XCTAssertEqual(output.colorSpace?.name as String?, CGColorSpace.displayP3 as String)
    }

    func testHarbethIOCGImageOutputPreservesSourceColorSpaceWithoutExplicitContract() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let displayP3 = try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))
        let image = try makeFixtureCGImage(width: 4, height: 4, colorSpace: displayP3)

        let output: CGImage = try HarbethIO(
            element: image,
            filters: [C7Brightness(brightness: 0.0)]
        ).output()

        XCTAssertEqual(output.colorSpace?.name as String?, CGColorSpace.displayP3 as String)
    }

    func testZeroBrightnessPreservesDisplayP3JPEGAppearanceForCGImage() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let source = try makeDisplayP3JPEGFixture()
        let output: CGImage = try HarbethIO(
            element: source,
            filters: [C7Brightness(brightness: 0.0)]
        ).output()

        XCTAssertEqual(output.colorSpace?.name as String?, source.colorSpace?.name as String?)
        try assertVisuallyEquivalent(source, output)
    }

    func testZeroBrightnessPreservesDisplayP3JPEGAppearanceForC7Image() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let sourceCGImage = try makeDisplayP3JPEGFixture()
        let source = C7Image(cgImage: sourceCGImage)
        let output: C7Image = try HarbethIO(
            element: source,
            filters: [C7Brightness(brightness: 0.0)]
        ).output()
        let outputCGImage = try XCTUnwrap(output.c7.toCGImage())

        XCTAssertEqual(outputCGImage.colorSpace?.name as String?, sourceCGImage.colorSpace?.name as String?)
        try assertVisuallyEquivalent(sourceCGImage, outputCGImage)
    }

    private func makeFixtureCGImage(width: Int,
                                    height: Int,
                                    colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()) throws -> CGImage {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                bytes[offset] = UInt8((x * 255) / max(width - 1, 1))
                bytes[offset + 1] = UInt8((y * 255) / max(height - 1, 1))
                bytes[offset + 2] = 128
                bytes[offset + 3] = 255
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bitsPerPixel: 32,
                                  bytesPerRow: width * 4,
                                  space: colorSpace,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider,
                                  decode: nil,
                                  shouldInterpolate: false,
                                  intent: .defaultIntent) else {
            throw XCTSkip("Failed to create CGImage fixture.")
        }
        return image
    }

    private func makePNGData(from image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            throw XCTSkip("Failed to create PNG destination.")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw XCTSkip("Failed to finalize PNG data.")
        }
        return data as Data
    }

    private func makeDisplayP3JPEGFixture() throws -> CGImage {
        let displayP3 = try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))
        let image = try makeFixtureCGImage(width: 64, height: 48, colorSpace: displayP3)
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else {
            throw XCTSkip("Failed to create JPEG destination.")
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination),
              let source = CGImageSourceCreateWithData(data, nil),
              let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw XCTSkip("Failed to finalize or decode Display P3 JPEG data.")
        }
        return decoded
    }

    private func assertVisuallyEquivalent(_ source: CGImage,
                                          _ output: CGImage,
                                          file: StaticString = #filePath,
                                          line: UInt = #line) throws {
        let sourceBytes = try makeSRGBBytes(from: source)
        let outputBytes = try makeSRGBBytes(from: output)
        XCTAssertEqual(sourceBytes.count, outputBytes.count, file: file, line: line)
        guard sourceBytes.count == outputBytes.count else { return }

        let differences = zip(sourceBytes, outputBytes).map { abs(Int($0) - Int($1)) }
        let maximumDifference = differences.max() ?? 0
        let meanDifference = Double(differences.reduce(0, +)) / Double(max(differences.count, 1))
        XCTAssertLessThanOrEqual(maximumDifference, 1, "Identity filtering changed a rendered sRGB channel by more than one level.", file: file, line: line)
        XCTAssertLessThanOrEqual(meanDifference, 0.05, "Identity filtering changed the rendered JPEG appearance.", file: file, line: line)
    }

    private func makeSRGBBytes(from image: CGImage) throws -> [UInt8] {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        guard let context = CGContext(
            data: &bytes,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw XCTSkip("Failed to create sRGB comparison context.")
        }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return bytes
    }

    private func writeTemporaryPNG(data: Data) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        try data.write(to: url)
        return url
    }
}

private struct CGImageDisplayP3RenderFilter: RenderProtocol {
    var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "basicFragment")
    }

    var renderSamplerConsumption: RenderSamplerConsumption { .runtimeBound }

    var renderOutputContract: RenderOutputContract {
        RenderOutputContract(colorSpace: .displayP3)
    }
}
