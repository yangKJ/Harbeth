//
//  FilterPipeline.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
@preconcurrency import MetalKit

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
    let computeKernelLibrarySource: KernelLibrarySource

    init(modifier: ModifierEnum, factors: [Float] = [], otherInputTextures: C7InputTextures = [], kernelParameterBindings: [KernelParameterBinding] = [], librarySource: KernelLibrarySource = .automatic) {
        self.modifier = modifier
        self.factors = factors
        self.otherInputTextures = otherInputTextures
        self.kernelParameterBindings = kernelParameterBindings
        self.computeKernelLibrarySource = librarySource
    }
}

public extension C7FilterPipelineProtocol {
    var modifier: ModifierEnum {
        makeFinalFilter(otherInputTextures: nil)?.modifier
        ?? pipelineFilters.last?.modifier
        ?? .compute(kernel: "__harbeth_invalid_pipeline__")
    }

    var factors: [Float] {
        makeFinalFilter(otherInputTextures: nil)?.factors ?? []
    }

    var kernelParameterBindings: [KernelParameterBinding] {
        makeFinalFilter(otherInputTextures: nil)?.kernelParameterBindings ?? []
    }

    var otherInputTextures: C7InputTextures { [] }

    var destinationTextureContract: FilterDestinationTextureContract {
        makeFinalFilter(otherInputTextures: nil)?.destinationTextureContract ?? .init()
    }

    var kernelOutputContract: RenderOutputContract {
        makeFinalFilter(otherInputTextures: nil)?.kernelOutputContract ?? .preserveInput
    }
}

enum FilterPipelineExecutor {
    static func apply(filter: C7FilterPipelineProtocol, source: MTLTexture, destination: MTLTexture, commandBuffer: MTLCommandBuffer) throws -> MTLTexture {
        let style = filter.pipelineExecutionStyle
        let pipelineFilters = filter.pipelineFilters
        let auxiliaryTextures: [MTLTexture]
        let transientTextures: [MTLTexture]

        switch style {
        case .sequential:
            let execution = try executeSequentialPipeline(
                filters: pipelineFilters,
                source: source,
                destination: destination,
                commandBuffer: commandBuffer
            )
            auxiliaryTextures = execution.auxiliaryTextures
            transientTextures = execution.transientTextures
        case .parallelFromSource:
            let execution = try executeParallelPipeline(
                filters: pipelineFilters,
                source: source,
                commandBuffer: commandBuffer
            )
            auxiliaryTextures = execution.auxiliaryTextures
            transientTextures = execution.transientTextures
        }

        guard let finalFilter = filter.makeFinalFilter(otherInputTextures: auxiliaryTextures) else {
            throw HarbethError.configurationInvalid("Filter pipeline must provide a final filter.")
        }
        _ = try finalFilter.apply(form: source, to: destination, for: commandBuffer, complete: nil)

        let texturesToRecycle = transientTextures.filter { $0 !== destination && $0 !== source }
        if texturesToRecycle.isEmpty == false {
            let transfer = HarbethUncheckedTransfer(value: texturesToRecycle)
            commandBuffer.addCompletedHandler { _ in
                HarbethContext.shared.texturePool.enqueueTexturesSync(transfer.value)
            }
        }
        return destination
    }

    private static func executeSequentialPipeline(
        filters: [C7FilterProtocol],
        source: MTLTexture,
        destination: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) throws -> (auxiliaryTextures: [MTLTexture], transientTextures: [MTLTexture]) {
        guard filters.isEmpty == false else { return ([], []) }
        var currentTexture = source
        var transientTextures: [MTLTexture] = []

        for stageFilter in filters {
            // Pipeline stage output must not alias the final destination. The final
            // filter consumes the last stage as an auxiliary texture while writing
            // `destination`; binding one texture for read and write is undefined.
            let stageDestination = try makeIntermediateTexture(source: currentTexture, filter: stageFilter)
            let outputTexture = try stageFilter.applyAtTexture(
                form: currentTexture,
                to: stageDestination,
                for: commandBuffer
            )
            if stageDestination !== source {
                transientTextures.append(stageDestination)
            }
            currentTexture = outputTexture
        }

        return ([currentTexture], transientTextures)
    }

    private static func executeParallelPipeline(
        filters: [C7FilterProtocol],
        source: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) throws -> (auxiliaryTextures: [MTLTexture], transientTextures: [MTLTexture]) {
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
        let usage: MTLTextureUsage
        switch filter.modifier {
        case .render:
            usage = filter.destinationTextureContract.usage.union(.renderTarget)
        case .compute, .blit, .mps, .metalCommand:
            usage = filter.destinationTextureContract.usage
        }
        let pixelFormat = filter.kernelOutputContract.primaryAttachment.pixelFormat.metalPixelFormat
            ?? source.pixelFormat
        var options: [TextureLoader.Option: Any] = [
            .texturePixelFormat: pixelFormat,
            .textureUsage: usage
        ]
        if let storageMode = filter.destinationTextureContract.storageMode {
            options[.textureStorageMode] = storageMode
        }
        return try TextureLoader.makeTexture(
            width: outputSize.width,
            height: outputSize.height,
            options: options,
            identifier: "FilterPipelineExecutor"
        )
    }
}

// 仅对没有宿主或外部同名实现的内置函数应用等价执行。
enum BuiltinKernelAdmission {
    static func isUnmodified(_ names: [String]) -> Bool {
        let runtime = HarbethContext.shared.runtimeDevice
        let libraries = runtime.externalLibraries() + [runtime.defaultLibrary].compactMap { $0 }
        return !libraries.contains { library in names.contains { library.makeFunction(name: $0) != nil } }
    }
}

// 资源ABI与恒等执行相匹配；不能跳过引导图后仍调用需要texture(2)的合成核。
struct PipelineIdentityFilter: C7FilterProtocol, BlitProtocol {
    var modifier: ModifierEnum { .blit }
    var kernelPixelContract: KernelPixelContract {
        .init(precision: .float32, dynamicRangeBehavior: .preservesExtendedRange, samplingFootprint: .point)
    }
    func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        guard textures.count >= 2 else { throw HarbethError.filterParameterInvalid("恒等执行缺少来源或目标") }
        let output = textures[0], input = textures[1]
        guard input.width == output.width, input.height == output.height else { throw HarbethError.textureSizeMismatch }
        if input === output { return output }
        if input.pixelFormat != output.pixelFormat {
            let copy = PipelineLeafFilter(modifier: .compute(kernel: "C7PixelFormatChange"), librarySource: .harbethFramework)
            return try copy.applyAtTexture(form: input, to: output, for: commandBuffer)
        }
        guard let encoder = commandBuffer.makeBlitCommandEncoder() else { throw HarbethError.makeBlitCommandEncoder }
        encoder.copy(
            from: input,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: .init(x: 0, y: 0, z: 0),
            sourceSize: .init(width: input.width, height: input.height, depth: 1),
            to: output,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: .init(x: 0, y: 0, z: 0)
        )
        encoder.endEncoding()
        return output
    }
}
