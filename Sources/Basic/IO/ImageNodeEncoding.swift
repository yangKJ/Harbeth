//
//  ImageNodeEncoding.swift
//  Harbeth
//
//  Created by Condy on 2026/11/13.
//

import CoreGraphics
import CoreVideo
import Foundation
import Metal

/// 单个执行器拥有的有界编译缓存；不保存帧像素，换源后仍重新绑定实际纹理。
public final class ImageNodeEncodingContext: @unchecked Sendable {
    private let lock = NSLock()
    private var caches: [String: RenderExecutionProgramCache] = [:]
    private var order: [String] = []
    private var hits = 0
    private var misses = 0

    public init() {}

    public var statistics: (entries: Int, hits: Int, misses: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (caches.count, hits, misses)
    }

    public func removeAll() {
        lock.lock()
        caches.removeAll()
        order.removeAll()
        lock.unlock()
    }

    func cache(for identifier: String) -> RenderExecutionProgramCache {
        lock.lock()
        defer { lock.unlock() }
        if let cache = caches[identifier] { return cache }
        if order.count == 8 { caches.removeValue(forKey: order.removeFirst()) }
        let cache = RenderExecutionProgramCache()
        caches[identifier] = cache
        order.append(identifier)
        return cache
    }

    func record(reused: Bool) {
        lock.lock()
        if reused { hits += 1 } else { misses += 1 }
        lock.unlock()
    }
}

extension HarbethIO where Dest == MTLTexture {
    /// 将滤镜编码到调用方缓冲区，不提交、不等待、不读回。
    /// 调用方必须提交缓冲区（后续阶段失败时也需提交已编码工作），并保留输入资源至完成。
    func encodeFrame(
        into commandBuffer: MTLCommandBuffer,
        inputColorSpace: ImageColorSpaceContract,
        workingColorSpace: ImageColorSpaceContract,
        inputColorProfile: CGColorSpace? = nil,
        context: ImageNodeEncodingContext? = nil,
        profile: RenderProfile = .stablePreview,
        generation: UInt64 = 0,
        alphaType: AlphaType = .alphaIsOne
    ) throws -> RenderedFrame {
        guard commandBuffer.status == .notEnqueued,
              commandBuffer.device === element.device,
              element.device === HarbethContext.shared.device,
              !inputColorSpace.preservesInput, !workingColorSpace.preservesInput else {
            throw HarbethError.configurationInvalid("纹理编码需要未提交缓冲区、同一设备及明确颜色合同。")
        }
        var sampledColorSpace: ImageColorSpaceContract
        var samplingRecovery: [C7FilterProtocol] = []
        if element.pixelFormat == .rgba8Unorm_srgb || element.pixelFormat == .bgra8Unorm_srgb {
            guard inputColorSpace.gamut != .custom, !inputColorSpace.isHDRTransfer else {
                throw HarbethError.configurationInvalid("硬件sRGB采样不能用于未知ICC或HDR传递函数。")
            }
            sampledColorSpace = ImageColorSpaceContract(name: "hardwareLinear", preservesInput: false,
                gamut: inputColorSpace.gamut, transferFunction: .linear)
            if alphaType == .premultiplied {
                guard inputColorSpace.transferFunction == .sRGB,
                      let restore = C7RGBTransferConversion(from: sampledColorSpace, to: inputColorSpace) else {
                    throw HarbethError.configurationInvalid("硬件sRGB的预乘输入需要明确的sRGB编码域。")
                }
                // 硬件先解码了预乘通道；先还原存储域，再进行alpha安全的颜色转换。
                samplingRecovery = [restore]
                sampledColorSpace = inputColorSpace
            }
        } else {
            sampledColorSpace = inputColorSpace
        }
        let normalization: [C7FilterProtocol]
        if sampledColorSpace == workingColorSpace {
            normalization = []
        } else if sampledColorSpace.gamut == .custom || sampledColorSpace.transferFunction == .custom {
            guard let inputColorProfile, let target = workingColorSpace.cgColorSpace else {
                throw HarbethError.configurationInvalid("自定义颜色输入必须提供实际ICC配置文件。")
            }
            normalization = [try MPSColorConversion(from: inputColorProfile, to: target, alphaType: alphaType)]
        } else {
            guard workingColorSpace.gamut != .custom, workingColorSpace.transferFunction != .custom else {
                throw HarbethError.configurationInvalid("目标颜色合同必须明确。")
            }
            let conversion = workingColorSpace.makeColorConversionFilters(from: sampledColorSpace)
            // 非线性传递函数必须作用于直通RGB，不能把覆盖率当作色值参与转换。
            normalization = alphaType == .premultiplied && !conversion.isEmpty
                ? [C7UnpremultiplyAlpha()] + conversion + [C7PremultiplyAlpha()]
                : conversion
        }
        var chain = samplingRecovery + normalization + filters
        if chain.isEmpty, let format = bufferPixelFormat, format != element.pixelFormat {
            chain = [C7Brightness(brightness: 0)]
        }
        var io = HarbethIO<MTLTexture>(element: element, filters: chain, identifier: identifier).configured(for: profile)
        io.bufferPixelFormat = bufferPixelFormat
        // 外部纹理可能来自采集池或临时图层，编译缓存不能延长这些帧的驻留时间。
        if chain.allSatisfy({ $0.otherInputTextures.isEmpty }) {
            io.executionProgramCache = context?.cache(for: identifier)
        }
        let program = io.makeRenderProgram(input: element)
        context?.record(reused: program.reusedCachedPlan)
        let encoded = try io.encodeManagedRenderProgram(program, commandBuffer: commandBuffer)
        encoded.retainUntilCompleted(by: commandBuffer)
        commandBuffer.addCompletedHandler { _ in encoded.releaseIntermediates() }
        return RenderedFrame(
            texture: encoded.result.texture,
            colorSpace: workingColorSpace.cgColorSpace ?? inputColorProfile,
            outputColorSpaceContract: workingColorSpace,
            alphaType: alphaType,
            profile: profile,
            generation: generation,
            identifier: identifier,
            lease: encoded.result.lease
        )
    }
}

