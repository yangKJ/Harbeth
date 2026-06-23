//
//  KernelExecution.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import Metal

struct KernelExecutionPass: Sendable, Codable, Equatable, Hashable {
    let index: Int
    let kind: KernelFunctionKind
    let functionIdentity: KernelFunctionIdentity
    let output: KernelOutputDescriptor
    let outputContract: RenderOutputContract
    let inputTextureCount: Int
    let requiresDestinationTexture: Bool
    let alphaBehavior: KernelAlphaBehavior
    let drawCallCount: Int
    let parameterFingerprint: String

    init(index: Int,
         kind: KernelFunctionKind,
         functionIdentity: KernelFunctionIdentity,
         output: KernelOutputDescriptor,
         outputContract: RenderOutputContract,
         inputTextureCount: Int,
         requiresDestinationTexture: Bool,
         alphaBehavior: KernelAlphaBehavior,
         drawCallCount: Int = 1,
         parameterFingerprint: String) {
        self.index = index
        self.kind = kind
        self.functionIdentity = functionIdentity
        self.output = output
        self.outputContract = outputContract
        self.inputTextureCount = inputTextureCount
        self.requiresDestinationTexture = requiresDestinationTexture
        self.alphaBehavior = alphaBehavior
        self.drawCallCount = max(drawCallCount, 1)
        self.parameterFingerprint = parameterFingerprint
    }
}

struct KernelExecutionPlan: Sendable, Codable, Equatable, Hashable {
    let filterName: String
    let kind: KernelFunctionKind
    let passes: [KernelExecutionPass]
    let outputContract: RenderOutputContract
    let inputTextureCount: Int
    let usesFunctionConstants: Bool
    let expectedPixelFormat: PixelFormatContract
    let compatibilitySummary: String

    var fingerprint: String {
        [
            "filter=\(filterName)",
            "kind=\(kind.rawValue)",
            "inputs=\(inputTextureCount)",
            "constants=\(usesFunctionConstants ? 1 : 0)",
            "pixel=\(expectedPixelFormat.fingerprint)",
            "outputAttachments=\(outputAttachmentCount)",
            "outputAttachmentSemantics=\(outputAttachmentSemantics.joined(separator: ","))",
            "outputAttachmentPixels=\(outputAttachmentPixelFormats.joined(separator: ","))",
            "compatibility=\(compatibilitySummary)",
            "passes=\(passes.map { "\($0.index):\($0.kind.rawValue):draws=\($0.drawCallCount):attachments=\($0.outputContract.attachmentCount):\($0.functionIdentity.fingerprint)" }.joined(separator: "||"))"
        ].joined(separator: "|")
    }

    var outputAttachmentCount: Int {
        outputContract.attachmentCount
    }

    var outputAttachmentPixelFormats: [String] {
        outputContract.attachments.map { $0.pixelFormat.name }
    }

    var outputAttachmentSemantics: [String] {
        outputContract.attachments.map { $0.semantic.rawValue }
    }
}

protocol KernelExecutable {
    var kernelExecutionPlan: KernelExecutionPlan { get }
}

enum KernelEncoder {
    static func makeExecutionPlan(descriptor: KernelDescriptor, compatibilitySummary: String = "compatible") -> KernelExecutionPlan {
        let kind = descriptor.functionIdentity.kind
        let parameterFingerprint = descriptor.parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.fingerprint)" }
            .joined(separator: "|")
        let bindingFingerprint = descriptor.parameterBindings
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
        let executionFingerprint = [parameterFingerprint, bindingFingerprint].filter { !$0.isEmpty }.joined(separator: "||")
        let passes = descriptor.passes.map { pass in
            KernelExecutionPass(
                index: pass.index,
                kind: pass.functionIdentity.kind,
                functionIdentity: pass.functionIdentity,
                output: pass.output,
                outputContract: descriptor.outputContract,
                inputTextureCount: pass.resources.inputTextureCount,
                requiresDestinationTexture: pass.resources.requiresDestinationTexture,
                alphaBehavior: pass.alphaBehavior,
                drawCallCount: pass.drawCallCount,
                parameterFingerprint: executionFingerprint
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
}
