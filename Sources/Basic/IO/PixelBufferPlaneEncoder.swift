//
//  PixelBufferPlaneEncoder.swift
//  Harbeth
//
//  Created by Condy on 2026/11/11.
//

import CoreVideo
import Metal

/// 将已处于目标传递函数的RGB纹理写入独立的双平面像素缓冲区。
enum PixelBufferPlaneEncoder {
    static func supports(_ format: OSType) -> Bool {
        [kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
         kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr10BiPlanarFullRange].contains(format)
    }

    static func encode(texture: MTLTexture, into buffer: CVPixelBuffer, colorSpace: ImageColorSpaceContract) throws {
        let format = CVPixelBufferGetPixelFormatType(buffer)
        guard supports(format), texture.device === HarbethContext.shared.device,
              texture.width == CVPixelBufferGetWidth(buffer), texture.height == CVPixelBufferGetHeight(buffer),
              colorSpace.gamut == .ituR2020 || colorSpace.gamut == .sRGB || colorSpace.gamut == .displayP3 else {
            throw HarbethError.configurationInvalid("双平面输出需要同尺寸纹理和明确的RGB色彩合同。")
        }
        let planes = buffer.c7.createPlaneTextureReferences()
        guard planes.count == 2 else { throw HarbethError.configurationInvalid("无法建立可写的双平面纹理。") }
        let tenBit = format == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange || format == kCVPixelFormatType_420YpCbCr10BiPlanarFullRange
        let fullRange = format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange || format == kCVPixelFormatType_420YpCbCr10BiPlanarFullRange
        struct Parameters {
            var coefficients: SIMD2<Float>
            var tenBit: UInt32
            var fullRange: UInt32
        }
        var parameters = Parameters(
            coefficients: colorSpace.gamut == .ituR2020 ? SIMD2(0.2627, 0.0593) : SIMD2(0.2126, 0.0722),
            tenBit: tenBit ? 1 : 0,
            fullRange: fullRange ? 1 : 0
        )
        let pipeline = try Compute.makeComputePipelineState(with: "HarbethRGBToBiPlanar420")
        guard let command = HarbethContext.shared.makeCommandBuffer(),
              let encoder = command.makeComputeCommandEncoder() else {
            throw HarbethError.makeComputeCommandEncoder
        }
        defer { HarbethContext.shared.recycleCommandBuffer(command) }
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setTexture(planes[0].texture, index: 1)
        encoder.setTexture(planes[1].texture, index: 2)
        encoder.setBytes(&parameters, length: MemoryLayout<Parameters>.stride, index: 0)
        let width = pipeline.threadExecutionWidth
        let height = max(1, pipeline.maxTotalThreadsPerThreadgroup / width)
        encoder.dispatchThreads(
            MTLSize(width: texture.width, height: texture.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: width, height: height, depth: 1)
        )
        encoder.endEncoding()
        // CVMetalTexture与原缓冲必须一起活到GPU完成，不能只保留提取出的MTLTexture。
        try withExtendedLifetime((planes, buffer)) {
            try command.commitAndWaitUntilCompleted(identifier: "HarbethRGBToBiPlanar420")
        }
        buffer.c7.setColorSpaceAttachments(colorSpace)
        CVBufferSetAttachment(buffer, kCVImageBufferChromaLocationTopFieldKey, kCVImageBufferChromaLocation_Center, .shouldPropagate)
        CVBufferSetAttachment(
            buffer, kCVImageBufferYCbCrMatrixKey,
            colorSpace.gamut == .ituR2020 ? kCVImageBufferYCbCrMatrix_ITU_R_2020 : kCVImageBufferYCbCrMatrix_ITU_R_709_2,
            .shouldPropagate
        )
    }
}

