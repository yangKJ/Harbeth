//
//  ColorCubeTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/7/28.
//

import XCTest
import Compression
import CryptoKit
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

    func testCubeParserIgnoresFullLineAndTrailingComments() throws {
        let contents = """
        # Project-owned generated LUT
        LUT_3D_SIZE 2 # eight RGB samples follow
        0 0 0
        1 0 0
        0 1 0
        1 1 0
        0 0 1
        1 0 1
        0 1 1
        1 1 1 # white corner
        """

        let resource = try C7ColorCube.Resource.parse(contents: contents)

        XCTAssertEqual(resource.dimension, 2)
        XCTAssertEqual(resource.data.count, 2 * 2 * 2 * 4 * MemoryLayout<Float>.size)
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

    func testCompactLookupResourcePreservesCubeDataAndBuildsTexture() throws {
        let source = try C7ColorCube.Resource.parse(contents: identityCube)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("identity.hlut")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try compactLookupData(from: source).write(to: url)

        let decoded = try XCTUnwrap(C7ColorCube.Resource.readCompactResource(from: url))
        let cube = C7ColorCube(cubeResource: decoded)

        XCTAssertEqual(decoded.dimension, source.dimension)
        XCTAssertEqual(decoded.domainMinimum, source.domainMinimum)
        XCTAssertEqual(decoded.domainMaximum, source.domainMaximum)
        XCTAssertEqual(decoded.data, source.data)
        XCTAssertEqual(decoded.identity, source.identity)
        XCTAssertEqual(cube.otherInputTextures.first?.textureType, .type3D)
    }

    func testCompactLookupRejectsChecksumMismatchExplicitly() throws {
        let source = try C7ColorCube.Resource.parse(contents: identityCube)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("identity.hlut")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var encoded = try compactLookupData(from: source)
        encoded[40] ^= 0xFF
        try encoded.write(to: url)

        XCTAssertThrowsError(try C7ColorCube.Resource.readCompactResourceStrict(from: url)) { error in
            guard case .some(.cubeCompactResourceFailed(let reason)) = error as? HarbethError else {
                return XCTFail("Expected HarbethError.cubeCompactResourceFailed, got \(error)")
            }
            XCTAssertEqual(reason, "checksumMismatch")
        }
        XCTAssertNil(C7ColorCube.Resource.readCompactResource(from: url))
    }

    func testCompactLookupRejectsInvalidDomainBeforeRendering() throws {
        let source = try C7ColorCube.Resource.parse(contents: identityCube)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("identity.hlut")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var encoded = try compactLookupData(from: source)
        var invalidMinimum = source.domainMaximum.x.bitPattern.littleEndian
        withUnsafeBytes(of: &invalidMinimum) {
            encoded.replaceSubrange(8..<12, with: $0)
        }
        try encoded.write(to: url)

        XCTAssertThrowsError(try C7ColorCube.Resource.readCompactResourceStrict(from: url)) { error in
            guard case .some(.cubeCompactResourceFailed(let reason)) = error as? HarbethError else {
                return XCTFail("Expected HarbethError.cubeCompactResourceFailed, got \(error)")
            }
            XCTAssertEqual(reason, "invalidHeader")
        }
    }

    func testInvalidCompactResourceDoesNotFallbackToLegacyCube() throws {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        try "<?xml version=\"1.0\" encoding=\"UTF-8\"?><plist version=\"1.0\"><dict><key>CFBundleIdentifier</key><string>tests.compact.lookup</string></dict></plist>"
            .write(to: bundleURL.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        try Data([0x48, 0x4C, 0x55, 0x54]).write(to: bundleURL.appendingPathComponent("identity.hlut"))
        try identityCube.write(to: bundleURL.appendingPathComponent("identity.cube"), atomically: true, encoding: .utf8)
        let bundle = try XCTUnwrap(Bundle(path: bundleURL.path))

        let cube = C7ColorCube(cubeName: "identity", bundle: bundle)

        XCTAssertNil(cube.resourceIdentity)
        XCTAssertTrue(cube.otherInputTextures.isEmpty)
        guard case .some(.cubeCompactResourceFailed(let reason)) = cube.resourceLoadError else {
            return XCTFail("Expected HarbethError.cubeCompactResourceFailed, got \(String(describing: cube.resourceLoadError))")
        }
        XCTAssertEqual(reason, "invalidHeader")
    }

    func testLegacyCubeResourceRemainsReadable() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("cube")
        defer { try? FileManager.default.removeItem(at: url) }
        try identityCube.write(to: url, atomically: true, encoding: .utf8)

        let decoded = try XCTUnwrap(C7ColorCube.Resource.readCubeResource(from: url))
        let source = try C7ColorCube.Resource.parse(contents: identityCube)

        XCTAssertEqual(decoded.dimension, source.dimension)
        XCTAssertEqual(decoded.domainMinimum, source.domainMinimum)
        XCTAssertEqual(decoded.domainMaximum, source.domainMaximum)
        XCTAssertEqual(decoded.data, source.data)
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

    private func compactLookupData(from resource: C7ColorCube.Resource) throws -> Data {
        var compressed = Data(count: resource.data.count + 65_536)
        let capacity = compressed.count
        let written = compressed.withUnsafeMutableBytes { destination in
            resource.data.withUnsafeBytes { source in
                compression_encode_buffer(
                    destination.bindMemory(to: UInt8.self).baseAddress!,
                    capacity,
                    source.bindMemory(to: UInt8.self).baseAddress!,
                    resource.data.count,
                    nil,
                    COMPRESSION_LZFSE
                )
            }
        }
        guard written > 0 else { throw CocoaError(.coderInvalidValue) }
        compressed.removeSubrange(written..<compressed.count)

        var encoded = Data([0x48, 0x4C, 0x55, 0x54, 2, 1])
        append(UInt16(resource.dimension), to: &encoded)
        append(resource.domainMinimum.x, to: &encoded)
        append(resource.domainMinimum.y, to: &encoded)
        append(resource.domainMinimum.z, to: &encoded)
        append(resource.domainMaximum.x, to: &encoded)
        append(resource.domainMaximum.y, to: &encoded)
        append(resource.domainMaximum.z, to: &encoded)
        append(UInt32(resource.data.count), to: &encoded)
        append(UInt32(compressed.count), to: &encoded)
        encoded.append(contentsOf: SHA256.hash(data: resource.data))
        encoded.append(compressed)
        return encoded
    }

    private func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }

    private func append(_ value: Float, to data: inout Data) {
        append(value.bitPattern, to: &data)
    }
}

