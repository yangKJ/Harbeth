//
//  KernelContract.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import Metal

public enum FilterKernelResourceUsage: String, Sendable, Codable, Equatable, Hashable {
    case readOnly
    case readWrite
    case multiInput
    case renderTarget
    case platformKernel
}

public enum FilterKernelAlphaBehavior: String, Sendable, Codable, Equatable, Hashable {
    case preserve
    case rewrite
    case dependsOnKernel
}

public struct FilterKernelContractDescriptor: Sendable, Equatable {
    public let functionIdentity: String
    public let modifierName: String
    public let otherInputTextureCount: Int
    public let resourceUsage: FilterKernelResourceUsage
    public let alphaBehavior: FilterKernelAlphaBehavior

    public init(functionIdentity: String,
                modifierName: String,
                otherInputTextureCount: Int,
                resourceUsage: FilterKernelResourceUsage,
                alphaBehavior: FilterKernelAlphaBehavior) {
        self.functionIdentity = functionIdentity
        self.modifierName = modifierName
        self.otherInputTextureCount = otherInputTextureCount
        self.resourceUsage = resourceUsage
        self.alphaBehavior = alphaBehavior
    }
}

public extension C7FilterProtocol {
    var kernelContract: FilterKernelContractDescriptor {
        let usage: FilterKernelResourceUsage
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
        return FilterKernelContractDescriptor(
            functionIdentity: modifier.recipeName,
            modifierName: modifier.name,
            otherInputTextureCount: otherInputTextures.count,
            resourceUsage: usage,
            alphaBehavior: otherInputTextures.isEmpty ? .preserve : .dependsOnKernel
        )
    }
}