public extension RenderedFrame {
    /// 在交付边界物化独立像素缓冲区；色彩变换和双平面打包均在GPU执行。
    /// 双平面格式不保留alpha，调用方必须明确允许舍弃或提供不透明帧。
    func makePixelBuffer(
        pixelFormatType: OSType = kCVPixelFormatType_64RGBAHalf,
        outputColorSpace: ImageColorSpaceContract? = nil,
        allowsAlphaDiscard: Bool = false
    ) throws -> CVPixelBuffer {
        defer { withExtendedLifetime(self) {} }
        guard texture.device === HarbethContext.shared.device else {
            throw HarbethError.configurationInvalid("像素缓冲区物化需要共享渲染设备，不能隐式跨GPU复制。")
        }
        let target = outputColorSpace ?? outputColorSpaceContract
        var source = outputColorSpaceContract
        if texture.pixelFormat == .rgba8Unorm_srgb || texture.pixelFormat == .bgra8Unorm_srgb {
            source = ImageColorSpaceContract(name: "hardwareLinear", preservesInput: false, gamut: source.gamut, transferFunction: .linear)
        }
        guard !source.preservesInput, !target.preservesInput,
              source.gamut != .custom, target.gamut != .custom,
              source.transferFunction != .custom, target.transferFunction != .custom else {
            throw HarbethError.configurationInvalid("像素缓冲区输出需要明确且受支持的源与目标色彩空间。")
        }
        let planar = PixelBufferPlaneEncoder.supports(pixelFormatType)
        guard !planar || alphaType == .alphaIsOne || allowsAlphaDiscard else {
            throw HarbethError.configurationInvalid("双平面输出不能隐式丢弃alpha。")
        }
        let targetPixelFormat: MTLPixelFormat
        switch pixelFormatType {
        case kCVPixelFormatType_64RGBAHalf: targetPixelFormat = .rgba16Float
        case kCVPixelFormatType_32BGRA: targetPixelFormat = .bgra8Unorm
        case kCVPixelFormatType_32RGBA: targetPixelFormat = .rgba8Unorm
        default:
            guard planar else { throw HarbethError.configurationInvalid("不支持的像素缓冲区输出格式。") }
            targetPixelFormat = .rgba16Float
        }
        guard let sourceSpace = source.cgColorSpace, let targetSpace = target.cgColorSpace else {
            throw HarbethError.configurationInvalid("源与目标色彩合同必须解析为实际RGB配置文件。")
        }
        let normalized = RenderedFrame(texture: texture, colorSpace: sourceSpace, outputColorSpaceContract: source,
            alphaType: alphaType, profile: profile, token: token, lease: lease)
        // 复用已有GPU ICC入口，使HLG/PQ的参考标度与平台颜色管理保持一致。
        let colorFrame = source == target ? normalized : try normalized.converted(to: targetSpace)
        var filters: [C7FilterProtocol] = []
        if planar, colorFrame.alphaType == .premultiplied { filters.append(C7UnpremultiplyAlpha()) }
        if filters.isEmpty, colorFrame.texture.pixelFormat != targetPixelFormat { filters.append(C7Brightness(brightness: 0)) }
        var io = HarbethIO(element: colorFrame.texture, filters: filters)
        io.bufferPixelFormat = targetPixelFormat
        let converted = filters.isEmpty ? colorFrame.texture : try io.output()
        defer { withExtendedLifetime(colorFrame) {} }
        let acquisition = try PixelBufferPool.acquire(for: RenderPixelBufferDescriptor(
            width: converted.width, height: converted.height,
            pixelFormatType: pixelFormatType,
            cgImageCompatible: !planar, bitmapContextCompatible: !planar
        ), realtime: true)
        let buffer = acquisition.buffer
        if planar {
            try PixelBufferPlaneEncoder.encode(texture: converted, into: buffer, colorSpace: target)
        } else {
            guard buffer.c7.copyToPixelBuffer(with: converted) else { throw HarbethError.pixelBufferCopyFailed }
            buffer.c7.setColorSpaceAttachments(target)
        }
        return buffer
    }
}
