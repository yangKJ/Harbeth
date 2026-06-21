//
//  HarbethKernelDescriptor.swift
//  Harbeth
//
//  Created by Codex on 2026/6/21.
//

import Foundation
import CoreGraphics
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

public enum HarbethKernelLibrarySource: Sendable, Codable, Equatable, Hashable {
    case automatic
    case defaultLibrary
    case harbethFramework
    case externalProvider(String)
    case metallibURL(String)
    case sourceFallback(String)

    public var fingerprint: String {
        switch self {
        case .automatic:
            return "library=automatic"
        case .defaultLibrary:
            return "library=default"
        case .harbethFramework:
            return "library=harbethFramework"
        case .externalProvider(let identifier):
            return "library=externalProvider:\(identifier)"
        case .metallibURL(let url):
            return "library=metallibURL:\(url)"
        case .sourceFallback(let identifier):
            return "library=sourceFallback:\(identifier)"
        }
    }
}

public enum HarbethKernelFunctionConstantValue: Sendable, Codable, Equatable, Hashable {
    case bool(Bool)
    case int(Int)
    case float(Float)
    case string(String)

    public var fingerprint: String {
        switch self {
        case .bool(let value):
            return "bool:\(value ? 1 : 0)"
        case .int(let value):
            return "int:\(value)"
        case .float(let value):
            return "float:\(String(format: "%.4f", value))"
        case .string(let value):
            return "string:\(value)"
        }
    }
}

public struct HarbethKernelFunctionConstantDescriptor: Sendable, Codable, Equatable, Hashable {
    public let name: String
    public let index: Int?
    public let value: HarbethKernelFunctionConstantValue

    public init(name: String,
                index: Int? = nil,
                value: HarbethKernelFunctionConstantValue) {
        self.name = name
        self.index = index
        self.value = value
    }

    public var fingerprint: String {
        [
            "constant=\(name)",
            "index=\(index.map(String.init) ?? "named")",
            "value=\(value.fingerprint)"
        ].joined(separator: "|")
    }
}

public struct HarbethKernelFunctionIdentity: Sendable, Codable, Equatable, Hashable {
    public let kind: HarbethKernelFunctionKind
    public let primaryName: String
    public let secondaryName: String?
    public let librarySource: HarbethKernelLibrarySource
    public let functionConstants: [HarbethKernelFunctionConstantDescriptor]

    public init(kind: HarbethKernelFunctionKind,
                primaryName: String,
                secondaryName: String? = nil,
                librarySource: HarbethKernelLibrarySource = .automatic,
                functionConstants: [HarbethKernelFunctionConstantDescriptor] = []) {
        self.kind = kind
        self.primaryName = primaryName
        self.secondaryName = secondaryName
        self.librarySource = librarySource
        self.functionConstants = functionConstants
    }

    public var fingerprint: String {
        let constants = functionConstants
            .sorted { lhs, rhs in
                if lhs.name == rhs.name {
                    return (lhs.index ?? -1) < (rhs.index ?? -1)
                }
                return lhs.name < rhs.name
            }
            .map(\.fingerprint)
            .joined(separator: "||")
        return [
            "kind=\(kind.rawValue)",
            "primary=\(primaryName)",
            "secondary=\(secondaryName ?? "none")",
            librarySource.fingerprint,
            "constants=\(constants.isEmpty ? "none" : constants)"
        ].joined(separator: "|")
    }
}

public extension HarbethKernelFunctionIdentity {
    func makeMetalFunctionConstantValues() -> MTLFunctionConstantValues? {
        guard functionConstants.isEmpty == false else {
            return nil
        }
        let values = MTLFunctionConstantValues()
        for constant in functionConstants {
            guard constant.apply(to: values) else {
                return nil
            }
        }
        return values
    }
}

public enum HarbethKernelParameterValue: Sendable, Codable, Equatable, Hashable {
    case float(Float)
    case double(Double)
    case int(Int)
    case bool(Bool)
    case string(String)
    case floatArray([Float])
    case intArray([Int])
    case stringArray([String])

    public var fingerprint: String {
        switch self {
        case .float(let value):
            return "float:\(String(format: "%.4f", value))"
        case .double(let value):
            return "double:\(String(format: "%.4f", value))"
        case .int(let value):
            return "int:\(value)"
        case .bool(let value):
            return "bool:\(value ? 1 : 0)"
        case .string(let value):
            return "string:\(value)"
        case .floatArray(let values):
            return "floats:\(values.map { String(format: "%.4f", $0) }.joined(separator: ","))"
        case .intArray(let values):
            return "ints:\(values.map(String.init).joined(separator: ","))"
        case .stringArray(let values):
            return "strings:\(values.joined(separator: ","))"
        }
    }
}

