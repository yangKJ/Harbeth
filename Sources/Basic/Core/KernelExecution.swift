//
//  KernelExecution.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import Metal

public enum KernelExecutableKind: String, Sendable, Codable, Equatable, Hashable {
    case compute
    case render
    case blit
    case mps
    case advancedMetal
}

public struct KernelExecutionPass: Sendable, Codable, Equatable, Hashable {
    public let index: Int
    public let kind: KernelExecutableKind
    public let functionIdentity: KernelFunctionIdentity
    public let output: KernelOutputDescriptor
    public let outputContract: RenderOutputContract
    public let inputTextureCount: Int
    public let requiresDestinationTexture: Bool
    public let alphaBehavior: KernelAlphaBehavior
    public let parameterFingerprint: String

    public init(index: Int,
                kind: KernelExecutableKind,
                functionIdentity: KernelFunctionIdentity,
                output: KernelOutputDescriptor,
                outputContract: RenderOutputContract,
                inputTextureCount: Int,
                requiresDestinationTexture: Bool,
                alphaBehavior: KernelAlphaBehavior,
                parameterFingerprint: String) {
        self.index = index
        self.kind = kind
        self.functionIdentity = functionIdentity
        self.output = output
        self.outputContract = outputContract
        self.inputTextureCount = inputTextureCount
        self.requiresDestinationTexture = requiresDestinationTexture
        self.alphaBehavior = alphaBehavior
        self.parameterFingerprint = parameterFingerprint
    }
}

public struct KernelExecutionPlan: Sendable, Codable, Equatable, Hashable {
    public let filterName: String
    public let kind: KernelExecutableKind
    public let passes: [KernelExecutionPass]
    public let outputContract: RenderOutputContract
    public let inputTextureCount: Int
    public let usesFunctionConstants: Bool
    public let expectedPixelFormat: PixelFormatContract
    public let compatibilitySummary: String

    public init(filterName: String,
                kind: KernelExecutableKind,
                passes: [KernelExecutionPass],
                outputContract: RenderOutputContract,
                inputTextureCount: Int,
                usesFunctionConstants: Bool,
                expectedPixelFormat: PixelFormatContract,
                compatibilitySummary: String) {
        self.filterName = filterName
        self.kind = kind
        self.passes = passes
        self.outputContract = outputContract
        self.inputTextureCount = inputTextureCount
        self.usesFunctionConstants = usesFunctionConstants
        self.expectedPixelFormat = expectedPixelFormat
        self.compatibilitySummary = compatibilitySummary
    }

    public var fingerprint: String {
        [
            "filter=\(filterName)",
            "kind=\(kind.rawValue)",
            "inputs=\(inputTextureCount)",
            "constants=\(usesFunctionConstants ? 1 : 0)",
            "pixel=\(expectedPixelFormat.fingerprint)",
            "compatibility=\(compatibilitySummary)",
            "passes=\(passes.map { "\($0.index):\($0.kind.rawValue):\($0.functionIdentity.fingerprint)" }.joined(separator: "||"))"
        ].joined(separator: "|")
    }
}

public protocol KernelExecutable {
    var kernelExecutionPlan: KernelExecutionPlan { get }
}

public enum KernelEncoder {
    public static func makeExecutionPlan(descriptor: KernelDescriptor,
                                         compatibilitySummary: String = "compatible") -> KernelExecutionPlan {
        let kind = executableKind(for: descriptor.functionIdentity.kind)
        let parameterFingerprint = descriptor.parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.fingerprint)" }
            .joined(separator: "|")
        let passes = descriptor.passes.map { pass in
            KernelExecutionPass(
                index: pass.index,
                kind: executableKind(for: pass.functionIdentity.kind),
                functionIdentity: pass.functionIdentity,
                output: pass.output,
                outputContract: descriptor.outputContract,
                inputTextureCount: pass.resources.inputTextureCount,
                requiresDestinationTexture: pass.resources.requiresDestinationTexture,
                alphaBehavior: pass.alphaBehavior,
                parameterFingerprint: parameterFingerprint
            )
        }
        return KernelExecutionPlan(
            filterName: descriptor.filterName,
            kind: kind,
            passes: passes,
            outputContract: descriptor.outputContract,
            inputTextureCount: descriptor.resources.inputTextureCount,
            usesFunctionConstants: descriptor.functionIdentity.functionConstants.isEmpty == false,
            expectedPixelFormat: descriptor.outputContract.pixelFormat,
            compatibilitySummary: compatibilitySummary
        )
    }

    private static func executableKind(for kind: KernelFunctionKind) -> KernelExecutableKind {
        switch kind {
        case .compute:
            return .compute
        case .render:
            return .render
        case .blit:
            return .blit
        case .mps:
            return .mps
        case .advancedMetal:
            return .advancedMetal
        }
    }
}