private struct CubeReplacementTestProvider: ColorCubeReplacementProvider {
    var providerIdentifier: String { "tests.cube-replacement.v1" }
    func replacement(resourceName: String, resourceOwner: String) -> ColorCubeReplacement? {
        guard resourceOwner == "tests.cube-replacement", resourceName == "invert-v1" else { return nil }
        return ColorCubeReplacement(identifier: "invert", version: 1, filters: [
            C7ColorMatrix4x5(matrix: Matrix4x5(values: [
                -1, 0, 0, 0, 1,
                0, -1, 0, 0, 1,
                0, 0, -1, 0, 1,
                0, 0, 0, 1, 0
            ]))
        ])
    }
}

extension ColorCubeTests {
    func testNamedReplacementPreservesIdentityIntensityAndAlphaWithoutLUT() throws {
        HarbethContext.shared.registerColorCubeReplacementProvider(CubeReplacementTestProvider())
        let input = try makeTexture(pixel: [32, 64, 96, 128])
        let cube = C7ColorCube(cubeName: "invert-v1", forResource: "tests.cube-replacement", intensity: 0.5)
        XCTAssertTrue(cube.usesAtomReplacement)
        XCTAssertEqual(cube.resourceName, "invert-v1")
        XCTAssertEqual(cube.resourceBundleName, "tests.cube-replacement")
        XCTAssertTrue(cube.otherInputTextures.isEmpty)
        XCTAssertNil(cube.resourceLoadError)
        let output = try HarbethIO(element: input, filter: cube).output()
        let bytes = try XCTUnwrap(output.c7.bytes())
        for channel in 0..<3 { XCTAssertLessThanOrEqual(abs(Int(bytes[channel]) - 128), 1) }
        XCTAssertEqual(bytes[3], 128)
        let zero = try HarbethIO(element: input, filter: cube.updateIntensity(0)).output()
        XCTAssertEqual(try zero.c7.bytes(), try input.c7.bytes())
        XCTAssertNotEqual(cube.recipeDescriptor.fingerprint, cube.updateIntensity(1).recipeDescriptor.fingerprint)
    }

