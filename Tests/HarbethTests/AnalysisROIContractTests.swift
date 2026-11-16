//
//  AnalysisROIContractTests.swift
//  HarbethTests
//
//  由 Condy 创建于 2026/11/16。
//

import XCTest
import Metal
@testable import Harbeth

final class AnalysisROIContractTests: XCTestCase {
    func testReadbackROIKeepsGlobalCoordinatesAndUsesROIBytes() throws {
        let texture = try makeTexture(width: 4, height: 3)
        let readback = try XCTUnwrap(TextureAnalysisReadback(texture: texture, region: MTLRegionMake2D(1, 1, 2, 1)))
        XCTAssertEqual(readback.width, 4); XCTAssertEqual(readback.height, 3)
        XCTAssertEqual(readback.regionSize.width, 2); XCTAssertEqual(readback.regionSize.height, 1)
        XCTAssertEqual(readback.data.count, 2 * 4)
        XCTAssertNotNil(readback.color(x: 1, y: 1))
        XCTAssertNil(readback.color(x: 0, y: 0))
    }

    func testEmptyROIReturnsEmptyStatisticsAndHistogram() throws {
        let texture = try makeTexture(width: 2, height: 2)
        let empty = MTLRegionMake2D(2, 2, 1, 1)
        let statistics = texture.c7.makeStatistics(region: empty)
        XCTAssertEqual(statistics?.sampleCount, 0)
        let histogram = texture.c7.makeHistogram(region: empty)
        XCTAssertEqual(histogram?.totalSampleCount, 0)
        XCTAssertEqual(histogram?.bins.reduce(0, +), 0)
    }

    func testRGBA8ROIValuesAreReadAtGlobalCoordinates() throws {
        let texture = try makeTexture(width: 4, height: 3)
        let readback = try XCTUnwrap(TextureAnalysisReadback(texture: texture, region: MTLRegionMake2D(1, 1, 2, 1)))
        let value = try XCTUnwrap(readback.color(x: 2, y: 1))
        XCTAssertEqual(value.x, 127.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(value.w, 127.0 / 255.0, accuracy: 0.001)
    }

    func testFloatFormatsAndSRGBROIReadback() throws {
        for format in [MTLPixelFormat.r16Float, .r32Float, .rgba8Unorm_srgb] {
            let texture = try makeTypedTexture(format: format, width: 3, height: 2)
            let readback = try XCTUnwrap(TextureAnalysisReadback(texture: texture, region: MTLRegionMake2D(1, 0, 1, 1)))
            XCTAssertEqual(readback.data.count, readback.regionSize.width * readback.regionSize.height * (format == .r16Float ? 2 : (format == .r32Float ? 4 : 4)))
            XCTAssertNotNil(readback.color(x: 1, y: 0))
        }
    }

    func testNaNHistogramReturnsNilWithoutTrap() throws {
        let texture = try makeTypedTexture(format: .r32Float, width: 1, height: 1, value: .nan)
        XCTAssertNil(texture.c7.makeHistogram(channel: .red, preferredMethod: .cpuReadback))
    }

    func testUnsupportedShapeAndFormatStayNilEvenForEmptyROI() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let arrayDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 2, height: 2, mipmapped: false)
        arrayDescriptor.textureType = .type2DArray
        arrayDescriptor.arrayLength = 2; arrayDescriptor.usage = [.shaderRead, .shaderWrite]
        let arrayTexture = try XCTUnwrap(device.makeTexture(descriptor: arrayDescriptor))
        XCTAssertNil(TextureAnalysisReadback(texture: arrayTexture, region: MTLRegionMake2D(2, 2, 1, 1)))
        XCTAssertNil(arrayTexture.c7.makeStatistics(region: MTLRegionMake2D(2, 2, 1, 1)))
        let uintDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Uint, width: 2, height: 2, mipmapped: false)
        uintDescriptor.usage = [.shaderRead, .shaderWrite]
        let uintTexture = try XCTUnwrap(device.makeTexture(descriptor: uintDescriptor))
        XCTAssertNil(TextureAnalysisReadback(texture: uintTexture, region: MTLRegionMake2D(2, 2, 1, 1)))
        XCTAssertNil(uintTexture.c7.makeHistogram(region: MTLRegionMake2D(2, 2, 1, 1)))
    }

    private func makeTexture(width: Int, height: Int) throws -> MTLTexture {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let bytes = Array(repeating: UInt8(127), count: width * height * 4)
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bytes, bytesPerRow: width * 4)
        return texture
    }

    private func makeTypedTexture(format: MTLPixelFormat, width: Int, height: Int, value: Float = 0.25) throws -> MTLTexture {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        if format == .r16Float {
            let bits = [UInt16](repeating: 0x3400, count: width * height)
            bits.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 2) }
        } else if format == .r32Float {
            let values = [Float](repeating: value, count: width * height)
            values.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 4) }
        } else {
            let bytes = Array(repeating: UInt8(64), count: width * height * 4)
            texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bytes, bytesPerRow: width * 4)
        }
        return texture
    }
}
