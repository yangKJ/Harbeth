//
//  HarbethKernelInvocation.swift
//  Harbeth
//
//  Created by Codex on 2026/6/21.
//

import Foundation

public struct HarbethKernelInvocation {
    public let descriptor: HarbethKernelDescriptor
    public let executableFilter: C7FilterProtocol
    public let compatibilitySummary: String

    public init(descriptor: HarbethKernelDescriptor,
                executableFilter: C7FilterProtocol,
                inputSize: C7Size? = nil) {
        self.descriptor = descriptor
        self.executableFilter = executableFilter
        self.compatibilitySummary = descriptor.compatibilitySummary(
            with: executableFilter,
            inputSize: inputSize
        )
    }

    public var isCompatible: Bool {
        compatibilitySummary == "compatible"
    }

    public var fingerprint: String {
        [
            descriptor.fingerprint,
            executableFilter.recipeDescriptor.fingerprint,
            "compatibility=\(compatibilitySummary)"
        ].joined(separator: " || ")
    }
}
