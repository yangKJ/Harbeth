//
//  SamplerExecutionAdapter.swift
//  Harbeth
//
//  Created by Condy on 2026/6/23.
//

import Foundation
import Metal

public enum SamplerExecutionCoverageMode: String, Sendable, Codable, Equatable, Hashable {
    case notApplicable
    case covered
    case partial
    case metadataOnly
}

public struct SamplerExecutionCoverage: Sendable, Codable, Equatable, Hashable {
    public let mode: SamplerExecutionCoverageMode
    public let coveredFilterTypes: [String]
    public let metadataOnlyFilterTypes: [String]

    public init(mode: SamplerExecutionCoverageMode, coveredFilterTypes: [String] = [], metadataOnlyFilterTypes: [String] = []) {
        self.mode = mode
        self.coveredFilterTypes = coveredFilterTypes
        self.metadataOnlyFilterTypes = metadataOnlyFilterTypes
    }

    public var summary: String {
        [
            "mode=\(mode.rawValue)",
            "covered=\(coveredFilterTypes.joined(separator: ","))",
            "metadataOnly=\(metadataOnlyFilterTypes.joined(separator: ","))"
        ].joined(separator: "|")
    }
}

enum SamplerExecutionAdapter {
    static func merge(_ lhs: SamplerExecutionCoverage, _ rhs: SamplerExecutionCoverage) -> SamplerExecutionCoverage {
        let covered = Array(Set(lhs.coveredFilterTypes + rhs.coveredFilterTypes)).sorted()
        let metadataOnly = Array(Set(lhs.metadataOnlyFilterTypes + rhs.metadataOnlyFilterTypes)).sorted()
        let mode: SamplerExecutionCoverageMode
        switch (covered.isEmpty, metadataOnly.isEmpty) {
        case (true, true):
            mode = .notApplicable
        case (true, false):
            mode = .metadataOnly
        case (false, true):
            mode = .covered
        case (false, false):
            mode = .partial
        }
        return SamplerExecutionCoverage(
            mode: mode,
            coveredFilterTypes: covered,
            metadataOnlyFilterTypes: metadataOnly
        )
    }

    static func adapt(filters: [C7FilterProtocol], samplerDescriptor: ImageSamplerDescriptor) -> [C7FilterProtocol] {
        guard filters.isEmpty == false, samplerDescriptor != .default else {
            return filters
        }
        return filters.map { adapt(filter: $0, samplerDescriptor: samplerDescriptor) }
    }

    static func adapt(filter: C7FilterProtocol, samplerDescriptor: ImageSamplerDescriptor) -> C7FilterProtocol {
        guard samplerDescriptor != .default else {
            return filter
        }
        if let filter = filter as? C7Crop {
            return adapt(filter: filter, samplerDescriptor: samplerDescriptor)
        }
        if let filter = filter as? C7Rotate {
            return adapt(filter: filter, samplerDescriptor: samplerDescriptor)
        }
        if let filter = filter as? C7Transform {
            return adapt(filter: filter, samplerDescriptor: samplerDescriptor)
        }
        if let filter = filter as? C7LensDistortionCorrection {
            return adapt(filter: filter, samplerDescriptor: samplerDescriptor)
        }
        if let filter = filter as? C7ChromaticAberrationCorrection {
            return adapt(filter: filter, samplerDescriptor: samplerDescriptor)
        }
        if let filter = filter as? RenderQuadTransform {
            return adapt(filter: filter, samplerDescriptor: samplerDescriptor)
        }
        if let filter = filter as? RenderQuadRectifyTransform {
            return adapt(filter: filter, samplerDescriptor: samplerDescriptor)
        }
        if let filter = filter as? any RenderProtocol {
            return adapt(renderFilter: filter, samplerDescriptor: samplerDescriptor)
        }
        return filter
    }

    static func adapt(renderFilter: any RenderProtocol, samplerDescriptor: ImageSamplerDescriptor) -> any RenderProtocol {
        guard samplerDescriptor != .default else {
            return renderFilter
        }
        return RenderSamplerOverride(base: renderFilter, samplerDescriptor: samplerDescriptor)
    }