private extension HarbethKernelFunctionConstantDescriptor {
    func apply(to values: MTLFunctionConstantValues) -> Bool {
        switch value {
        case .bool(let constant):
            var typedValue = constant
            if let index {
                values.setConstantValue(&typedValue, type: .bool, index: index)
            } else {
                values.setConstantValue(&typedValue, type: .bool, withName: name)
            }
            return true
        case .int(let constant):
            var typedValue = Int32(constant)
            if let index {
                values.setConstantValue(&typedValue, type: .int, index: index)
            } else {
                values.setConstantValue(&typedValue, type: .int, withName: name)
            }
            return true
        case .float(let constant):
            var typedValue = constant
            if let index {
                values.setConstantValue(&typedValue, type: .float, index: index)
            } else {
                values.setConstantValue(&typedValue, type: .float, withName: name)
            }
            return true
        case .string:
            return false
        }
    }
}

public enum HarbethKernelArgumentRole: String, Sendable, Codable, Equatable, Hashable {
    case parameter
    case functionConstant
    case inputTexture
    case outputTexture
    case resourceState
    case executionHint
}

public enum HarbethKernelArgumentDataType: String, Sendable, Codable, Equatable, Hashable {
    case float
    case double
    case int
    case bool
    case string
    case floatArray
    case intArray
    case stringArray
    case texture
    case unknown
}

public struct HarbethKernelArgumentDescriptor: Sendable, Codable, Equatable, Hashable {
    public let name: String
    public let index: Int
    public let role: HarbethKernelArgumentRole
    public let dataType: HarbethKernelArgumentDataType
    public let required: Bool
    public let valueFingerprint: String?

    public init(name: String,
                index: Int,
                role: HarbethKernelArgumentRole,
                dataType: HarbethKernelArgumentDataType,
                required: Bool = true,
                valueFingerprint: String? = nil) {
        self.name = name
        self.index = index
        self.role = role
        self.dataType = dataType
        self.required = required
        self.valueFingerprint = valueFingerprint
    }

    public var fingerprint: String {
        [
            "arg=\(index)",
            "name=\(name)",
            "role=\(role.rawValue)",
            "type=\(dataType.rawValue)",
            "required=\(required ? 1 : 0)",
            "value=\(valueFingerprint ?? "none")"
        ].joined(separator: "|")
    }
}

public struct HarbethKernelResourceDescriptor: Sendable, Codable, Equatable, Hashable {
    public let usage: HarbethKernelResourceUsage
    public let inputTextureCount: Int
    public let writesOutputTexture: Bool
    public let requiresDestinationTexture: Bool
    public let memoryAccessPattern: String
    public let hasPixelCountBuffer: Bool

    public init(usage: HarbethKernelResourceUsage,
                inputTextureCount: Int,
                writesOutputTexture: Bool = true,
                requiresDestinationTexture: Bool = true,
                memoryAccessPattern: String = "auto",
                hasPixelCountBuffer: Bool = false) {
        self.usage = usage
        self.inputTextureCount = inputTextureCount
        self.writesOutputTexture = writesOutputTexture
        self.requiresDestinationTexture = requiresDestinationTexture
        self.memoryAccessPattern = memoryAccessPattern
        self.hasPixelCountBuffer = hasPixelCountBuffer
    }

