//
//  KernelInvocation.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation

public struct KernelInvocation {
    public let descriptor: KernelDescriptor
    public let executableFilter: C7FilterProtocol
    public let compatibilitySummary: String
    public let executionPlan: KernelExecutionPlan

    public init(descriptor: KernelDescriptor,
                executableFilter: C7FilterProtocol,
                inputSize: C7Size? = nil) {
        self.descriptor = descriptor
        self.executableFilter = executableFilter
        let compatibilitySummary = descriptor.compatibilitySummary(
            with: executableFilter,
            inputSize: inputSize
        )
        self.compatibilitySummary = compatibilitySummary
        self.executionPlan = KernelEncoder.makeExecutionPlan(
            descriptor: descriptor,
            compatibilitySummary: compatibilitySummary
        )
    }

    public var isCompatible: Bool {
        compatibilitySummary == "compatible"
    }

    public var fingerprint: String {
        [
            descriptor.fingerprint,
            executableFilter.recipeDescriptor.fingerprint,
            executionPlan.fingerprint,
            "compatibility=\(compatibilitySummary)"
        ].joined(separator: " || ")
    }
}

extension KernelInvocation: KernelExecutable {
    public var kernelExecutionPlan: KernelExecutionPlan {
        executionPlan
    }
}