    static func coverage(for filters: [C7FilterProtocol], samplerDescriptor: ImageSamplerDescriptor) -> SamplerExecutionCoverage {
        guard samplerDescriptor != .default else {
            return SamplerExecutionCoverage(mode: .notApplicable)
        }

        let relevantFilters = filters.filter(isSamplerSensitive)
        guard relevantFilters.isEmpty == false else {
            return SamplerExecutionCoverage(mode: .notApplicable)
        }

        var covered: [String] = []
        var metadataOnly: [String] = []

        for filter in relevantFilters {
            let typeName = String(describing: type(of: filter))
            if isExecutionCovered(filter, samplerDescriptor: samplerDescriptor) {
                covered.append(typeName)
            } else {
                metadataOnly.append(typeName)
            }
        }

        let uniqueCovered = Array(Set(covered)).sorted()
        let uniqueMetadataOnly = Array(Set(metadataOnly)).sorted()
        let mode: SamplerExecutionCoverageMode
        switch (uniqueCovered.isEmpty, uniqueMetadataOnly.isEmpty) {
        case (true, false):
            mode = .metadataOnly
        case (false, true):
            mode = .covered
        case (false, false):
            mode = .partial
        case (true, true):
            mode = .notApplicable
        }

        return SamplerExecutionCoverage(
            mode: mode,
            coveredFilterTypes: uniqueCovered,
            metadataOnlyFilterTypes: uniqueMetadataOnly
        )
    }

    private static func adapt(filter: RenderQuadTransform, samplerDescriptor: ImageSamplerDescriptor) -> RenderQuadTransform {
        var resolved = filter
        if let samplingMode = samplerDescriptor.preferredSpatialSamplingMode {
            resolved.samplingMode = samplingMode
        }
        if let edgeMode = samplerDescriptor.preferredSpatialEdgeMode {
            resolved.edgeMode = edgeMode
        }
        return resolved
    }

    private static func adapt(filter: C7Crop, samplerDescriptor: ImageSamplerDescriptor) -> C7Crop {
        filter.resolved(
            samplingMode: samplerDescriptor.preferredSpatialSamplingMode,
            edgeMode: samplerDescriptor.preferredSpatialEdgeMode
        )
    }

    private static func adapt(filter: C7Rotate, samplerDescriptor: ImageSamplerDescriptor) -> C7Rotate {
        var resolved = filter
        if let samplingMode = samplerDescriptor.preferredSpatialSamplingMode {
            resolved.samplingMode = samplingMode
        }
        if let edgeMode = samplerDescriptor.preferredSpatialEdgeMode {
            resolved.edgeMode = edgeMode
        }
        return resolved
    }

    private static func adapt(filter: C7Transform, samplerDescriptor: ImageSamplerDescriptor) -> C7Transform {
        var resolved = filter
        if let samplingMode = samplerDescriptor.preferredSpatialSamplingMode {
            resolved.samplingMode = samplingMode
        }
        if let edgeMode = samplerDescriptor.preferredSpatialEdgeMode {
            resolved.edgeMode = edgeMode
        }
        return resolved
    }

    private static func adapt(filter: C7LensDistortionCorrection, samplerDescriptor: ImageSamplerDescriptor) -> C7LensDistortionCorrection {
        var resolved = filter
        if let samplingMode = samplerDescriptor.preferredSpatialSamplingMode {
            resolved.samplingMode = samplingMode
        }
        if let edgeMode = samplerDescriptor.preferredSpatialEdgeMode {
            resolved.edgeMode = edgeMode
        }
        return resolved
    }

    private static func adapt(filter: C7ChromaticAberrationCorrection, samplerDescriptor: ImageSamplerDescriptor) -> C7ChromaticAberrationCorrection {
        var resolved = filter
        if let samplingMode = samplerDescriptor.preferredSpatialSamplingMode {
            resolved.samplingMode = samplingMode
        }
        if let edgeMode = samplerDescriptor.preferredSpatialEdgeMode {
            resolved.edgeMode = edgeMode
        }
        return resolved
    }

