//
//  ColorCubeTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/7/28.
//

import XCTest
import Metal
@testable import Harbeth

final class ColorCubeTests: XCTestCase {
    func testCubeParserPreservesDomainAndStableIdentity() throws {
        let first = try C7ColorCube.Resource.parse(contents: identityCube)
        let second = try C7ColorCube.Resource.parse(contents: identityCube)

        XCTAssertEqual(first.dimension, 2)
        XCTAssertEqual(first.domainMinimum, SIMD3<Float>(-0.25, 0, 0.1))
        XCTAssertEqual(first.domainMaximum, SIMD3<Float>(1.25, 1, 1.1))
        XCTAssertEqual(first.data.count, 2 * 2 * 2 * 4 * MemoryLayout<Float>.size)
        XCTAssertEqual(first.identity, second.identity)
    }

    func testCubeParserRejectsIncompleteAndOneDimensionalResources() {
        XCTAssertThrowsError(try C7ColorCube.Resource.parse(contents: "LUT_3D_SIZE 2\n0 0 0"))
        XCTAssertThrowsError(try C7ColorCube.Resource.parse(contents: "LUT_1D_SIZE 2\n0 0 0\n1 1 1"))
    }

    func testCubeResourceUsesCachedThreeDimensionalTexture() throws {
        let resource = try C7ColorCube.Resource.parse(contents: identityCube)
        let first = C7ColorCube(cubeResource: resource)
        let second = C7ColorCube(cubeResource: resource)
        let firstTexture = try XCTUnwrap(first.otherInputTextures.first)
        let secondTexture = try XCTUnwrap(second.otherInputTextures.first)

        XCTAssertEqual(firstTexture.textureType, .type3D)
        XCTAssertEqual(firstTexture.width, 2)
        XCTAssertEqual(firstTexture.height, 2)
        XCTAssertEqual(firstTexture.depth, 2)
        XCTAssertTrue(firstTexture === secondTexture)
        XCTAssertEqual(first.interpolation, .tetrahedral)
        XCTAssertEqual(first.kernelResourceIdentity, resource.identity)
    }

    func testCubeResourceIdentityParticipatesInRenderRecipeFingerprint() throws {
        let identity = try C7ColorCube.Resource.parse(contents: unitIdentityCube)
        let inverted = try C7ColorCube.Resource.parse(contents: unitIdentityCube.replacingOccurrences(of: "1 0 0", with: "0 1 1"))

        XCTAssertNotEqual(
            C7ColorCube(cubeResource: identity).recipeDescriptor.fingerprint,
            C7ColorCube(cubeResource: inverted).recipeDescriptor.fingerprint
        )
    }

    func testTetrahedralIdentityCubePreservesPrimaryColors() throws {
        let input = try makeTexture(pixel: [255, 0, 0, 255])
        let resource = try C7ColorCube.Resource.parse(contents: unitIdentityCube)
        let output: MTLTexture = try HarbethIO(
            element: input,
            filter: C7ColorCube(cubeResource: resource, interpolation: .tetrahedral)
        ).output()
        var pixel = [UInt8](repeating: 0, count: 4)
        output.getBytes(&pixel, bytesPerRow: 4, from: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0)

        XCTAssertEqual(pixel[0], 255)
        XCTAssertLessThanOrEqual(pixel[1], 1)
        XCTAssertLessThanOrEqual(pixel[2], 1)
        XCTAssertEqual(pixel[3], 255)
    }

    private var identityCube: String {
        """
        TITLE "Domain Identity"
        LUT_3D_SIZE 2
        DOMAIN_MIN -0.25 0 0.1
        DOMAIN_MAX 1.25 1 1.1
        0 0 0
        1 0 0
        0 1 0
        1 1 0
        0 0 1
        1 0 1
        0 1 1
        1 1 1
        """
    }

    private var unitIdentityCube: String {
        """
        LUT_3D_SIZE 2
        0 0 0
        1 0 0
        0 1 0
        1 1 0
        0 0 1
        1 0 1
        0 1 1
        1 1 1
        """
    }

    private func makeTexture(pixel: [UInt8]) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw XCTSkip("Could not create Metal texture.")
        }
        texture.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: pixel, bytesPerRow: 4)
        return texture
    }
}