extension HarbethIO where Dest == CVPixelBuffer {
    /// 仅接受可直接映射的缓冲区；平面解码与后续滤镜共用一次提交。
    func encodeFrame(
        into commandBuffer: MTLCommandBuffer,
        inputColorSpace: ImageColorSpaceContract,
        workingColorSpace: ImageColorSpaceContract,
        inputColorProfile: CGColorSpace? = nil,
        context: ImageNodeEncodingContext? = nil,
        profile: RenderProfile = .stablePreview,
        generation: UInt64 = 0
    ) throws -> RenderedFrame {
        let plan = element.c7.makeTextureBridgePlan()
        guard plan.loadStrategy == .directMetalTexture || plan.loadStrategy == .directPlaneTexture else {
            throw HarbethError.configurationInvalid("实时输入不允许位图或CPU复制回退。")
        }
        let source = try TextureLoader.resolveGPUTextureSource(with: element)
        guard source.exposesAllDirectPlaneTextures || plan.loadStrategy == .directMetalTexture else {
            throw HarbethError.configurationInvalid("实时输入无法映射全部平面。")
        }
        let owners = HarbethUncheckedTransfer(value: source.retainedOwners)
        let borrowed = TextureLease(texture: source.primaryTexture) { withExtendedLifetime(owners.value) {} }
        borrowed.retainUntilCompleted(by: commandBuffer)
        commandBuffer.addCompletedHandler { _ in borrowed.release() }
        var texture = source.primaryTexture
        var decoded: RenderedFrame?
        var remaining = filters
        if source.requiresPlaneAwareDecoding {
            guard let strategy = TextureLoader.makeYCbCrDecodeStrategy(for: element, bridgePlan: plan) else {
                throw HarbethError.configurationInvalid("缺少输入平面解码合同。")
            }
            // 仅合并同一颜色域的首级缩小几何；保持原先逐像素解码、夹紧后线性采样的顺序。
            let geometry = remaining.first as? C7TextureGeometry
            let fusesGeometry = inputColorSpace == workingColorSpace
                && geometry.map { $0.width * $0.height < texture.width * texture.height } == true
            var filter = YCbCrPlaneDecodeFilter(
                layout: strategy.layout,
                conversionMatrix: strategy.conversionMatrix,
                conversionOffset: strategy.conversionOffset,
                planeTextures: source.planeTextures
            )
            if fusesGeometry {
                filter.geometry = geometry
                remaining.removeFirst()
            }
            var io = HarbethIO<MTLTexture>(element: texture, filter: filter, identifier: identifier + ".decode")
            io.bufferPixelFormat = .rgba16Float
            decoded = try io.encodeFrame(
                into: commandBuffer,
                inputColorSpace: inputColorSpace,
                workingColorSpace: inputColorSpace,
                context: context,
                profile: profile,
                generation: generation
            )
            texture = decoded!.texture
        }
        var io = HarbethIO<MTLTexture>(element: texture, filters: remaining, identifier: identifier)
        io.bufferPixelFormat = bufferPixelFormat
        let output = try io.encodeFrame(
            into: commandBuffer,
            inputColorSpace: inputColorSpace,
            workingColorSpace: workingColorSpace,
            inputColorProfile: inputColorProfile,
            context: context,
            profile: profile,
            generation: generation
        )
        let retained = HarbethUncheckedTransfer(value: decoded)
        commandBuffer.addCompletedHandler { _ in withExtendedLifetime(retained.value) {} }
        guard output.lease == nil else { return output }
        // 直通结果可能在GPU完成后仍由显示宿主持有，采集缓冲不能提前归还。
        // 解码融合后可能直接返回解码纹理，显示帧必须继续持有其池租约。
        let lease = TextureLease(texture: output.texture) { withExtendedLifetime((owners.value, retained.value)) {} }
        return RenderedFrame(
            texture: output.texture,
            colorSpace: output.colorSpace,
            outputColorSpaceContract: output.outputColorSpaceContract,
            alphaType: .alphaIsOne,
            profile: profile,
            token: output.token,
            lease: lease
        )
    }
}