    private static func adapt(filter: RenderQuadRectifyTransform, samplerDescriptor: ImageSamplerDescriptor) -> RenderQuadRectifyTransform {
        var resolved = filter
        if let samplingMode = samplerDescriptor.preferredSpatialSamplingMode {
            resolved.samplingMode = samplingMode
        }
        if let edgeMode = samplerDescriptor.preferredSpatialEdgeMode {
            resolved.edgeMode = edgeMode
        }
        return resolved
    }

    private static func isSamplerSensitive(_ filter: C7FilterProtocol) -> Bool {
        if filter is RenderProtocol {
            return true
        }
        switch filter {
        case is C7Crop,
             is C7Rotate,
             is C7Transform,
             is C7LensDistortionCorrection,
             is C7ChromaticAberrationCorrection:
            return true
        default:
            return false
        }
    }

    private static func isExecutionCovered(_ filter: C7FilterProtocol) -> Bool {
        switch filter {
        case is RenderQuadTransform, is RenderQuadRectifyTransform:
            return true
        case is RenderProtocol:
            return true
        default:
            return false
        }
    }

    static func isExecutionCovered(_ filter: C7FilterProtocol, samplerDescriptor: ImageSamplerDescriptor) -> Bool {
        if isExecutionCovered(filter) {
            return true
        }
        switch filter {
        case is C7Crop,
             is C7Rotate,
             is C7Transform,
             is C7LensDistortionCorrection,
             is C7ChromaticAberrationCorrection:
            return samplerDescriptor.preferredSpatialSamplingMode != nil
                || samplerDescriptor.preferredSpatialEdgeMode != nil
        default:
            return false
        }
    }
}

private struct RenderSamplerOverride: RenderProtocol {
    let base: any RenderProtocol
    let samplerDescriptor: ImageSamplerDescriptor

    var identifier: String {
        "\(base.identifier)|sampler=\(samplerDescriptor.fingerprint)"
    }

    var modifier: ModifierEnum { base.modifier }
    var factors: [Float] { base.factors }
    var otherInputTextures: C7InputTextures { base.otherInputTextures }
    var kernelParameterBindings: [KernelParameterBinding] { base.kernelParameterBindings }
    var memoryAccessPattern: MemoryAccessPattern { base.memoryAccessPattern }
    var renderVertexStride: Int { base.renderVertexStride }
    var renderOutputContract: RenderOutputContract { base.renderOutputContract }
    var renderSamplerDescriptor: ImageSamplerDescriptor { samplerDescriptor }

    func resize(input size: C7Size) -> C7Size {
        base.resize(input: size)
    }

    func combinationBegin(for buffer: MTLCommandBuffer, source texture: MTLTexture, dest texture2: MTLTexture) throws -> MTLTexture {
        try base.combinationBegin(for: buffer, source: texture, dest: texture2)
    }

    func combinationAfter(for buffer: MTLCommandBuffer, input texture: MTLTexture, source texture2: MTLTexture) throws -> MTLTexture {
        try base.combinationAfter(for: buffer, input: texture, source: texture2)
    }

    func setupVertexUniformBuffer(for device: MTLDevice) -> MTLBuffer? {
        base.setupVertexUniformBuffer(for: device)
    }

    func setupFragmentUniformBuffer(for device: MTLDevice, inputSize: C7Size) -> MTLBuffer? {
        base.setupFragmentUniformBuffer(for: device, inputSize: inputSize)
    }

    func setupVertices(inputSize: C7Size) -> [Float]? {
        base.setupVertices(inputSize: inputSize)
    }
}

private extension ImageSamplerDescriptor {
    var preferredSpatialSamplingMode: SpatialSamplingMode? {
        if minFilter == .nearest, magFilter == .nearest {
            return .nearest
        }
        if minFilter == .linear, magFilter == .linear {
            return .linear
        }
        return nil
    }

    var preferredSpatialEdgeMode: SpatialEdgeMode? {
        guard sAddressMode == tAddressMode else {
            return nil
        }
        switch sAddressMode {
        case .clampToZero:
            return .transparent
        case .clampToEdge:
            return .clamp
        case .repeat:
            return .repeat
        case .mirrorRepeat:
            return .mirrorRepeat
        default:
            return nil
        }
    }
}
