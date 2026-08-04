//
//  FrameProcessingCapability.swift
//  Harbeth
//
//  Created by Condy on 2026/8/4.
//

import Foundation

/// 宿主对单帧像素处理链提出的执行要求。
public struct FrameProcessingRequirements: Sendable, Codable, Equatable, Hashable {
    public let allowsCPUReadback: Bool
    public let allowsGlobalDependency: Bool
    public let requiresDeterministicKernels: Bool
    public let requiresExtendedRangePreservation: Bool

    public init(
        allowsCPUReadback: Bool = false,
        allowsGlobalDependency: Bool = false,
        requiresDeterministicKernels: Bool = true,
        requiresExtendedRangePreservation: Bool = false
    ) {
        self.allowsCPUReadback = allowsCPUReadback
        self.allowsGlobalDependency = allowsGlobalDependency
        self.requiresDeterministicKernels = requiresDeterministicKernels
        self.requiresExtendedRangePreservation = requiresExtendedRangePreservation
    }

    /// SDR 动态媒体逐帧处理的默认要求。
    public static let dynamicFrame = FrameProcessingRequirements()

    /// HDR/EDR 动态媒体逐帧处理的默认要求。
    public static let extendedRangeDynamicFrame = FrameProcessingRequirements(
        requiresExtendedRangePreservation: true
    )
}

/// 单帧处理链无法满足宿主要求的结构化原因。
public enum FrameProcessingBlocker: String, Sendable, Codable, Equatable, Hashable {
    case cpuReadbackRequired
    case globalDependencyPresent
    case nonDeterministicKernelPresent
    case kernelContractEvidenceMissing
    case extendedRangePreservationUnproven
    case samplerDescriptorNotApplied
    case externalBoundaryContractUnproven
    case outputDynamicRangeUnsupported
    case outputPrecisionInsufficient
    case sdrToneMappingRequested
}

/// 基于已编译渲染计划得出的单帧处理能力。
public struct FrameProcessingCapability: Sendable, Codable, Equatable, Hashable {
    public let requirements: FrameProcessingRequirements
    public let blockers: [FrameProcessingBlocker]

    init(requirements: FrameProcessingRequirements, blockers: [FrameProcessingBlocker]) {
        self.requirements = requirements
        self.blockers = blockers
    }

    public var isSupported: Bool {
        blockers.isEmpty
    }
}

public extension RenderPlanDiagnostics {
    /// 使用真实 kernel、sampler 与渲染计划证据评估单帧处理能力。
    func frameProcessingCapability(for requirements: FrameProcessingRequirements = .dynamicFrame) -> FrameProcessingCapability {
        var blockers: [FrameProcessingBlocker] = []
        if requirements.allowsCPUReadback == false, cpuReadbackKernelCount > 0 {
            blockers.append(.cpuReadbackRequired)
        }
        if requirements.allowsGlobalDependency == false, globalDependencyKernelCount > 0 {
            blockers.append(.globalDependencyPresent)
        }
        if requirements.requiresDeterministicKernels, nonDeterministicKernelCount > 0 {
            blockers.append(.nonDeterministicKernelPresent)
        }
        if fallbackKernelPixelContractCount > 0 {
            blockers.append(.kernelContractEvidenceMissing)
        }
        if externalBoundaryCount > 0 {
            blockers.append(.externalBoundaryContractUnproven)
        }
        if requirements.requiresExtendedRangePreservation,
           extendedRangeSafeKernelCount != kernelPixelContractCount {
            blockers.append(.extendedRangePreservationUnproven)
        }
        if requirements.requiresExtendedRangePreservation {
            switch outputDynamicRange {
            case .preserveInput, .extendedDynamicRange, .highDynamicRange:
                break
            case .standardDynamicRange, .custom:
                blockers.append(.outputDynamicRangeUnsupported)
            }
            switch outputPixelFormat.precision {
            case .preserveInput, .float16, .float32:
                break
            case .unorm8, .custom:
                blockers.append(.outputPrecisionInsufficient)
            }
            if outputToneMappingPolicy == .toneMapToSDR {
                blockers.append(.sdrToneMappingRequested)
            }
        }
        switch samplerExecutionCoverage.mode {
        case .notApplicable, .covered:
            break
        case .partial, .metadataOnly:
            blockers.append(.samplerDescriptorNotApplied)
        }
        return FrameProcessingCapability(requirements: requirements, blockers: blockers)
    }
}

public extension RenderRequest {
    func frameProcessingCapability(for requirements: FrameProcessingRequirements = .dynamicFrame) -> FrameProcessingCapability {
        diagnostics.frameProcessingCapability(for: requirements)
    }
}

public extension HarbethIO {
    func makeFrameProcessingCapability(
        for requirements: FrameProcessingRequirements = .dynamicFrame,
        profile: RenderProfile = .stablePreview,
        derivative: ImageDerivativeSpec? = nil
    ) throws -> FrameProcessingCapability {
        try renderDiagnostics(profile: profile, derivative: derivative)
            .frameProcessingCapability(for: requirements)
    }
}

public extension ImageNode {
    func makeFrameProcessingCapability(
        for requirements: FrameProcessingRequirements = .dynamicFrame,
        profile: RenderProfile = .stablePreview,
        derivative: ImageDerivativeSpec? = nil
    ) throws -> FrameProcessingCapability {
        try makeDiagnostics(profile: profile, derivative: derivative)
            .frameProcessingCapability(for: requirements)
    }
}