extension ImageNode {
    /// 纹理、采集与分层合成图编码入口，与上层媒体IO共用命令缓冲区。
    /// 未物化蒙版与复杂编辑使用makeFrameAsync；不隐式同步或位图回退。
    public func encodeFrame(
        into commandBuffer: MTLCommandBuffer,
        inputColorSpace: ImageColorSpaceContract,
        workingColorSpace: ImageColorSpaceContract,
        inputColorProfile: CGColorSpace? = nil,
        context: ImageNodeEncodingContext? = nil,
        pixelFormat: MTLPixelFormat = .rgba16Float,
        profile: RenderProfile = .stablePreview,
        identifier: String = "ImageNode.EncodedFrame",
        generation: UInt64 = 0,
        alphaType: AlphaType = .alphaIsOne
    ) throws -> RenderedFrame {
        var sourceNode = self
        var chain: [C7FilterProtocol] = []
        while case .filters(let input, let filters) = sourceNode.storage {
            chain = filters + chain
            sourceNode = input
        }
        if case .layerComposite(let recipe) = sourceNode.storage {
            guard recipe.outputContract == .preserveInput else {
                throw HarbethError.configurationInvalid("相机分层图的输出合同由编码入口统一指定。")
            }
            var current = try ImageNode.source(recipe.background).encodeFrame(
                into: commandBuffer, inputColorSpace: inputColorSpace, workingColorSpace: workingColorSpace,
                inputColorProfile: inputColorProfile, context: context, pixelFormat: pixelFormat,
                profile: profile, identifier: identifier + ".background", generation: generation, alphaType: alphaType)
            for (index, layer) in recipe.layers.enumerated() {
                guard layer.layoutUnit == .normalized, layer.maskSource == nil,
                      layer.compositingMaskSource == nil, layer.programmableBlend == nil,
                      layer.rasterSampleCount == 1 else {
                    throw HarbethError.configurationInvalid("外部编码接受已物化遮罩与标准纹理图层。")
                }
                var transform = layer.transform
                transform.rotationDegrees += layer.rotation
                if layer.flipOptions.horizontal { transform.mirrorsHorizontally.toggle() }
                if layer.flipOptions.vertical { transform.flipsVertically.toggle() }
                guard case .texture(let texture) = layer.content else {
                    throw HarbethError.configurationInvalid("图层输入必须先准备为纹理。")
                }
                let filters = transform.makeFilters(inputSize: C7Size(texture: texture)) + layer.filters
                let prepared = try ImageNode.texture(texture).applying(filters: filters).encodeFrame(
                    into: commandBuffer, inputColorSpace: inputColorSpace, workingColorSpace: workingColorSpace,
                    inputColorProfile: inputColorProfile, context: context, pixelFormat: pixelFormat,
                    profile: profile, identifier: identifier + ".layer.\(index)", generation: generation,
                    alphaType: .premultiplied)
                let composite = LayerComposite(layerTexture: prepared.texture, mask: layer.mask,
                    compositingMask: layer.compositingMask, normalizedFrame: layer.normalizedFrame,
                    contentRegion: layer.contentRegion, opacity: layer.opacity, blendMode: layer.blendMode,
                    cornerRadius: layer.cornerRadius, cornerCurve: layer.cornerCurve, tintColor: layer.tintColor)
                let previous = current
                current = try ImageNode.texture(previous.texture).applying(composite).encodeFrame(
                    into: commandBuffer, inputColorSpace: workingColorSpace, workingColorSpace: workingColorSpace,
                    context: context, pixelFormat: pixelFormat, profile: profile,
                    identifier: identifier + ".composite.\(index)", generation: generation, alphaType: .premultiplied)
                commandBuffer.addCompletedHandler { _ in withExtendedLifetime((previous, prepared)) {} }
            }
            let target = recipe.derivative.resolvedOutputSize(for: C7Size(texture: current.texture))
            if target != C7Size(texture: current.texture) {
                chain.append(C7Resize(width: Float(target.width), height: Float(target.height)))
            }
            if chain.isEmpty { return current }
            let previous = current
            let output = try ImageNode.texture(previous.texture).applying(filters: chain).encodeFrame(
                into: commandBuffer, inputColorSpace: workingColorSpace, workingColorSpace: workingColorSpace,
                context: context, pixelFormat: pixelFormat, profile: profile, identifier: identifier + ".finish",
                generation: generation, alphaType: .premultiplied)
            commandBuffer.addCompletedHandler { _ in withExtendedLifetime(previous) {} }
            return output
        }
        guard case .source(let source) = sourceNode.storage else {
            throw HarbethError.configurationInvalid("外部命令编码仅接受线性图；复杂图使用异步图执行入口。")
        }
        switch source {
        case .texture(let texture):
            var io = HarbethIO<MTLTexture>(element: texture, filters: chain, identifier: identifier)
            io.bufferPixelFormat = pixelFormat
            return try io.encodeFrame(
                into: commandBuffer,
                inputColorSpace: inputColorSpace,
                workingColorSpace: workingColorSpace,
                inputColorProfile: inputColorProfile,
                context: context,
                profile: profile,
                generation: generation,
                alphaType: alphaType
            )
        case .pixelBuffer(let buffer):
            var io = HarbethIO<CVPixelBuffer>(element: buffer, filters: chain, identifier: identifier)
            io.bufferPixelFormat = pixelFormat
            return try io.encodeFrame(
                into: commandBuffer,
                inputColorSpace: inputColorSpace,
                workingColorSpace: workingColorSpace,
                inputColorProfile: inputColorProfile,
                context: context,
                profile: profile,
                generation: generation
            )
        default:
            throw HarbethError.configurationInvalid("外部命令编码需要已准备的纹理或PixelBuffer输入。")
        }
    }
}


