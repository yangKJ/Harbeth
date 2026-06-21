//
//  HarbethKernelDescriptor.swift
//  Harbeth
//
//  Created by Codex on 2026/6/21.
//

import Foundation
import Metal

public enum HarbethKernelResourceUsage: String, Sendable, Codable, Equatable, Hashable {
    case singleInput
    case dualInput
    case multiInput
    case generatesTexture
    case externalEncoder
}

public enum HarbethKernelAlphaBehavior: String, Sendable, Codable, Equatable, Hashable {
    case preserveInput
    case outputsOpaque
    case outputsPremultiplied
    case outputsNonPremultiplied
    case modifiesAlpha
}

public enum HarbethKernelFunctionKind: String, Sendable, Codable, Equatable, Hashable {
    case compute
    case render
    case blit
    case mps
    case advancedMetal
}

public struct HarbethKernelFunctionIdentity: Sendable, Codable, Equatable, Hashable {
    public let kind: HarbethKernelFunctionKind
    public let primaryName: String
    public let secondaryName: String?

    public init(kind: HarbethKernelFunctionKind,
                primaryName: String,
                secondaryName: String? = nil) {
        self.kind = kind
        self.primaryName = primaryName
        self.secondaryName = secondaryName
    }

    public var fingerprint: String {
        [
            "kind=\(kind.rawValue)",
            "primary=\(primaryName)",
            "secondary=\(secondaryName ?? "none")"
        ].joined(separator: "|")
    }
}

public enum HarbethKernelParameterValue: Sendable, Codable, Equatable, Hashable {
    case float(Float)
    case int(Int)
    case bool(Bool)
    case string(String)
    case floatArray([Float])

    public var fingerprint: String {
        switch self {
        case .float(let value):
            return "float:\(String(format: "%.4f", value))"
        case .int(let value):
            return "int:\(value)"
        case .bool(let value):
            return "bool:\(value ? 1 : 0)"
        case .string(let value):
            return "string:\(value)"
        case .floatArray(let values):
            return "floats:\(values.map { String(format: "%.4f", $0) }.joined(separator: ","))"
        }
    }
}

public struct HarbethKernelOutputDescriptor: Sendable, Codable, Equatable, Hashable {
    public let outputSize: C7Size?
    public let pixelFormat: String?

    public init(outputSize: C7Size? = nil, pixelFormat: MTLPixelFormat? = nil) {
        self.outputSize = outputSize
        self.pixelFormat = pixelFormat.map { String(describing: $0) }
    }

    public var fingerprint: String {
        [
            "size=\(outputSize.map { "\($0.width)x\($0.height)" } ?? "source")",
            "pixelFormat=\(pixelFormat ?? "preserve")"
        ].joined(separator: "|")
    }
}

public struct HarbethKernelDescriptor: Sendable, Codable, Equatable, Hashable {
    public let filterName: String
    public let functionIdentity: HarbethKernelFunctionIdentity
    public let parameters: [String: HarbethKernelParameterValue]
    public let output: HarbethKernelOutputDescriptor
    public let resourceUsage: HarbethKernelResourceUsage
    public let alphaBehavior: HarbethKernelAlphaBehavior

    public init(filterName: String,
                functionIdentity: HarbethKernelFunctionIdentity,
                parameters: [String: HarbethKernelParameterValue] = [:],
                output: HarbethKernelOutputDescriptor = HarbethKernelOutputDescriptor(),
                resourceUsage: HarbethKernelResourceUsage = .singleInput,
                alphaBehavior: HarbethKernelAlphaBehavior = .preserveInput) {
        self.filterName = filterName
        self.functionIdentity = functionIdentity
        self.parameters = parameters
        self.output = output
        self.resourceUsage = resourceUsage
        self.alphaBehavior = alphaBehavior
    }

    public var fingerprint: String {
        let parameterFingerprint = parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.fingerprint)" }
            .joined(separator: "|")
        return [
            "filter=\(filterName)",
            functionIdentity.fingerprint,
            "params=\(parameterFingerprint)",
            output.fingerprint,
            "resources=\(resourceUsage.rawValue)",
            "alpha=\(alphaBehavior.rawValue)"
        ].joined(separator: "|")
    }
}

public extension C7FilterProtocol {
    func kernelDescriptor(inputSize: C7Size? = nil) -> HarbethKernelDescriptor {
        let outputSize = inputSize.map { resize(input: $0) }
        let functionIdentity: HarbethKernelFunctionIdentity
        let resourceUsage: HarbethKernelResourceUsage
        switch modifier {
        case .compute(let kernel):
            functionIdentity = HarbethKernelFunctionIdentity(kind: .compute, primaryName: kernel)
            resourceUsage = otherInputTextures.isEmpty ? .singleInput : (otherInputTextures.count == 1 ? .dualInput : .multiInput)
        case .render(let vertex, let fragment):
            functionIdentity = HarbethKernelFunctionIdentity(kind: .render, primaryName: vertex, secondaryName: fragment)
            resourceUsage = otherInputTextures.isEmpty ? .singleInput : .multiInput
        case .blit:
            functionIdentity = HarbethKernelFunctionIdentity(kind: .blit, primaryName: "blit")
            resourceUsage = .generatesTexture
        case .mps(let kernel):
            functionIdentity = HarbethKernelFunctionIdentity(kind: .mps, primaryName: kernel.label ?? String(describing: Swift.type(of: kernel)))
            resourceUsage = .externalEncoder
        case .advancedMetal(_, let function):
            functionIdentity = HarbethKernelFunctionIdentity(kind: .advancedMetal, primaryName: function)
            resourceUsage = .externalEncoder
        }

        var parameters: [String: HarbethKernelParameterValue] = [
            "factors": .floatArray(factors),
            "hasCount": .bool(hasCount),
            "otherInputTextures": .int(otherInputTextures.count),
            "memoryAccessPattern": .string(String(describing: memoryAccessPattern))
        ]
        for (key, value) in parameterDescription {
            if let float = value as? Float {
                parameters[key] = .float(float)
            } else if let int = value as? Int {
                parameters[key] = .int(int)
            } else if let bool = value as? Bool {
                parameters[key] = .bool(bool)
            } else if let string = value as? String {
                parameters[key] = .string(string)
            }
        }

        return HarbethKernelDescriptor(
            filterName: String(describing: Swift.type(of: self)),
            functionIdentity: functionIdentity,
            parameters: parameters,
            output: HarbethKernelOutputDescriptor(outputSize: outputSize),
            resourceUsage: resourceUsage,
            alphaBehavior: self is C7Opacity ? .modifiesAlpha : .preserveInput
        )
    }
}