    public var fingerprint: String {
        [
            "usage=\(usage.rawValue)",
            "inputs=\(inputTextureCount)",
            "writes=\(writesOutputTexture ? 1 : 0)",
            "dest=\(requiresDestinationTexture ? 1 : 0)",
            "memory=\(memoryAccessPattern)",
            "count=\(hasPixelCountBuffer ? 1 : 0)"
        ].joined(separator: "|")
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

public struct HarbethKernelPassDescriptor: Sendable, Codable, Equatable, Hashable {
    public let index: Int
    public let functionIdentity: HarbethKernelFunctionIdentity
    public let output: HarbethKernelOutputDescriptor
    public let resources: HarbethKernelResourceDescriptor
    public let alphaBehavior: HarbethKernelAlphaBehavior

    public init(index: Int,
                functionIdentity: HarbethKernelFunctionIdentity,
                output: HarbethKernelOutputDescriptor = HarbethKernelOutputDescriptor(),
                resources: HarbethKernelResourceDescriptor,
                alphaBehavior: HarbethKernelAlphaBehavior = .preserveInput) {
        self.index = index
        self.functionIdentity = functionIdentity
        self.output = output
        self.resources = resources
        self.alphaBehavior = alphaBehavior
    }

    public var fingerprint: String {
        [
            "pass=\(index)",
            functionIdentity.fingerprint,
            output.fingerprint,
            resources.fingerprint,
            "alpha=\(alphaBehavior.rawValue)"
        ].joined(separator: "|")
    }
}

public struct HarbethKernelDescriptor: Sendable, Codable, Equatable, Hashable {
    public let filterName: String
    public let functionIdentity: HarbethKernelFunctionIdentity
    public let parameters: [String: HarbethKernelParameterValue]
    public let arguments: [HarbethKernelArgumentDescriptor]
    public let output: HarbethKernelOutputDescriptor
    public let resourceUsage: HarbethKernelResourceUsage
    public let resources: HarbethKernelResourceDescriptor
    public let alphaBehavior: HarbethKernelAlphaBehavior
    public let outputContract: RenderOutputContract
    public let passes: [HarbethKernelPassDescriptor]

    public init(filterName: String,
                functionIdentity: HarbethKernelFunctionIdentity,
                parameters: [String: HarbethKernelParameterValue] = [:],
                arguments: [HarbethKernelArgumentDescriptor] = [],
                output: HarbethKernelOutputDescriptor = HarbethKernelOutputDescriptor(),
                resourceUsage: HarbethKernelResourceUsage = .singleInput,
                resources: HarbethKernelResourceDescriptor? = nil,
                alphaBehavior: HarbethKernelAlphaBehavior = .preserveInput,
                outputContract: RenderOutputContract = .preserveInput,
                passes: [HarbethKernelPassDescriptor] = []) {
        self.filterName = filterName
        self.functionIdentity = functionIdentity
        self.parameters = parameters
        self.arguments = arguments.isEmpty
            ? HarbethKernelDescriptor.makeArgumentDescriptors(
                parameters: parameters,
                functionConstants: functionIdentity.functionConstants
            )
            : arguments
        self.output = output
        self.resourceUsage = resourceUsage
        self.resources = resources ?? HarbethKernelResourceDescriptor(usage: resourceUsage, inputTextureCount: 1)
        self.alphaBehavior = alphaBehavior
        self.outputContract = outputContract
        if passes.isEmpty {
            self.passes = [
                HarbethKernelPassDescriptor(
                    index: 0,
                    functionIdentity: functionIdentity,
                    output: output,
                    resources: self.resources,
                    alphaBehavior: alphaBehavior
                )
            ]
        } else {
            self.passes = passes
        }
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
            "arguments=\(arguments.map(\.fingerprint).joined(separator: "||"))",
            output.fingerprint,
            resources.fingerprint,
            "alpha=\(alphaBehavior.rawValue)",
            outputContract.fingerprint,
            "passes=\(passes.map(\.fingerprint).joined(separator: "||"))"
        ].joined(separator: "|")
    }

    private static func makeArgumentDescriptors(parameters: [String: HarbethKernelParameterValue],
                                                functionConstants: [HarbethKernelFunctionConstantDescriptor]) -> [HarbethKernelArgumentDescriptor] {
        let parameterDescriptors = parameters
            .sorted { $0.key < $1.key }
            .enumerated()
            .map { index, pair in
                HarbethKernelArgumentDescriptor(
                    name: pair.key,
                    index: index,
                    role: pair.key.defaultArgumentRole,
                    dataType: pair.value.argumentDataType,
                    required: pair.key != "hasCount" && pair.key != "otherInputTextures",
                    valueFingerprint: pair.value.fingerprint
                )
            }
        let constantDescriptors = functionConstants
            .sorted { lhs, rhs in
                if lhs.name == rhs.name {
                    return (lhs.index ?? -1) < (rhs.index ?? -1)
                }
                return lhs.name < rhs.name
            }
            .enumerated()
            .map { offset, constant in
                HarbethKernelArgumentDescriptor(
                    name: constant.name,
                    index: parameterDescriptors.count + offset,
                    role: .functionConstant,
                    dataType: constant.value.argumentDataType,
                    required: true,
                    valueFingerprint: constant.value.fingerprint
                )
            }
        return parameterDescriptors + constantDescriptors
    }
}

public extension C7FilterProtocol {
    func kernelDescriptor(inputSize: C7Size? = nil) -> HarbethKernelDescriptor {
        let outputSize = inputSize.map { resize(input: $0) }
        let functionIdentity: HarbethKernelFunctionIdentity
        let resourceUsage: HarbethKernelResourceUsage
        let inputTextureCount = 1 + otherInputTextures.count
        let requiresDestinationTexture: Bool
        switch modifier {
        case .compute(let kernel):
            functionIdentity = HarbethKernelFunctionIdentity(kind: .compute, primaryName: kernel)
            resourceUsage = otherInputTextures.isEmpty ? .singleInput : (otherInputTextures.count == 1 ? .dualInput : .multiInput)
            requiresDestinationTexture = true
        case .render(let vertex, let fragment):
            functionIdentity = HarbethKernelFunctionIdentity(kind: .render, primaryName: vertex, secondaryName: fragment)
            resourceUsage = otherInputTextures.isEmpty ? .singleInput : .multiInput
            requiresDestinationTexture = true
        case .blit:
            functionIdentity = HarbethKernelFunctionIdentity(kind: .blit, primaryName: "blit")
            resourceUsage = .generatesTexture
            requiresDestinationTexture = false
        case .mps(let kernel):
            functionIdentity = HarbethKernelFunctionIdentity(kind: .mps, primaryName: kernel.label ?? String(describing: Swift.type(of: kernel)))
            resourceUsage = .externalEncoder
            requiresDestinationTexture = true
        case .advancedMetal(_, let function):
            functionIdentity = HarbethKernelFunctionIdentity(kind: .advancedMetal, primaryName: function)
            resourceUsage = .externalEncoder
            requiresDestinationTexture = true
        }

        var parameters: [String: HarbethKernelParameterValue] = [
            "factors": .floatArray(factors),
            "hasCount": .bool(hasCount),
            "otherInputTextures": .int(otherInputTextures.count),
            "memoryAccessPattern": .string(String(describing: memoryAccessPattern))
        ]
        for (key, value) in parameterDescription {
            if let parameter = HarbethKernelParameterValue(value: value) {
                parameters[key] = parameter
            }
        }

        let alphaBehavior = defaultAlphaBehavior
        let outputContract = RenderOutputContract(alpha: alphaBehavior.renderAlphaContract)
        let resourceDescriptor = HarbethKernelResourceDescriptor(
            usage: resourceUsage,
            inputTextureCount: inputTextureCount,
            writesOutputTexture: modifier.writesOutputTexture,
            requiresDestinationTexture: requiresDestinationTexture,
            memoryAccessPattern: String(describing: memoryAccessPattern),
            hasPixelCountBuffer: hasCount
        )

        return HarbethKernelDescriptor(
            filterName: String(describing: Swift.type(of: self)),
            functionIdentity: functionIdentity,
            parameters: parameters,
            output: HarbethKernelOutputDescriptor(outputSize: outputSize),
            resourceUsage: resourceUsage,
            resources: resourceDescriptor,
            alphaBehavior: alphaBehavior,
            outputContract: outputContract
        )
    }

