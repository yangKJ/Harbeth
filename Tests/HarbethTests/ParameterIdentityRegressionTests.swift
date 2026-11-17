// 由 Condy 创建于 2026/11/17。缓存身份必须区分实际执行的参数。
import XCTest
import Metal
@testable import Harbeth

final class ParameterIdentityRegressionTests: XCTestCase {
    func testEveryFloatingBindingSeparatesAdjacentValuesAndSpecialBits() {
        let pairs: [(Float, Float)] = [(0.1, Float(0.1).nextUp), (0, Float(bitPattern: 0x80000000)),
            (Float(bitPattern: 0x7fc00001), Float(bitPattern: 0x7fc00002)), (.infinity, -.infinity)]
        for (a, b) in pairs {
            func bindings(_ v: Float) -> [KernelParameterBindingValue] {
                [.float(v), .float2(SIMD2(v, 1)), .float3(SIMD3(1, v, 2)), .float4(SIMD4(1, 2, v, 3)),
                 .vector4(Vector4(values: [v, 1, 2, 3])), .floatArray([v]),
                 .matrix3x3(Matrix3x3(values: [v, 0, 0, 0, 1, 0, 0, 0, 1])),
                 .matrix4x4(Matrix4x4(values: [v] + Array(repeating: 0, count: 15)))]
            }
            for (x, y) in zip(bindings(a), bindings(b)) { XCTAssertNotEqual(x.fingerprint, y.fingerprint) }
            XCTAssertNotEqual(KernelParameterValue.float(a).fingerprint, KernelParameterValue.float(b).fingerprint)
            XCTAssertNotEqual(KernelFunctionConstantValue.float(a).fingerprint, KernelFunctionConstantValue.float(b).fingerprint)
            XCTAssertNotEqual(ScalarIdentityFilter(value: a).recipeDescriptor.fingerprint, ScalarIdentityFilter(value: b).recipeDescriptor.fingerprint)
            XCTAssertNotEqual(ScalarIdentityFilter(value: a).kernelParameterFingerprint, ScalarIdentityFilter(value: b).kernelParameterFingerprint)
        }
        XCTAssertNotEqual(KernelParameterValue.double(0.1).fingerprint, KernelParameterValue.double(Double(0.1).nextUp).fingerprint)
        XCTAssertNotEqual(KernelParameterBindingValue.bytes([1, 2], dataType: .float).fingerprint,
                          KernelParameterBindingValue.bytes([2, 1], dataType: .float).fingerprint)
        XCTAssertNotEqual(KernelParameterBindingValue.bytes([1, 2], dataType: .float).fingerprint,
                          KernelParameterBindingValue.bytes([1, 2], dataType: .int).fingerprint)
    }

    func testPersistentCacheTracksScalarAndTypedVectorPixels() throws {
        let source = try NeighborhoodTestImage.make(width: 1, height: 1, values: [0, 0, 0, 1], format: .rgba32Float)
        for value: Float in [1e-7, 4e-7, 1e-7] {
            let f = C7Brightness(brightness: value)
            let actual = try cached(source, f)
            XCTAssertEqual(actual[0], value)
            XCTAssertEqual(actual, try transient(source, f))
        }
        for value: Float in [0.10001, 0.10004, 0.10001] {
            var f = C7FalseColor(); f.fristColor = C7Color(red: CGFloat(value), green: 0.2, blue: 0.3, alpha: 1)
            XCTAssertEqual(try cached(source, f), try transient(source, f))
        }
    }

    func testPersistentCacheTracksSameLengthRawBytesAndLargePayloads() throws {
        let device = HarbethContext.shared.device
        let library = try device.makeLibrary(source: """
        #include <metal_stdlib>
        using namespace metal;
        kernel void parameterIdentityBytes(texture2d<float, access::write> out [[texture(0)]],
            constant float4 &color [[buffer(0)]], uint2 p [[thread_position_in_grid]]) {
            if (p.x < out.get_width() && p.y < out.get_height()) out.write(color, p);
        }
        """, options: nil)
        XCTAssertTrue(Device.registerExternalLibraryProvider(IdentityBytesLibrary(library: library)))
        let source = try NeighborhoodTestImage.make(width: 1, height: 1, values: [0, 0, 0, 1], format: .rgba32Float)
        for count in [4, 2048] {
            for color: [Float] in [[0.25, 0.5, 0.75, 1], [0.75, 0.25, 0.5, 1]] {
                let values = color + Array(repeating: Float.zero, count: count - 4)
                let filter = BytesIdentityFilter(bytes: values.withUnsafeBytes { Array($0) })
                XCTAssertEqual(try cached(source, filter), color)
                XCTAssertEqual(try cached(source, filter), try transient(source, filter))
                let payload = filter.kernelParameterBindings[0].value
                XCTAssertEqual(try JSONDecoder().decode(KernelParameterBindingValue.self, from: JSONEncoder().encode(payload)), payload)
            }
        }
    }

    private func cached(_ source: MTLTexture, _ filter: any C7FilterProtocol) throws -> [Float] {
        try NeighborhoodTestImage.read(ImageNode.texture(source).applying(filter).withCachePolicy(.persistent).makeTexture())
    }
    private func transient(_ source: MTLTexture, _ filter: any C7FilterProtocol) throws -> [Float] {
        try NeighborhoodTestImage.read(ImageNode.texture(source).applying(filter).withCachePolicy(.transient).makeTexture())
    }
}

private struct ScalarIdentityFilter: C7FilterProtocol {
    let value: Float
    var modifier: ModifierEnum { .compute(kernel: "C7Brightness") }
    var factors: [Float] { [value] }
}
private struct BytesIdentityFilter: C7FilterProtocol {
    let bytes: [UInt8]
    var modifier: ModifierEnum { .compute(kernel: "parameterIdentityBytes") }
    var kernelParameterBindings: [KernelParameterBinding] {
        [.init(name: "color", index: 0, stage: .compute, value: .bytes(bytes, dataType: .float4))]
    }
}
private struct IdentityBytesLibrary: ExternalMTLLibraryProvider {
    let library: MTLLibrary
    let providerIdentifier = "parameter.identity." + UUID().uuidString
    func provideLibrary(for device: MTLDevice) -> MTLLibrary? { library.device.registryID == device.registryID ? library : nil }
}
