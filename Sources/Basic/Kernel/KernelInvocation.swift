//
//  KernelInvocation.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation

struct KernelInvocation {
    let descriptor: KernelDescriptor
    let executableFilter: C7FilterProtocol
    let compatibilitySummary: String
    let executionPlan: KernelExecutionPlan

    init(descriptor: KernelDescriptor, executableFilter: C7FilterProtocol, inputSize: C7Size? = nil) {
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

    var isCompatible: Bool {
        compatibilitySummary == "compatible"
    }

    var fingerprint: String {
        [
            descriptor.fingerprint,
            executableFilter.recipeDescriptor.fingerprint,
            executionPlan.fingerprint,
            "compatibility=\(compatibilitySummary)"
        ].joined(separator: " || ")
    }
}

extension KernelInvocation: KernelExecutable {
    var kernelExecutionPlan: KernelExecutionPlan {
        executionPlan
    }
}