    func testReplacementPreservesExtendedDomainPolicyAcrossBothSamplers() throws {
        HarbethContext.shared.registerColorCubeReplacementProvider(CubeReplacementTestProvider())
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: 1, height: 1, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead, .shaderWrite]
        let input = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let original: [Float16] = [-0.25, 1.25, 0.5, 0.5]
        original.withUnsafeBytes { input.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0,
            withBytes: $0.baseAddress!, bytesPerRow: 8) }
        for sampler in [C7ColorCube.Interpolation.trilinear, .tetrahedral] {
            let cube = C7ColorCube(cubeName: "invert-v1", forResource: "tests.cube-replacement", interpolation: sampler)
            let output = try HarbethIO(element: input, filter: cube.updateDomainPolicy(.preserveOutsideDomain)).output()
            var actual = [Float16](repeating: 0, count: 4)
            actual.withUnsafeMutableBytes { output.getBytes($0.baseAddress!, bytesPerRow: 8,
                from: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0) }
            XCTAssertEqual(actual, original)
            let clamped = try HarbethIO(element: input, filter: cube).output()
            actual.withUnsafeMutableBytes { clamped.getBytes($0.baseAddress!, bytesPerRow: 8,
                from: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0) }
            XCTAssertEqual(actual, [1, 0, 0.5, 0.5])
        }
    }

    func testOriginalLookupAndReplacementAgreeAcrossImageNodeAndIO() throws {
        HarbethContext.shared.registerColorCubeReplacementProvider(CubeReplacementTestProvider())
        let resource = try C7ColorCube.Resource.parse(contents: unitIdentityCube)
        let original = C7ColorCube(cubeResource: resource)
        XCTAssertEqual(original.kernelDescriptor().resources.inputTextureCount, 2)
        let input = try makeTexture(pixel: [32, 64, 96, 128])
        let atom = C7ColorCube(cubeName: "invert-v1", forResource: "tests.cube-replacement", intensity: 0.5)
        for cube in [original, atom] {
            let direct = try HarbethIO(element: input, filter: cube).output()
            let node = try ImageNode.texture(input).applying(cube).makeTexture()
            XCTAssertEqual(try direct.c7.bytes(), try node.c7.bytes())
        }
    }

    func testFusedCurveMatrixCurveMatchesHalfFloatPipeline() throws {
        let first = C7Curves(redPoints: [.init(x: 0, y: 0.02), .init(x: 0.5, y: 0.48), .init(x: 1, y: 0.98)],
            interpolation: .linear, compositionOrder: .channelsThenRGB)
        let matrix = C7ColorMatrix4x5(matrix: Matrix4x5(values: [
            0.95, 0.04, 0.01, 0, 0.01,
            0.02, 0.97, 0.01, 0, 0,
            0.01, 0.04, 0.95, 0, -0.005,
            0, 0, 0, 1, 0
        ]))
        let last = C7Curves(interpolation: .linear, compositionOrder: .channelsThenRGB)
        let filters: [C7FilterProtocol] = [first, matrix, last]
        let input = try makeTexture(pixel: [32, 64, 96, 128])
        for amount: Float in [0, 0.3, 1] {
            var fused = try XCTUnwrap(ColorCubeFusedAtoms(filters: filters))
            fused.intensity = amount
            let normal = CubeUnfusedTestPipeline(filters: filters, amount: amount)
            let expected = try XCTUnwrap(try HarbethIO(element: input, filter: normal).output().c7.bytes())
            let actual = try XCTUnwrap(try HarbethIO(element: input, filter: fused).output().c7.bytes())
            XCTAssertEqual(actual[3], expected[3])
            for i in 0..<3 { XCTAssertLessThanOrEqual(abs(Int(actual[i]) - Int(expected[i])), 1) }
        }
    }

    func testReplacementRegistrationAndUnknownNameKeepOriginalResourcePath() {
        let context = HarbethContext.shared
        context.registerColorCubeReplacementProvider(CubeReplacementTestProvider())
        XCTAssertFalse(context.registerColorCubeReplacementProvider(CubeReplacementTestProvider()))
        XCTAssertFalse(C7ColorCube(cubeName: "unknown", forResource: "tests.cube-replacement").usesAtomReplacement)
        XCTAssertFalse(C7ColorCube(cubeResource: nil).usesAtomReplacement)
        XCTAssertNil(ColorCubeReplacement(identifier: "invalid", version: 1, filters: [C7GaussianBlur()]))
    }
}

private struct CubeUnfusedTestPipeline: C7FilterPipelineProtocol {
    let filters: [C7FilterProtocol]
    let amount: Float
    var pipelineFilters: [C7FilterProtocol] { [ColorCubeReplacementPrepare()] + filters }
    func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? {
        ColorCubeReplacementMix(intensity: amount, domainPolicy: .clampToDomain, inputs: otherInputTextures ?? [])
    }
}
