//
//  KernelContract.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation

struct FilterKernelContractDescriptor: Sendable, Equatable {
    let functionIdentity: String
    let modifierName: String
    let otherInputTextureCount: Int
    let resourceUsage: KernelResourceUsage
    let alphaBehavior: KernelAlphaBehavior

    init(functionIdentity: String,
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

extension C7FilterProtocol {
    var kernelContract: FilterKernelContractDescriptor {
        let usage: KernelResourceUsage
        switch modifier {
        case .compute:
            usage = otherInputTextures.isEmpty ? .singleInput : .multiInput
        case .render:
            usage = otherInputTextures.isEmpty ? .singleInput : .multiInput
        case .blit:
            usage = .generatesTexture
        case .mps, .advancedMetal:
            usage = .externalEncoder
        }
        return FilterKernelContractDescriptor(
            functionIdentity: modifier.recipeName,
            modifierName: modifier.name,
            otherInputTextureCount: otherInputTextures.count,
            resourceUsage: usage,
            alphaBehavior: defaultAlphaBehavior
        )
    }
}
