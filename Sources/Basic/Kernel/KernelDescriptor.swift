//
//  KernelDescriptor.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import CoreGraphics
import Metal

enum KernelResourceUsage: String, Sendable, Codable, Equatable, Hashable {
    case singleInput
    case dualInput
    case multiInput
    case generatesTexture
    case externalEncoder
}

enum KernelAlphaBehavior: String, Sendable, Codable, Equatable, Hashable {
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

    public init(name: String, index: Int? = nil, value: KernelFunctionConstantValue) {
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

enum KernelParameterValue: Sendable, Codable, Equatable, Hashable {
    case float(Float)
    case double(Double)
    case int(Int)
    case bool(Bool)
    case string(String)
    case floatArray([Float])
    case intArray([Int])
    case stringArray([String])

    var fingerprint: String {
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

enum KernelArgumentRole: String, Sendable, Codable, Equatable, Hashable {
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
    case float2
    case float3
    case float4
    case string
    case floatArray
    case intArray
    case stringArray
    case matrix3x3
    case matrix4x4
    case bytes
    case texture
    case unknown
}

struct KernelArgumentDescriptor: Sendable, Codable, Equatable, Hashable {
    let name: String
    let index: Int
    let role: KernelArgumentRole
    let dataType: KernelArgumentDataType
    let required: Bool
    let valueFingerprint: String?

    var fingerprint: String {
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

struct KernelResourceDescriptor: Sendable, Codable, Equatable, Hashable {
    let usage: KernelResourceUsage
    let inputTextureCount: Int
    let writesOutputTexture: Bool
    let requiresDestinationTexture: Bool
    let memoryAccessPattern: String

    init(usage: KernelResourceUsage,
         inputTextureCount: Int,
         writesOutputTexture: Bool = true,
         requiresDestinationTexture: Bool = true,
         memoryAccessPattern: String = "auto") {
        self.usage = usage
        self.inputTextureCount = inputTextureCount
        self.writesOutputTexture = writesOutputTexture
        self.requiresDestinationTexture = requiresDestinationTexture
        self.memoryAccessPattern = memoryAccessPattern
    }

    var fingerprint: String {
        [
            "usage=\(usage.rawValue)",
            "inputs=\(inputTextureCount)",
            "writes=\(writesOutputTexture ? 1 : 0)",
            "dest=\(requiresDestinationTexture ? 1 : 0)",
            "memory=\(memoryAccessPattern)"
        ].joined(separator: "|")
    }
}

struct KernelOutputDescriptor: Sendable, Codable, Equatable, Hashable {
    let outputSize: C7Size?
    let pixelFormat: String?

    init(outputSize: C7Size? = nil, pixelFormat: MTLPixelFormat? = nil) {
        self.outputSize = outputSize
        self.pixelFormat = pixelFormat.map { String(describing: $0) }
    }

    var fingerprint: String {
        [
            "size=\(outputSize.map { "\($0.width)x\($0.height)" } ?? "source")",
            "pixelFormat=\(pixelFormat ?? "preserve")"
        ].joined(separator: "|")
    }
}

struct KernelPassDescriptor: Sendable, Codable, Equatable, Hashable {
    let index: Int
    let functionIdentity: KernelFunctionIdentity
    let output: KernelOutputDescriptor
    let resources: KernelResourceDescriptor
    let alphaBehavior: KernelAlphaBehavior
    let renderPass: RenderPassContract?
    let drawCallCount: Int

    init(index: Int,
         functionIdentity: KernelFunctionIdentity,
         output: KernelOutputDescriptor = KernelOutputDescriptor(),
         resources: KernelResourceDescriptor,
         alphaBehavior: KernelAlphaBehavior = .preserveInput,
         renderPass: RenderPassContract? = nil,
         drawCallCount: Int = 1) {
        self.index = index
        self.functionIdentity = functionIdentity
        self.output = output
        self.resources = resources
        self.alphaBehavior = alphaBehavior
        self.renderPass = renderPass
        self.drawCallCount = max(drawCallCount, 1)
    }

    var fingerprint: String {
        [
            "pass=\(index)",
            functionIdentity.fingerprint,
            output.fingerprint,
            resources.fingerprint,
            "alpha=\(alphaBehavior.rawValue)",
            "renderPass=\(renderPass?.fingerprint ?? "none")",
            "drawCalls=\(drawCallCount)"
        ].joined(separator: "|")
    }
}

struct KernelDescriptor: Sendable, Codable, Equatable, Hashable {
    let filterName: String
    let functionIdentity: KernelFunctionIdentity
    let parameters: [String: KernelParameterValue]
    let parameterBindings: [KernelParameterBinding]
    let arguments: [KernelArgumentDescriptor]
    let output: KernelOutputDescriptor
    let resourceUsage: KernelResourceUsage
    let resources: KernelResourceDescriptor
    let alphaBehavior: KernelAlphaBehavior
    let inputColorSpace: ImageColorSpaceContract
    let outputContract: RenderOutputContract
    let passes: [KernelPassDescriptor]

    init(filterName: String,
         functionIdentity: KernelFunctionIdentity,
         parameters: [String: KernelParameterValue] = [:],
         parameterBindings: [KernelParameterBinding] = [],
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
        self.parameterBindings = parameterBindings
        self.arguments = arguments.isEmpty
            ? KernelDescriptor.makeArgumentDescriptors(
                parameters: parameters,
                parameterBindings: parameterBindings,
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
                    renderPass: nil,
                    drawCallCount: 1
                )
            ]
        } else {
            self.passes = passes
        }
    }

    var fingerprint: String {
        let parameterFingerprint = parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.fingerprint)" }
            .joined(separator: "|")
        let bindingFingerprint = parameterBindings
            .sorted { lhs, rhs in
                if lhs.index == rhs.index {
                    if lhs.stage == rhs.stage {
                        return lhs.name < rhs.name
                    }
                    return lhs.stage.rawValue < rhs.stage.rawValue
                }
                return lhs.index < rhs.index
            }
            .map(\.fingerprint)
            .joined(separator: "||")
        return [
            "filter=\(filterName)",
            functionIdentity.fingerprint,
            "params=\(parameterFingerprint)",
            "bindings=\(bindingFingerprint.isEmpty ? "none" : bindingFingerprint)",
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
                                                parameterBindings: [KernelParameterBinding],
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
                    required: pair.key != "otherInputTextures",
                    valueFingerprint: pair.value.fingerprint
                )
            }
        let bindingDescriptors = parameterBindings
            .sorted { lhs, rhs in
                if lhs.index == rhs.index {
                    if lhs.stage == rhs.stage {
                        return lhs.name < rhs.name
                    }
                    return lhs.stage.rawValue < rhs.stage.rawValue
                }
                return lhs.index < rhs.index
            }
            .map { binding in
                KernelArgumentDescriptor(
                    name: binding.name,
                    index: binding.index,
                    role: .parameter,
                    dataType: binding.value.argumentDataType,
                    required: binding.required,
                    valueFingerprint: binding.fingerprint
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
                    index: parameterDescriptors.count + bindingDescriptors.count + offset,
                    role: .functionConstant,
                    dataType: constant.value.argumentDataType,
                    required: true,
                    valueFingerprint: constant.value.fingerprint
                )
            }
        return parameterDescriptors + bindingDescriptors + constantDescriptors
    }
}

extension KernelDescriptor {
    func compatibilitySummary(with filter: C7FilterProtocol, inputSize: C7Size? = nil) -> String {
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
        if parameterBindings != runtimeDescriptor.parameterBindings {
            return "parameterBindingsMismatch"
        }
        return "compatible"
    }

    func matches(_ filter: C7FilterProtocol, inputSize: C7Size? = nil) -> Bool {
        compatibilitySummary(with: filter, inputSize: inputSize) == "compatible"
    }

    func validateCompatibility(with filter: C7FilterProtocol, inputSize: C7Size? = nil) throws {
        let summary = compatibilitySummary(with: filter, inputSize: inputSize)
        guard summary == "compatible" else {
            throw HarbethError.kernelInvocationIncompatible(summary)
        }
    }

    func makeInvocation(filter: C7FilterProtocol, inputSize: C7Size? = nil) -> KernelInvocation {
        KernelInvocation(descriptor: self, executableFilter: filter, inputSize: inputSize)
    }
}

extension C7FilterProtocol {
    func makeKernelExecutionPlan(inputSize: C7Size? = nil) -> KernelExecutionPlan {
        let descriptor = kernelDescriptor(inputSize: inputSize)
        return KernelEncoder.makeExecutionPlan(descriptor: descriptor)
    }

    func kernelDescriptor(inputSize: C7Size? = nil) -> KernelDescriptor {
        let outputSize = inputSize.map { resize(input: $0) }
        let pipelineFilter = self as? C7FilterPipelineProtocol
        let effectiveFilter = pipelineFilter?.makeFinalFilter(otherInputTextures: nil) ?? self
        let otherInputCount = pipelineFilter?.pipelineOtherInputCount ?? effectiveFilter.otherInputTextures.count
        let functionIdentity: KernelFunctionIdentity
        let resourceUsage: KernelResourceUsage
        let inputTextureCount = 1 + otherInputCount
        let requiresDestinationTexture: Bool
        switch effectiveFilter.modifier {
        case .compute(let kernel):
            functionIdentity = KernelFunctionIdentity(kind: .compute, primaryName: kernel)
            resourceUsage = otherInputCount == 0 ? .singleInput : (otherInputCount == 1 ? .dualInput : .multiInput)
            requiresDestinationTexture = true
        case .render(let vertex, let fragment):
            functionIdentity = KernelFunctionIdentity(kind: .render, primaryName: vertex, secondaryName: fragment)
            resourceUsage = otherInputCount == 0 ? .singleInput : .multiInput
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
            let advancedFilter = self as? C7AdvancedMetalKernelProtocol
            functionIdentity = KernelFunctionIdentity(
                kind: .advancedMetal,
                primaryName: function,
                librarySource: advancedFilter?.advancedMetalLibrarySource ?? .automatic,
                functionConstants: advancedFilter?.advancedMetalFunctionConstants ?? []
            )
            resourceUsage = .externalEncoder
            requiresDestinationTexture = true
        }

        let parameterBindings = effectiveFilter.kernelParameterBindings
        var parameters: [String: KernelParameterValue] = [
            "factors": .floatArray(parameterBindings.isEmpty ? effectiveFilter.factors : []),
            "otherInputTextures": .int(otherInputCount),
            "memoryAccessPattern": .string(String(describing: memoryAccessPattern))
        ]
        for (key, value) in parameterDescription {
            if let parameter = KernelParameterValue(value: value) {
                parameters[key] = parameter
            }
        }

        let alphaBehavior = defaultAlphaBehavior
        let outputContract: RenderOutputContract
        let renderPassContract: RenderPassContract?
        if case .render = effectiveFilter.modifier {
            let fallbackSize = inputSize ?? outputSize ?? C7Size(width: 1, height: 1)
            let renderFilter = effectiveFilter as? RenderProtocol
            let usesCustomVertexLayout = renderFilter?.renderVertexStride != 4
                || renderFilter?.setupVertices(inputSize: fallbackSize) != nil
            let declaredContract = renderFilter?.renderOutputContract ?? .preserveInput
            outputContract = RenderOutputContract(
                inputAlphaExpectation: declaredContract.inputAlphaExpectation,
                alpha: alphaBehavior.renderAlphaContract == .preserveInput ? declaredContract.alpha : alphaBehavior.renderAlphaContract,
                colorSpace: declaredContract.colorSpace,
                pixelFormat: declaredContract.pixelFormat,
                additionalAttachments: declaredContract.secondaryAttachments,
                colorTransferPolicy: declaredContract.colorTransferPolicy,
                pixelFormatFallbackPolicy: declaredContract.pixelFormatFallbackPolicy,
                allowsLossyConversion: declaredContract.allowsLossyConversion,
                preservesOrientation: declaredContract.preservesOrientation
            )
            renderPassContract = RenderPassContract(
                colorAttachments: outputContract.attachments.map {
                    ColorAttachmentContract(index: $0.index, pixelFormat: $0.pixelFormat.metalPixelFormat)
                },
                usesCustomVertexLayout: usesCustomVertexLayout
            )
        } else {
            outputContract = RenderOutputContract(alpha: alphaBehavior.renderAlphaContract)
            renderPassContract = nil
        }
        let resourceDescriptor = KernelResourceDescriptor(
            usage: resourceUsage,
            inputTextureCount: inputTextureCount,
            writesOutputTexture: effectiveFilter.modifier.writesOutputTexture,
            requiresDestinationTexture: requiresDestinationTexture,
            memoryAccessPattern: String(describing: memoryAccessPattern)
        )

        return KernelDescriptor(
            filterName: String(describing: Swift.type(of: self)),
            functionIdentity: functionIdentity,
            parameters: parameters,
            parameterBindings: parameterBindings,
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
                    renderPass: renderPassContract,
                    drawCallCount: 1
                )
            ]
        )
    }

    var defaultAlphaBehavior: KernelAlphaBehavior {
        if self is C7Opacity {
            return .modifiesAlpha
        }
        if self is C7PremultiplyAlpha {
            return .outputsPremultiplied
        }
        if self is C7UnpremultiplyAlpha {
            return .outputsNonPremultiplied
        }
        if self is C7ForceOpaqueAlpha {
            return .outputsOpaque
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
        case "memoryAccessPattern":
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