extension TextureLoader {
    /// 严格GPU映射，不能因平面映射失败而转成CGImage或CPU复制。
    public static func resolveGPUTextureSource(with buffer: CVPixelBuffer) throws -> PixelBufferTextureSource {
        let plan = buffer.c7.makeTextureBridgePlan()
        guard plan.loadStrategy == .directMetalTexture || plan.loadStrategy == .directPlaneTexture,
              let cache = HarbethContext.shared.cvMetalTextureCache else {
            throw HarbethError.configurationInvalid("输入不能直接映射GPU纹理。")
        }
        let planar = CVPixelBufferIsPlanar(buffer)
        let count = planar ? CVPixelBufferGetPlaneCount(buffer) : 1
        var textures: [MTLTexture] = []
        var owners: [AnyObject] = [buffer]
        for index in 0..<count {
            let format = planar ? plan.contract.planes[index].metalPixelFormat : plan.contract.preferredMetalPixelFormat
            guard let format else { throw HarbethError.source2Texture }
            let width = planar ? CVPixelBufferGetWidthOfPlane(buffer, index) : CVPixelBufferGetWidth(buffer)
            let height = planar ? CVPixelBufferGetHeightOfPlane(buffer, index) : CVPixelBufferGetHeight(buffer)
            var reference: CVMetalTexture?
            guard CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, cache, buffer, nil,
                format, width, height, index, &reference) == kCVReturnSuccess,
                  let reference, let texture = CVMetalTextureGetTexture(reference) else {
                throw HarbethError.source2Texture
            }
            textures.append(texture)
            owners.append(reference)
        }
        guard let primary = textures.first else { throw HarbethError.source2Texture }
        return PixelBufferTextureSource(primaryTexture: primary, planeTextures: textures,
            bridgePlan: plan, retainedOwners: owners)
    }
}
