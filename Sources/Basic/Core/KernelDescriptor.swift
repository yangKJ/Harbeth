//
//  KernelDescriptor.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import CoreGraphics
import Metal

public enum KernelResourceUsage: String, Sendable, Codable, Equatable, Hashable {
    case singleInput
    case dualInput
    case multiInput
    case generatesTexture
    case externalEncoder
}

public enum KernelAlphaBehavior: String, Sendable, Codable, Equatable, Hashable {
    case preserveInput
    case outputsOpaque
    case outputsPremultiplied
    case outputsNonPremultiplied
    case modifiesAlpha
}

public enum KernelFunctionKind: String, Sendable, Codable, Equatable, Hashable {
    case compute
    case render
    case blit
    case mps
    case advancedMetal
}

public enum KernelLibrarySource: Sendable, Codable, Equatable, Hashable {
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

public enum KernelFunctionConstantValue: Sendable, Codable, Equatable, Hashable {
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

public struct KernelFunctionConstantDescriptor: Sendable, Codable, Equatable, Hashable {
    public let name: String
    public let index: Int?
    public let value: KernelFunctionConstantValue

    public init(name: String,
                index: Int? = nil,
                value: KernelFunctionConstantValue) {
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

public struct KernelFunctionIdentity: Sendable, Codable, Equatable, Hashable {
    public let kind: KernelFunctionKind
    public let primaryName: String
    public let secondaryName: String?
    public let librarySource: KernelLibrarySource
    public let functionConstants: [KernelFunctionConstantDescriptor]

    public init(kind: KernelFunctionKind,
                primaryName: String,
                secondaryName: String? = nil,
                librarySource: KernelLibrarySource = .automatic,
                functionConstants: [KernelFunctionConstantDescriptor] = []) {
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

public extension KernelFunctionIdentity {
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

public enum KernelParameterValue: Sendable, Codable, Equatable, Hashable {
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

private extension KernelFunctionConstantDescriptor {
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

public enum KernelArgumentRole: String, Sendable, Codable, Equatable, Hashable {
    case parameter
    case functionConstant
    case inputTexture
    case outputTexture
    case resourceState
    case executionHint
}

public enum KernelArgumentDataType: String, Sendable, Codable, Equatable, Hashable {
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

public struct KernelArgumentDescriptor: Sendable, Codable, Equatable, Hashable {
    public let name: String
    public let index: Int
    public let role: KernelArgumentRole
    public let dataType: KernelArgumentDataType
    public let required: Bool
    public let valueFingerprint: String?

    public init(name: String,
                index: Int,
                role: KernelArgumentRole,
                dataType: KernelArgumentDataType,
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

public struct KernelResourceDescriptor: Sendable, Codable, Equatable, Hashable {
    public let usage: KernelResourceUsage
    public let inputTextureCount: Int
    public let writesOutputTexture: Bool
    public let requiresDestinationTexture: Bool
    public let memoryAccessPattern: String
    public let hasPixelCountBuffer: Bool

    public init(usage: KernelResourceUsage,
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

public struct KernelOutputDescriptor: Sendable, Codable, Equatable, Hashable {
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

public struct KernelPassDescriptor: Sendable, Codable, Equatable, Hashable {
    public let index: Int
    public let functionIdentity: KernelFunctionIdentity
    public let output: KernelOutputDescriptor
    public let resources: KernelResourceDescriptor
    public let alphaBehavior: KernelAlphaBehavior
    public let renderPass: RenderPassContract?

    public init(index: Int,
                functionIdentity: KernelFunctionIdentity,
                output: KernelOutputDescriptor = KernelOutputDescriptor(),
                resources: KernelResourceDescriptor,
                alphaBehavior: KernelAlphaBehavior = .preserveInput,
                renderPass: RenderPassContract? = nil) {
        self.index = index
        self.functionIdentity = functionIdentity
        self.output = output
        self.resources = resources
        self.alphaBehavior = alphaBehavior
        self.renderPass = renderPass
    }

    public var fingerprint: String {
        [
            "pass=\(index)",
            functionIdentity.fingerprint,
            output.fingerprint,
            resources.fingerprint,
            "alpha=\(alphaBehavior.rawValue)",
            "renderPass=\(renderPass?.fingerprint ?? "none")"
        ].joined(separator: "|")
    }
}

public struct KernelDescriptor: Sendable, Codable, Equatable, Hashable {
    public let filterName: String
    public let functionIdentity: KernelFunctionIdentity
    public let parameters: [String: KernelParameterValue]
    public let arguments: [KernelArgumentDescriptor]
    public let output: KernelOutputDescriptor
    public let resourceUsage: KernelResourceUsage
    public let resources: KernelResourceDescriptor
    public let alphaBehavior: KernelAlphaBehavior
    public let inputColorSpace: ImageColorSpaceContract
    public let outputContract: RenderOutputContract
    public let passes: [KernelPassDescriptor]

    public init(filterName: String,
                functionIdentity: KernelFunctionIdentity,
                parameters: [String: KernelParameterValue] = [:],
                arguments: [KernelArgumentDescriptor] = [],
                output: KernelOutputDescriptor = KernelOutputDescriptor(),
                resourceUsage: KernelResourceUsage = .singleInput,
                resources: KernelResourceDescriptor? = nil,
                alphaBehavior: KernelAlphaBehavior = .preserveInput,
                inputColorSpace: ImageColorSpaceContract = .preserveInput,
                outputContract: RenderOutputContract = .preserveInput,
                passes: [KernelPassDescriptor] = []) {
        self.filterName = filterName
        self.functionIdentity = functionIdentity
        self.parameters = parameters
        self.arguments = arguments.isEmpty
            ? KernelDescriptor.makeArgumentDescriptors(
                parameters: parameters,
                functionConstants: functionIdentity.functionConstants
            )
            : arguments
        self.output = output
        self.resourceUsage = resourceUsage
        self.resources = resources ?? KernelResourceDescriptor(usage: resourceUsage, inputTextureCount: 1)
        self.alphaBehavior = alphaBehavior
        self.inputColorSpace = inputColorSpace
        self.outputContract = outputContract
        if passes.isEmpty {
            self.passes = [
                KernelPassDescriptor(
                    index: 0,
                    functionIdentity: functionIdentity,
                    output: output,
                    resources: self.resources,
                    alphaBehavior: alphaBehavior,
                    renderPass: nil
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
            "inputColor=\(inputColorSpace.fingerprint)",
            outputContract.fingerprint,
            "passes=\(passes.map(\.fingerprint).joined(separator: "||"))"
        ].joined(separator: "|")
    }

    private static func makeArgumentDescriptors(parameters: [String: KernelParameterValue],
                                                functionConstants: [KernelFunctionConstantDescriptor]) -> [KernelArgumentDescriptor] {
        let parameterDescriptors = parameters
            .sorted { $0.key < $1.key }
            .enumerated()
            .map { index, pair in
                KernelArgumentDescriptor(
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
                KernelArgumentDescriptor(
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

public extension KernelDescriptor {
    func compatibilitySummary(with filter: C7FilterProtocol,
                              inputSize: C7Size? = nil) -> String {
        let runtimeDescriptor = filter.kernelDescriptor(inputSize: inputSize)
        if functionIdentity != runtimeDescriptor.functionIdentity {
            return "functionIdentityMismatch"
        }
        if resourceUsage != runtimeDescriptor.resourceUsage {
            return "resourceUsageMismatch"
        }
        if resources.inputTextureCount != runtimeDescriptor.resources.inputTextureCount {
            return "inputTextureCountMismatch"
        }
        return "compatible"
    }

    func matches(_ filter: C7FilterProtocol, inputSize: C7Size? = nil) -> Bool {
        compatibilitySummary(with: filter, inputSize: inputSize) == "compatible"
    }

    func makeInvocation(filter: C7FilterProtocol,
                        inputSize: C7Size? = nil) -> KernelInvocation {
        KernelInvocation(
            descriptor: self,
            executableFilter: filter,
            inputSize: inputSize
        )
    }
}

public extension C7FilterProtocol {
    func makeKernelExecutionPlan(inputSize: C7Size? = nil) -> KernelExecutionPlan {
        let descriptor = kernelDescriptor(inputSize: inputSize)
        return KernelEncoder.makeExecutionPlan(descriptor: descriptor)
    }

    func kernelDescriptor(inputSize: C7Size? = nil) -> KernelDescriptor {
        let outputSize = inputSize.map { resize(input: $0) }
        let functionIdentity: KernelFunctionIdentity
        let resourceUsage: KernelResourceUsage
        let inputTextureCount = 1 + otherInputTextures.count
        let requiresDestinationTexture: Bool
        switch modifier {
        case .compute(let kernel):
            functionIdentity = KernelFunctionIdentity(kind: .compute, primaryName: kernel)
            resourceUsage = otherInputTextures.isEmpty ? .singleInput : (otherInputTextures.count == 1 ? .dualInput : .multiInput)
            requiresDestinationTexture = true
        case .render(let vertex, let fragment):
            functionIdentity = KernelFunctionIdentity(kind: .render, primaryName: vertex, secondaryName: fragment)
            resourceUsage = otherInputTextures.isEmpty ? .singleInput : .multiInput
            requiresDestinationTexture = true
        case .blit:
            functionIdentity = KernelFunctionIdentity(kind: .blit, primaryName: "blit")
            resourceUsage = .generatesTexture
            requiresDestinationTexture = false
        case .mps(let kernel):
            functionIdentity = KernelFunctionIdentity(kind: .mps, primaryName: kernel.label ?? String(describing: Swift.type(of: kernel)))
            resourceUsage = .externalEncoder
            requiresDestinationTexture = true
        case .advancedMetal(_, let function):
            functionIdentity = KernelFunctionIdentity(kind: .advancedMetal, primaryName: function)
            resourceUsage = .externalEncoder
            requiresDestinationTexture = true
        }

        var parameters: [String: KernelParameterValue] = [
            "factors": .floatArray(factors),
            "hasCount": .bool(hasCount),
            "otherInputTextures": .int(otherInputTextures.count),
            "memoryAccessPattern": .string(String(describing: memoryAccessPattern))
        ]
        for (key, value) in parameterDescription {
            if let parameter = KernelParameterValue(value: value) {
                parameters[key] = parameter
            }
        }

        let alphaBehavior = defaultAlphaBehavior
        let outputContract = RenderOutputContract(alpha: alphaBehavior.renderAlphaContract)
        let renderPassContract: RenderPassContract?
        if case .render = modifier {
            let fallbackSize = inputSize ?? outputSize ?? C7Size(width: 1, height: 1)
            let usesCustomVertexLayout = (self as? RenderProtocol)?.renderVertexStride != 4
                || (self as? RenderProtocol)?.setupVertices(inputSize: fallbackSize) != nil
            renderPassContract = .singleColor(usesCustomVertexLayout: usesCustomVertexLayout)
        } else {
            renderPassContract = nil
        }
        let resourceDescriptor = KernelResourceDescriptor(
            usage: resourceUsage,
            inputTextureCount: inputTextureCount,
            writesOutputTexture: modifier.writesOutputTexture,
            requiresDestinationTexture: requiresDestinationTexture,
            memoryAccessPattern: String(describing: memoryAccessPattern),
            hasPixelCountBuffer: hasCount
        )

        return KernelDescriptor(
            filterName: String(describing: Swift.type(of: self)),
            functionIdentity: functionIdentity,
            parameters: parameters,
            output: KernelOutputDescriptor(outputSize: outputSize),
            resourceUsage: resourceUsage,
            resources: resourceDescriptor,
            alphaBehavior: alphaBehavior,
            outputContract: outputContract,
            passes: [
                KernelPassDescriptor(
                    index: 0,
                    functionIdentity: functionIdentity,
                    output: KernelOutputDescriptor(outputSize: outputSize),
                    resources: resourceDescriptor,
                    alphaBehavior: alphaBehavior,
                    renderPass: renderPassContract
                )
            ]
        )
    }

    private var defaultAlphaBehavior: KernelAlphaBehavior {
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

private extension KernelParameterValue {
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

    var argumentDataType: KernelArgumentDataType {
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

private extension KernelFunctionConstantValue {
    var argumentDataType: KernelArgumentDataType {
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
    var defaultArgumentRole: KernelArgumentRole {
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

extension KernelAlphaBehavior {
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
