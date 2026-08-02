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
    static func makePlan(filters: [C7FilterProtocol], samplerDescriptor: ImageSamplerDescriptor) -> SamplerExecutionPlan {
        guard filters.isEmpty == false, samplerDescriptor != .default else {
            return SamplerExecutionPlan(
                filters: filters,
                coverage: SamplerExecutionCoverage(mode: .notApplicable)
            )
        }

        let resolutions = filters.map { resolve(filter: $0, samplerDescriptor: samplerDescriptor) }
        var coverage = SamplerExecutionCoverage(mode: .notApplicable)
        for (filter, resolution) in zip(filters, resolutions) where isSamplerRelevant(filter) {
            let typeName = String(describing: type(of: filter))
            let item: SamplerExecutionCoverage
            switch resolution.coverage {
            case .covered:
                item = SamplerExecutionCoverage(mode: .covered, coveredFilterTypes: [typeName])
            case .partial:
                item = SamplerExecutionCoverage(
                    mode: .partial,
                    coveredFilterTypes: [typeName],
                    metadataOnlyFilterTypes: [typeName]
                )
            case .metadataOnly:
                item = SamplerExecutionCoverage(mode: .metadataOnly, metadataOnlyFilterTypes: [typeName])
            case .notApplicable:
                item = SamplerExecutionCoverage(mode: .notApplicable)
            }
            coverage = merge(coverage, item)
        }
        return SamplerExecutionPlan(filters: resolutions.map(\.filter), coverage: coverage)
    }

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
        makePlan(filters: filters, samplerDescriptor: samplerDescriptor).filters
    }

    static func adapt(filter: C7FilterProtocol, samplerDescriptor: ImageSamplerDescriptor) -> C7FilterProtocol {
        resolve(filter: filter, samplerDescriptor: samplerDescriptor).filter
    }

    static func adapt(renderFilter: any RenderProtocol, samplerDescriptor: ImageSamplerDescriptor) -> any RenderProtocol {
        guard samplerDescriptor != .default else {
            return renderFilter
        }
        if let configurable = renderFilter as? SamplerAdaptableFilter {
            switch configurable.samplerAdaptation(for: samplerDescriptor) {
            case .covered(let adaptedFilter):
                return adaptedFilter as? any RenderProtocol ?? renderFilter
            case .partial(let adaptedFilter):
                return adaptedFilter as? any RenderProtocol ?? renderFilter
            case .metadataOnly, .notApplicable:
                return renderFilter
            }
        }
        guard renderFilter.renderSamplerConsumption == .runtimeBound else {
            return renderFilter
        }
        return RenderSamplerOverride(base: renderFilter, samplerDescriptor: samplerDescriptor)
    }

    static func coverage(for filters: [C7FilterProtocol], samplerDescriptor: ImageSamplerDescriptor) -> SamplerExecutionCoverage {
        makePlan(filters: filters, samplerDescriptor: samplerDescriptor).coverage
    }

    private static func resolve(filter: C7FilterProtocol, samplerDescriptor: ImageSamplerDescriptor) -> SamplerExecutionResolution {
        guard samplerDescriptor != .default else {
            return SamplerExecutionResolution(filter: filter, coverage: .notApplicable)
        }
        if let configurable = filter as? SamplerAdaptableFilter {
            switch configurable.samplerAdaptation(for: samplerDescriptor) {
            case .covered(let adaptedFilter):
                return SamplerExecutionResolution(filter: adaptedFilter, coverage: .covered)
            case .partial(let adaptedFilter):
                return SamplerExecutionResolution(filter: adaptedFilter, coverage: .partial)
            case .metadataOnly:
                return SamplerExecutionResolution(filter: filter, coverage: .metadataOnly)
            case .notApplicable:
                break
            }
        }
        if let renderFilter = filter as? any RenderProtocol,
           renderFilter.renderSamplerConsumption == .runtimeBound {
            return SamplerExecutionResolution(
                filter: RenderSamplerOverride(base: renderFilter, samplerDescriptor: samplerDescriptor),
                coverage: .covered
            )
        }
        if filter is any RenderProtocol {
            return SamplerExecutionResolution(filter: filter, coverage: .metadataOnly)
        }
        return SamplerExecutionResolution(filter: filter, coverage: .notApplicable)
    }

    private static func isSamplerRelevant(_ filter: C7FilterProtocol) -> Bool {
        filter is SamplerAdaptableFilter || filter is RenderProtocol
    }
}

struct SamplerExecutionPlan {
    let filters: [C7FilterProtocol]
    let coverage: SamplerExecutionCoverage
}

private struct SamplerExecutionResolution {
    let filter: C7FilterProtocol
    let coverage: SamplerExecutionCoverageMode
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
    var renderSamplerConsumption: RenderSamplerConsumption { base.renderSamplerConsumption }

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