    private var defaultAlphaBehavior: HarbethKernelAlphaBehavior {
        if self is C7Opacity {
            return .modifiesAlpha
        }
        if self is C7PremultiplyAlpha {
            return .outputsPremultiplied
        }
        if self is C7UnpremultiplyAlpha {
            return .outputsNonPremultiplied
        }
        return .preserveInput
    }
}

private extension HarbethKernelParameterValue {
    init?(value: Any) {
        if let float = value as? Float {
            self = .float(float)
        } else if let double = value as? Double {
            self = .double(double)
        } else if let cgFloat = value as? CGFloat {
            self = .double(Double(cgFloat))
        } else if let int = value as? Int {
            self = .int(int)
        } else if let bool = value as? Bool {
            self = .bool(bool)
        } else if let string = value as? String {
            self = .string(string)
        } else if let values = value as? [Float] {
            self = .floatArray(values)
        } else if let values = value as? [Double] {
            self = .floatArray(values.map(Float.init))
        } else if let values = value as? [Int] {
            self = .intArray(values)
        } else if let values = value as? [String] {
            self = .stringArray(values)
        } else {
            self = .string(String(describing: value))
        }
    }

    var argumentDataType: HarbethKernelArgumentDataType {
        switch self {
        case .float:
            return .float
        case .double:
            return .double
        case .int:
            return .int
        case .bool:
            return .bool
        case .string:
            return .string
        case .floatArray:
            return .floatArray
        case .intArray:
            return .intArray
        case .stringArray:
            return .stringArray
        }
    }
}

private extension HarbethKernelFunctionConstantValue {
    var argumentDataType: HarbethKernelArgumentDataType {
        switch self {
        case .bool:
            return .bool
        case .int:
            return .int
        case .float:
            return .float
        case .string:
            return .string
        }
    }
}

private extension String {
    var defaultArgumentRole: HarbethKernelArgumentRole {
        switch self {
        case "otherInputTextures":
            return .inputTexture
        case "hasCount", "memoryAccessPattern":
            return .executionHint
        default:
            return .parameter
        }
    }
}

private extension ModifierEnum {
    var writesOutputTexture: Bool {
        switch self {
        case .blit:
            return false
        case .compute, .render, .mps, .advancedMetal:
            return true
        }
    }
}

extension HarbethKernelAlphaBehavior {
    var renderAlphaContract: ImageAlphaContract {
        switch self {
        case .preserveInput:
            return .preserveInput
        case .outputsOpaque:
            return .opaque
        case .outputsPremultiplied:
            return .premultiplied
        case .outputsNonPremultiplied:
            return .nonPremultiplied
        case .modifiesAlpha:
            return .preserveInput
        }
    }
}
