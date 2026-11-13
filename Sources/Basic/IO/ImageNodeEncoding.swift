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

extension HarbethIO where Dest == MTLTexture {
    /// 将滤镜编码到调用方缓冲区，不提交、不等待、不读回。
    /// 调用方必须提交缓冲区（后续阶段失败时也需提交已编码工作），并保留输入资源至完成。
    func encodeFrame(
        into commandBuffer: MTLCommandBuffer,
        inputColorSpace: ImageColorSpaceContract,
        workingColorSpace: ImageColorSpaceContract,
        inputColorProfile: CGColorSpace? = nil,
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
        let normalization: [C7FilterProtocol]
        if inputColorSpace == workingColorSpace {
            normalization = []
        } else if inputColorSpace.gamut == .custom || inputColorSpace.transferFunction == .custom {
            guard let inputColorProfile, let target = workingColorSpace.cgColorSpace else {
                throw HarbethError.configurationInvalid("自定义颜色输入必须提供实际ICC配置文件。")
            }
            normalization = [try MPSColorConversion(from: inputColorProfile, to: target)]
        } else {
            guard workingColorSpace.gamut != .custom, workingColorSpace.transferFunction != .custom else {
                throw HarbethError.configurationInvalid("目标颜色合同必须明确。")
            }
            normalization = workingColorSpace.makeColorConversionFilters(from: inputColorSpace)
        }
        var chain = normalization + filters
        if chain.isEmpty, let format = bufferPixelFormat, format != element.pixelFormat {
            chain = [C7Brightness(brightness: 0)]
        }
        var io = HarbethIO<MTLTexture>(element: element, filters: chain, identifier: identifier).configured(for: profile)
        io.bufferPixelFormat = bufferPixelFormat
        let program = io.makeRenderProgram(input: element)
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
        if source.requiresPlaneAwareDecoding {
            guard let strategy = TextureLoader.makeYCbCrDecodeStrategy(for: element, bridgePlan: plan) else {
                throw HarbethError.configurationInvalid("缺少输入平面解码合同。")
            }
            let filter = YCbCrPlaneDecodeFilter(
                layout: strategy.layout,
                conversionMatrix: strategy.conversionMatrix,
                conversionOffset: strategy.conversionOffset,
                planeTextures: source.planeTextures
            )
            var io = HarbethIO<MTLTexture>(element: texture, filter: filter, identifier: identifier + ".decode")
            io.bufferPixelFormat = .rgba16Float
            decoded = try io.encodeFrame(
                into: commandBuffer,
                inputColorSpace: inputColorSpace,
                workingColorSpace: inputColorSpace,
                profile: profile,
                generation: generation
            )
            texture = decoded!.texture
        }
        var io = HarbethIO<MTLTexture>(element: texture, filters: filters, identifier: identifier)
        io.bufferPixelFormat = bufferPixelFormat
        let output = try io.encodeFrame(
            into: commandBuffer,
            inputColorSpace: inputColorSpace,
            workingColorSpace: workingColorSpace,
            inputColorProfile: inputColorProfile,
            profile: profile,
            generation: generation
        )
        let retained = HarbethUncheckedTransfer(value: decoded)
        commandBuffer.addCompletedHandler { _ in withExtendedLifetime(retained.value) {} }
        guard output.lease == nil else { return output }
        // 直通结果可能在GPU完成后仍由显示宿主持有，采集缓冲不能提前归还。
        let lease = TextureLease(texture: output.texture) { withExtendedLifetime(owners.value) {} }
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
    /// 线性纹理/采集图编码入口，与上层媒体IO共用命令缓冲区。
    /// 复杂编辑、过渡及分层图继续使用makeFrameAsync；不隐式同步或位图回退。
    public func encodeFrame(
        into commandBuffer: MTLCommandBuffer,
        inputColorSpace: ImageColorSpaceContract,
        workingColorSpace: ImageColorSpaceContract,
        inputColorProfile: CGColorSpace? = nil,
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
