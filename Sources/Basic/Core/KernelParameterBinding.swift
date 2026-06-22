//
//  KernelParameterBinding.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import Metal
import simd

public enum KernelBindingStage: String, Sendable, Codable, Equatable, Hashable {
    case compute
    case renderVertex
    case renderFragment
}

public enum KernelParameterBindingValue: Sendable, Codable, Equatable, Hashable {
    case float(Float)
    case int(Int)
    case bool(Bool)
    case float2(SIMD2<Float>)
    case float3(SIMD3<Float>)
    case float4(SIMD4<Float>)
    case matrix3x3(Matrix3x3)
    case matrix4x4(Matrix4x4)
    case bytes([UInt8], dataType: KernelArgumentDataType)

    public var fingerprint: String {
        switch self {
        case .float(let value):
            return "float:\(String(format: "%.4f", value))"
        case .int(let value):
            return "int:\(value)"
        case .bool(let value):
            return "bool:\(value ? 1 : 0)"
        case .float2(let value):
            return "float2:\(String(format: "%.4f", value.x)),\(String(format: "%.4f", value.y))"
        case .float3(let value):
            return "float3:\(String(format: "%.4f", value.x)),\(String(format: "%.4f", value.y)),\(String(format: "%.4f", value.z))"
        case .float4(let value):
            return "float4:\(String(format: "%.4f", value.x)),\(String(format: "%.4f", value.y)),\(String(format: "%.4f", value.z)),\(String(format: "%.4f", value.w))"
        case .matrix3x3(let value):
            return "matrix3x3:\(value.values.map { String(format: "%.4f", $0) }.joined(separator: ","))"
        case .matrix4x4(let value):
            return "matrix4x4:\(value.values.map { String(format: "%.4f", $0) }.joined(separator: ","))"
        case .bytes(let bytes, let dataType):
            return "bytes:\(dataType.rawValue):\(bytes.count)"
        }
    }

    public var argumentDataType: KernelArgumentDataType {
        switch self {
        case .float:
            return .float
        case .int:
            return .int
        case .bool:
            return .bool
        case .float2:
            return .float2
        case .float3:
            return .float3
        case .float4:
            return .float4
        case .matrix3x3:
            return .matrix3x3
        case .matrix4x4:
            return .matrix4x4
        case .bytes(_, let dataType):
            return dataType
        }
    }

    var byteCount: Int {
        switch self {
        case .float:
            return MemoryLayout<Float>.size
        case .int:
            return MemoryLayout<Int32>.size
        case .bool:
            return MemoryLayout<Bool>.size
        case .float2:
            return MemoryLayout<SIMD2<Float>>.stride
        case .float3:
            return MemoryLayout<SIMD3<Float>>.stride
        case .float4:
            return MemoryLayout<SIMD4<Float>>.stride
        case .matrix3x3:
            return Matrix3x3.size
        case .matrix4x4:
            return Matrix4x4.size
        case .bytes(let bytes, _):
            return bytes.count
        }
    }
}

public struct KernelParameterBinding: Sendable, Codable, Equatable, Hashable {
    public let name: String
    public let index: Int
    public let stage: KernelBindingStage
    public let value: KernelParameterBindingValue
    public let required: Bool

    public init(name: String, index: Int, stage: KernelBindingStage, value: KernelParameterBindingValue, required: Bool = true) {
        self.name = name
        self.index = index
        self.stage = stage
        self.value = value
        self.required = required
    }

    public var fingerprint: String {
        [
            "binding=\(name)",
            "index=\(index)",
            "stage=\(stage.rawValue)",
            "type=\(value.argumentDataType.rawValue)",
            "required=\(required ? 1 : 0)",
            "value=\(value.fingerprint)"
        ].joined(separator: "|")
    }
}

enum KernelBindingEncoder {
    static func encode(_ bindings: [KernelParameterBinding], stage: KernelBindingStage, on encoder: MTLCommandEncoder) {
        for binding in bindings where binding.stage == stage {
            encode(binding, on: encoder)
        }
    }

    private static func encode(_ binding: KernelParameterBinding, on encoder: MTLCommandEncoder) {
        switch binding.stage {
        case .compute:
            guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
            encode(binding.value, index: binding.index) { bytes, length, index in
                computeEncoder.setBytes(bytes, length: length, index: index)
            }
        case .renderVertex:
            guard let renderEncoder = encoder as? MTLRenderCommandEncoder else { return }
            encode(binding.value, index: binding.index) { bytes, length, index in
                renderEncoder.setVertexBytes(bytes, length: length, index: index)
            }
        case .renderFragment:
            guard let renderEncoder = encoder as? MTLRenderCommandEncoder else { return }
            encode(binding.value, index: binding.index) { bytes, length, index in
                renderEncoder.setFragmentBytes(bytes, length: length, index: index)
            }
        }
    }

    private static func encode(_ value: KernelParameterBindingValue, index: Int, applier: (UnsafeRawPointer, Int, Int) -> Void) {
        switch value {
        case .float(let rawValue):
            var value = rawValue
            withUnsafeBytes(of: &value) { applier($0.baseAddress!, $0.count, index) }
        case .int(let rawValue):
            var value = Int32(rawValue)
            withUnsafeBytes(of: &value) { applier($0.baseAddress!, $0.count, index) }
        case .bool(let rawValue):
            var value = rawValue
            withUnsafeBytes(of: &value) { applier($0.baseAddress!, $0.count, index) }
        case .float2(let rawValue):
            var value = rawValue
            withUnsafeBytes(of: &value) { applier($0.baseAddress!, $0.count, index) }
        case .float3(let rawValue):
            var value = rawValue
            withUnsafeBytes(of: &value) { applier($0.baseAddress!, $0.count, index) }
        case .float4(let rawValue):
            var value = rawValue
            withUnsafeBytes(of: &value) { applier($0.baseAddress!, $0.count, index) }
        case .matrix3x3(let rawValue):
            var value = rawValue.to_factor()
            withUnsafeBytes(of: &value) { applier($0.baseAddress!, $0.count, index) }
        case .matrix4x4(let rawValue):
            var value = rawValue.to_factor()
            withUnsafeBytes(of: &value) { applier($0.baseAddress!, $0.count, index) }
        case .bytes(let rawValue, _):
            rawValue.withUnsafeBytes { buffer in
                guard let baseAddress = buffer.baseAddress else { return }
                applier(baseAddress, buffer.count, index)
            }
        }
    }
}
