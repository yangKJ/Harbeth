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
        case .mps:
            usage = .externalEncoder
        case .metalCommand:
            usage = .metalCommand
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
