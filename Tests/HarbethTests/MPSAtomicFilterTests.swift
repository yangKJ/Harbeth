import XCTest
import Metal
import MetalPerformanceShaders
@testable import Harbeth

final class MPSAtomicFilterTests: XCTestCase {

    func testExactGaussianSigmaAndInvalidValues() throws {
        for value: Float in [0, -1, .nan, .infinity, 101] {
            XCTAssertThrowsError(try MPSGaussianBlur(sigma: value)) {
                guard case HarbethError.filterParameterInvalid = $0 else {
                    return XCTFail("非法sigma必须返回参数错误。")
                }
            }
        }
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "当前环境没有Metal设备")
        let filter = try MPSGaussianBlur(sigma: 2.1, edgeMode: .zero)
        XCTAssertEqual(filter.sigma, 2.1)
        XCTAssertEqual(filter.factors, [2.1, Float(MPSImageEdgeMode.zero.rawValue)])
        XCTAssertEqual(filter.edgeMode, .zero)
        XCTAssertEqual(filter.samplingFootprint, .neighborhood(radius: 9))
        XCTAssertTrue(filter.kernelPixelContract.canAutoTile)
    }

    func testExactGaussianFractionalSigmaHasDifferentImpulseFromRoundedPrimitive() throws {
        var pixels = [UInt8](repeating: 0, count: 41 * 41 * 4)
        for index in stride(from: 3, to: pixels.count, by: 4) { pixels[index] = 255 }
        let center = (20 * 41 + 20) * 4
        pixels[center] = 255
        let source = try makeTexture(width: 41, height: 41, pixels: pixels)
        let exact: MTLTexture = try HarbethIO(element: source, filter: MPSGaussianBlur(sigma: 2.1)).output()
        let rounded: MTLTexture = try HarbethIO(element: source, filter: MPSGaussianBlur(radius: 2.1)).output()
        let a = try XCTUnwrap(exact.c7.bytes()), b = try XCTUnwrap(rounded.c7.bytes())
        XCTAssertGreaterThan(a[center], b[center])
        XCTAssertEqual(a[center + 3], 255)
        XCTAssertEqual(source.c7.bytes(), Data(pixels))
    }

    func testGaussianConfigurationSurvivesRadiusChangesAndCopies() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "当前环境没有Metal设备")

        var exact = try MPSGaussianBlur(sigma: 2.1, edgeMode: .zero)
        let original = exact
        exact.radius = 2.25
        XCTAssertEqual(exact.sigma, 2.25)
        XCTAssertEqual(exact.samplingFootprint, .neighborhood(radius: 9))
        XCTAssertEqual(exact.factors, [2.25, Float(MPSImageEdgeMode.zero.rawValue)])
        XCTAssertEqual(original.sigma, 2.1)
        guard case .mps(let kernel) = exact.modifier else { return XCTFail("高斯必须经MPS执行。") }
        XCTAssertEqual(try XCTUnwrap(kernel as? MPSImageGaussianBlur).edgeMode, .zero)

        var rounded = MPSGaussianBlur(radius: 2.1, edgeMode: .zero)
        XCTAssertEqual(rounded.radius, 2.1)
        XCTAssertEqual(rounded.sigma, 3)
        rounded.radius = 3.25
        XCTAssertEqual(rounded.sigma, 4)
        XCTAssertEqual(rounded.samplingFootprint, .neighborhood(radius: 16))
        guard case .mps(let roundedKernel) = rounded.modifier else { return XCTFail("高斯必须经MPS执行。") }
        XCTAssertEqual(try XCTUnwrap(roundedKernel as? MPSImageGaussianBlur).edgeMode, .zero)
    }

    func testGaussianBlurExposesConservativeTileHalo() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")

        let filter = MPSGaussianBlur(radius: 2.25)

        XCTAssertEqual(filter.samplingFootprint, .neighborhood(radius: 12))
        XCTAssertTrue(filter.kernelPixelContract.canAutoTile)
        XCTAssertEqual(MPSGaussianBlur.conservativeHaloRadius(for: 0), 0)
    }

    func testConvolutionRejectsInvalidCPUParametersBeforeGPUConstruction() {
        XCTAssertThrowsError(try MPSConvolution(kernelWidth: 2, kernelHeight: 3, weights: Array(repeating: 0, count: 6)))
        XCTAssertThrowsError(try MPSConvolution(kernelWidth: 3, kernelHeight: 0, weights: []))
        XCTAssertThrowsError(try MPSConvolution(kernelWidth: 3, kernelHeight: 3, weights: Array(repeating: 0, count: 8)))
        XCTAssertThrowsError(try MPSConvolution(kernelWidth: 3, kernelHeight: 3, weights: Array(repeating: .nan, count: 9)))
        XCTAssertThrowsError(try MPSConvolution(kernelWidth: 3, kernelHeight: 3, weights: Array(repeating: 0, count: 9), bias: .infinity))
    }

    func testConvolutionPreservesDeclaredParameters() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")

        let filter = try MPSConvolution(
            kernelWidth: 3,
            kernelHeight: 3,
            weights: [0, 0, 0, 0, 1, 0, 0, 0, 0],
            bias: 0.25,
            edgeMode: .zero
        )

        XCTAssertEqual(filter.kernelWidth, 3)
        XCTAssertEqual(filter.kernelHeight, 3)
        XCTAssertEqual(filter.weights.count, 9)
        XCTAssertEqual(filter.bias, 0.25)
        XCTAssertEqual(filter.edgeMode, .zero)
        XCTAssertEqual(filter.samplingFootprint, .neighborhood(radius: 1))
        XCTAssertEqual(filter.factors.suffix(9), filter.weights[...])
        XCTAssertThrowsError(try MPSConvolution(
            kernelWidth: MPSConvolution.maximumKernelDimension + 2,
            kernelHeight: 1,
            weights: Array(repeating: 0, count: MPSConvolution.maximumKernelDimension + 2)
        ))
    }

    func testLanczosResizeHasExactSizeContract() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")

        let filter = try MPSLanczosResize(width: 5, height: 3)
        XCTAssertEqual(filter.resize(input: C7Size(width: 2, height: 9)), C7Size(width: 5, height: 3))
        XCTAssertEqual(filter.samplingFootprint, .global)
        XCTAssertThrowsError(try MPSLanczosResize(width: 0, height: 3))
        XCTAssertThrowsError(try MPSLanczosResize(width: 5, height: MPSLanczosResize.maximumDimension + 1))
    }

    func testMorphologyNormalizesKernelToSupportedOddRange() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")

        let minimum = MPSMorphology(operation: .erode, kernelSize: -1)
        let rounded = MPSMorphology(operation: .dilate, kernelSize: 2)
        let maximum = MPSMorphology(operation: .dilate, kernelSize: 10)

        XCTAssertEqual(minimum.kernelSize, 1)
        XCTAssertEqual(rounded.kernelSize, 3)
        XCTAssertEqual(maximum.kernelSize, 9)
        XCTAssertEqual(rounded.samplingFootprint, .neighborhood(radius: 1))
        XCTAssertEqual(rounded.factors, [1, 3])
    }

    func testMPSAtomsRenderExpectedOutputSizes() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable in this environment.")

        let source = try makeTexture(
            width: 3,
            height: 3,
            pixels: [
                0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255,
                0, 0, 0, 255, 255, 255, 255, 255, 0, 0, 0, 255,
                0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255
            ]
        )
        let identity = try MPSConvolution(
            kernelWidth: 3,
            kernelHeight: 3,
            weights: [0, 0, 0, 0, 1, 0, 0, 0, 0]
        )
        let convolutionOutput: MTLTexture = try HarbethIO(element: source, filter: identity).output()
        let morphologyOutput: MTLTexture = try HarbethIO(
            element: source,
            filter: MPSMorphology(operation: .dilate, kernelSize: 3)
        ).output()
        let resizedOutput: MTLTexture = try HarbethIO(
            element: source,
            filter: MPSLanczosResize(width: 5, height: 2)
        ).output()

        XCTAssertEqual(convolutionOutput.width, 3)
        XCTAssertEqual(convolutionOutput.height, 3)
        XCTAssertEqual(convolutionOutput.c7.bytes(), source.c7.bytes())
        XCTAssertEqual(morphologyOutput.width, 3)
        XCTAssertEqual(morphologyOutput.height, 3)
        let morphologyBytes = try XCTUnwrap(morphologyOutput.c7.bytes())
        XCTAssertEqual(morphologyBytes[0], 255)
        XCTAssertEqual(resizedOutput.width, 5)
        XCTAssertEqual(resizedOutput.height, 2)
    }

    private func makeTexture(width: Int, height: Int, pixels: [UInt8]) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable in this environment.")
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw HarbethError.textureLoader
        }
        TextureLoader.replaceTexture(
            texture,
            region: MTLRegionMake2D(0, 0, width, height),
            bytes: pixels,
            packedBytesPerRow: width * 4
        )
        return texture
    }
}
