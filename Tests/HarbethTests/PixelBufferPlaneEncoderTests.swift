//
//  PixelBufferPlaneEncoderTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/11/11.
//

import CoreVideo
import CoreImage
import Metal
import XCTest
@testable import Harbeth

final class PixelBufferPlaneEncoderTests: XCTestCase {
    func testMaskedGammaKeepsExtendedRangeAndHasExecutableContract() throws {
        let frame = try fixture(alpha: .alphaIsOne)
        let pixel: [Float16] = [-0.25, 2, 4, 1]
        let pixels: [Float16] = Array(repeating: pixel, count: 16).flatMap { $0 }
        pixels.withUnsafeBytes {
            frame.texture.replace(region: MTLRegionMake2D(0, 0, 4, 4), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 32)
        }
        let coverage = try fixture(alpha: .alphaIsOne)
        let node = ImageNode.texture(frame.texture).applying(
            mask: MaskDescriptor(texture: coverage.texture, component: .red), filter: C7Gamma(gamma: 0.5))
        let capability = try node.makeFrameProcessingCapability(
            for: FrameProcessingRequirements(allowsGlobalDependency: true, requiresExtendedRangePreservation: true), profile: .exportQuality)
        XCTAssertTrue(capability.isSupported)
        let rendered = try node.makeFrame(profile: .exportQuality)
        defer { withExtendedLifetime(rendered) {} }
        let output = rendered.texture
        var result = [Float16](repeating: 0, count: 64)
        XCTAssertTrue(result.withUnsafeMutableBytes { output.c7.copyBytes(to: $0.baseAddress!, bytesPerRow: 32) })
        XCTAssertEqual(Float(result[0]), -0.45, accuracy: 0.003)
        XCTAssertEqual(Float(result[2]), 2.4, accuracy: 0.005)
        XCTAssertEqual(Float(result[3]), 1, accuracy: 0.001)
    }

    func testGammaKeepsExtendedValuesFiniteAndPreservesAlpha() throws {
        let frame = try fixture(alpha: .premultiplied)
        let pixels: [Float16] = Array(repeating: [Float16(-0.25), 2, 4, 0.5], count: 16).flatMap { $0 }
        pixels.withUnsafeBytes {
            frame.texture.replace(region: MTLRegionMake2D(0, 0, 4, 4), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 32)
        }
        var io = HarbethIO(element: frame.texture, filter: C7Gamma(gamma: 0.5))
        io.bufferPixelFormat = .rgba16Float
        let result = try io.output()
        var output = [Float16](repeating: 0, count: 64)
        XCTAssertTrue(output.withUnsafeMutableBytes { result.c7.copyBytes(to: $0.baseAddress!, bytesPerRow: 32) })
        XCTAssertEqual(Float(output[0]), -0.5, accuracy: 0.002)
        XCTAssertEqual(Float(output[1]), Float(2).squareRoot(), accuracy: 0.002)
        XCTAssertEqual(Float(output[2]), 2, accuracy: 0.002)
        XCTAssertEqual(Float(output[3]), 0.5, accuracy: 0.002)
    }

