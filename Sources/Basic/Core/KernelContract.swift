//
//  KernelContract.swift
//  Harbeth
//
//  Created by Codex on 2026/6/21.
//

import Foundation
import Metal

public enum KernelResourceUsage: String, Sendable, Codable, Equatable, Hashable {
    case readOnly
    case readWrite
    case multiInput
    case renderTarget
    case platformKernel
}

public enum KernelAlphaBehavior: String, Sendable, Codable, Equatable, Hashable {
    case preserve
    case rewrite
    case dependsOnKernel
}

public struct KernelContractDescriptor: Sendable, Equatable {
    public let functionIdentity: String
    public let modifierName: String
    public let otherInputTextureCount: Int
    public let resourceUsage: KernelResourceUsage
    public let alphaBehavior: KernelAlphaBehavior

    public init(functionIdentity: String,
                modifierName: String,
                otherInputTextureCount: Int,
                resourceUsage: KernelResourceUsage,
                alphaBehavior: KernelAlphaBehavior) {
        self.functionIdentity = functionIdentity
        self.modifierName = modifierName
        self.otherInputTextureCount = otherInputTextureCount
        self.resourceUsage = resourceUsage
        self.alphaBehavior = alphaBehavior
    }
}

public extension C7FilterProtocol {
    var kernelContract: KernelContractDescriptor {
        let usage: KernelResourceUsage
        switch modifier {
        case .compute:
            usage = otherInputTextures.isEmpty ? .readWrite : .multiInput
        case .render:
            usage = .renderTarget
        case .blit:
            usage = .readWrite
        case .mps, .advancedMetal:
            usage = .platformKernel
        }
        return KernelContractDescriptor(
            functionIdentity: modifier.recipeName,
            modifierName: modifier.name,
            otherInputTextureCount: otherInputTextures.count,
            resourceUsage: usage,
            alphaBehavior: otherInputTextures.isEmpty ? .preserve : .dependsOnKernel
        )
    }
}
