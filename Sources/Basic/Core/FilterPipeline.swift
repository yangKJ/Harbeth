//
//  FilterPipeline.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import MetalKit

public enum FilterPipelineExecutionStyle: String, Sendable, Codable, Equatable, Hashable {
    case sequential
    case parallelFromSource
}

public protocol C7FilterPipelineProtocol: C7FilterProtocol {
    var pipelineFilters: [C7FilterProtocol] { get }
    var pipelineExecutionStyle: FilterPipelineExecutionStyle { get }
    var pipelineOtherInputCount: Int { get }
    func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol?
}

public extension C7FilterPipelineProtocol {
    var pipelineExecutionStyle: FilterPipelineExecutionStyle { .sequential }
    var pipelineOtherInputCount: Int {
        switch pipelineExecutionStyle {
        case .sequential:
            return pipelineFilters.isEmpty ? 0 : 1
        case .parallelFromSource:
            return pipelineFilters.count
        }
    }
    func applyAtTexture(form texture: MTLTexture, to destTexture: MTLTexture, for buffer: MTLCommandBuffer) throws -> MTLTexture {
        try FilterPipelineExecutor.apply(filter: self, source: texture, destination: destTexture, commandBuffer: buffer)
    }
}

struct PipelineLeafFilter: C7FilterProtocol {
    let modifier: ModifierEnum
    let factors: [Float]
    let otherInputTextures: C7InputTextures
    let kernelParameterBindings: [KernelParameterBinding]

    init(modifier: ModifierEnum, factors: [Float] = [], otherInputTextures: C7InputTextures = [], kernelParameterBindings: [KernelParameterBinding] = []) {
        self.modifier = modifier
        self.factors = factors
        self.otherInputTextures = otherInputTextures
        self.kernelParameterBindings = kernelParameterBindings
    }
}

public extension C7FilterPipelineProtocol {
    var modifier: ModifierEnum {
        guard let finalFilter = makeFinalFilter(otherInputTextures: nil) else {
            fatalError("Pipeline combination filters must provide a final filter.")
        }
        return finalFilter.modifier
    }

    var factors: [Float] {
        makeFinalFilter(otherInputTextures: nil)?.factors ?? []
    }

    var kernelParameterBindings: [KernelParameterBinding] {
        makeFinalFilter(otherInputTextures: nil)?.kernelParameterBindings ?? []
    }

    var otherInputTextures: C7InputTextures { [] }
}

enum FilterPipelineExecutor {
    static func apply(filter: C7FilterPipelineProtocol, source: MTLTexture, destination: MTLTexture, commandBuffer: MTLCommandBuffer) throws -> MTLTexture {
        let style = filter.pipelineExecutionStyle
        let pipelineFilters = filter.pipelineFilters
        let auxiliaryTextures: [MTLTexture]
        let transientTextures: [MTLTexture]

        switch style {
        case .sequential:
            let execution = try executeSequentialPipeline(filters: pipelineFilters,
                                                          source: source,
                                                          destination: destination,
                                                          commandBuffer: commandBuffer)
            auxiliaryTextures = execution.auxiliaryTextures
            transientTextures = execution.transientTextures
        case .parallelFromSource:
            let execution = try executeParallelPipeline(filters: pipelineFilters, source: source, commandBuffer: commandBuffer)
            auxiliaryTextures = execution.auxiliaryTextures
            transientTextures = execution.transientTextures
        }

        if let finalFilter = filter.makeFinalFilter(otherInputTextures: auxiliaryTextures) {
            _ = try finalFilter.apply(form: source, to: destination, for: commandBuffer, complete: nil)
        }

        let texturesToRecycle = transientTextures.filter { $0 !== destination && $0 !== source }
        if texturesToRecycle.isEmpty == false {
            commandBuffer.addCompletedHandler { _ in
                Shared.shared.defaultTexturePool.enqueueTexturesSync(texturesToRecycle)
            }
        }
        return destination
    }

    private static func executeSequentialPipeline(filters: [C7FilterProtocol],
                                                  source: MTLTexture,
                                                  destination: MTLTexture,
                                                  commandBuffer: MTLCommandBuffer) throws -> (auxiliaryTextures: [MTLTexture], transientTextures: [MTLTexture]) {
        guard filters.isEmpty == false else {
            return ([], [])
        }
        var currentTexture = source
        var transientTextures: [MTLTexture] = []

        for (index, stageFilter) in filters.enumerated() {
            let stageIsFinalOutput = index == filters.count - 1
            let stageDestination = stageIsFinalOutput
                ? destination
                : try makeIntermediateTexture(source: currentTexture, filter: stageFilter)
            let outputTexture = try stageFilter.applyAtTexture(form: currentTexture, to: stageDestination, for: commandBuffer)
            if stageDestination !== destination && stageDestination !== source {
                transientTextures.append(stageDestination)
            }
            currentTexture = outputTexture
        }

        if currentTexture === destination {
            return ([destination], transientTextures.filter { $0 !== destination })
        }
        return ([currentTexture], transientTextures)
    }

    private static func executeParallelPipeline(filters: [C7FilterProtocol],
                                                source: MTLTexture,
                                                commandBuffer: MTLCommandBuffer) throws -> (auxiliaryTextures: [MTLTexture], transientTextures: [MTLTexture]) {
        var outputs: [MTLTexture] = []
        var transientTextures: [MTLTexture] = []
        for stageFilter in filters {
            let stageDestination = try makeIntermediateTexture(source: source, filter: stageFilter)
            let outputTexture = try stageFilter.applyAtTexture(form: source, to: stageDestination, for: commandBuffer)
            outputs.append(outputTexture)
            if stageDestination !== source {
                transientTextures.append(stageDestination)
            }
        }
        return (outputs, transientTextures)
    }

    private static func makeIntermediateTexture(source: MTLTexture, filter: C7FilterProtocol) throws -> MTLTexture {
        let inputSize = C7Size(width: source.width, height: source.height)
        let outputSize = filter.resize(input: inputSize)
        return try TextureLoader.makeTexture(width: outputSize.width, height: outputSize.height, options: [
            .texturePixelFormat: source.pixelFormat
        ], identifier: "FilterPipelineExecutor")
    }
}