    func testNV12AndP010EncodePixelsAndColorAttachments() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("模拟器不支持直接双平面Metal纹理桥接")
        #else
        for format in [kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                       kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr10BiPlanarFullRange] {
            let frame = try fixture(alpha: .alphaIsOne)
            let output = try frame.makePixelBuffer(pixelFormatType: format)
            XCTAssertEqual(CVPixelBufferGetPixelFormatType(output), format)
            XCTAssertEqual(output.c7.contract.colorPrimariesAttachment, .ituR2020)
            XCTAssertEqual(output.c7.contract.transferFunctionAttachment, .ituR2100HLG)
            let tenBit = format == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange || format == kCVPixelFormatType_420YpCbCr10BiPlanarFullRange
            let full = format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange || format == kCVPixelFormatType_420YpCbCr10BiPlanarFullRange
            XCTAssertEqual(CVPixelBufferLockBaseAddress(output, .readOnly), kCVReturnSuccess)
            let y = try XCTUnwrap(CVPixelBufferGetBaseAddressOfPlane(output, 0))
            let uv = try XCTUnwrap(CVPixelBufferGetBaseAddressOfPlane(output, 1))
            let luminance: Float = 0.2627 * 0.8 + (1 - 0.2627 - 0.0593) * 0.4 + 0.0593 * 0.2
            let cb: Float = (0.2 - luminance) / (2 * (1 - 0.0593))
            if tenBit {
                let expectedY = UInt16((luminance * (full ? 1023 : 876) + (full ? 0 : 64)).rounded()) << 6
                let expectedCb = UInt16((cb * (full ? 1023 : 896) + 512).rounded()) << 6
                XCTAssertEqual(Int(y.load(as: UInt16.self)), Int(expectedY), accuracy: 64)
                XCTAssertEqual(Int(uv.load(as: UInt16.self)), Int(expectedCb), accuracy: 64)
                XCTAssertEqual(y.load(as: UInt16.self) & 63, 0)
            } else {
                XCTAssertEqual(Int(y.load(as: UInt8.self)), Int((luminance * (full ? 255 : 219) + (full ? 0 : 16)).rounded()), accuracy: 1)
                XCTAssertEqual(Int(uv.load(as: UInt8.self)), Int((cb * (full ? 255 : 224) + 128).rounded()), accuracy: 1)
            }
            CVPixelBufferUnlockBaseAddress(output, .readOnly)
        }
        #endif
    }

    func testHLGToPQOutputMatchesPlatformLinearColorValues() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("模拟器不支持直接P010纹理桥接")
        #else
        let frame = try fixture(alpha: .alphaIsOne)
        let output = try frame.makePixelBuffer(pixelFormatType: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange, outputColorSpace: .hdrPQ)
        let sourceImage = try XCTUnwrap(CIImage(mtlTexture: frame.texture,
            options: [.colorSpace: CGColorSpace(name: CGColorSpace.itur_2100_HLG)!]))
        let actualImage = CIImage(cvPixelBuffer: output, options: [.toneMapHDRtoSDR: false])
        let context = CIContext(mtlDevice: HarbethContext.shared.device)
        func sample(_ image: CIImage) -> [Float] {
            var pixel = [Float](repeating: 0, count: 4)
            pixel.withUnsafeMutableBytes {
                context.render(image, toBitmap: $0.baseAddress!, rowBytes: 16, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                    format: .RGBAf, colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearITUR_2020)!)
            }
            return pixel
        }
        let expected = sample(sourceImage), actual = sample(actualImage)
        for index in 0..<3 { XCTAssertEqual(actual[index], expected[index], accuracy: max(0.02, abs(expected[index]) * 0.03)) }
        #endif
    }

    func testPlanarOutputRequiresExplicitAlphaDiscard() throws {
        let frame = try fixture(alpha: .premultiplied)
        XCTAssertThrowsError(try frame.makePixelBuffer(pixelFormatType: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange))
    }

    func testRGBAOutputPreservesPremultipliedAlpha() throws {
        let frame = try fixture(alpha: .premultiplied)
        let output = try frame.makePixelBuffer()
        XCTAssertEqual(CVPixelBufferLockBaseAddress(output, .readOnly), kCVReturnSuccess)
        defer { CVPixelBufferUnlockBaseAddress(output, .readOnly) }
        let pixel = try XCTUnwrap(CVPixelBufferGetBaseAddress(output)).assumingMemoryBound(to: Float16.self)
        XCTAssertEqual(Float(pixel[0]), 0.8, accuracy: 0.001)
        XCTAssertEqual(Float(pixel[3]), 0.5, accuracy: 0.001)
    }

    private func fixture(alpha: AlphaType) throws -> RenderedFrame {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: 4, height: 4, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared
        let texture = try XCTUnwrap(HarbethContext.shared.device.makeTexture(descriptor: descriptor))
        let pixel: [Float16] = [0.8, 0.4, 0.2, alpha == .alphaIsOne ? 1 : 0.5]
        let pixels = Array(repeating: pixel, count: 16).flatMap { $0 }
        pixels.withUnsafeBytes {
            texture.replace(region: MTLRegionMake2D(0, 0, 4, 4), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 4 * 8)
        }
        return RenderedFrame(texture: texture, outputColorSpaceContract: .hdrHLG, alphaType: alpha,
                             profile: .exportQuality, generation: 0, identifier: "planar-output-test")
    }
}
