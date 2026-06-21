//
//  CVPixelBuffer+Ext.swift
//  Harbeth
//
//  Created by Condy on 2022/2/28.
//

import Foundation
import CoreVideo
import MetalKit
import VideoToolbox

extension CVPixelBuffer: HarbethCompatible { }

extension HarbethWrapper where Base: CVPixelBuffer {

    public var contract: PixelBufferContract {
        let pixelFormatType = CVPixelBufferGetPixelFormatType(base)
        let isPlanar = CVPixelBufferIsPlanar(base)
        let actualPlaneCount = isPlanar ? CVPixelBufferGetPlaneCount(base) : 1
        let colorModel = Self.colorModel(for: pixelFormatType, planeCount: actualPlaneCount)
        let nativeTextureLayout: PixelBufferNativeTextureLayout
        switch colorModel {
        case .rgba, .monochrome:
            nativeTextureLayout = .directSingleTexture
        case .yCbCrBiPlanar, .yCbCrTriPlanar:
            nativeTextureLayout = .planeTextures
        case .unknown:
            nativeTextureLayout = .unsupported
        }
        let planes = (0..<actualPlaneCount).map { planeIndex in
            PixelBufferPlaneContract(
                index: planeIndex,
                width: Self.width(of: base, planeIndex: planeIndex, planar: isPlanar),
                height: Self.height(of: base, planeIndex: planeIndex, planar: isPlanar),
                bytesPerRow: Self.bytesPerRow(of: base, planeIndex: planeIndex, planar: isPlanar),
                cvPixelFormatType: pixelFormatType,
                metalPixelFormat: Self.preferredMetalPixelFormat(
                    for: pixelFormatType,
                    planeIndex: planeIndex,
                    planar: isPlanar
                )
            )
        }
        return PixelBufferContract(
            width: CVPixelBufferGetWidth(base),
            height: CVPixelBufferGetHeight(base),
            cvPixelFormatType: pixelFormatType,
            planeCount: actualPlaneCount,
            planar: isPlanar,
            colorModel: colorModel,
            nativeTextureLayout: nativeTextureLayout,
            yCbCrMatrixAttachment: Self.yCbCrMatrixAttachment(for: base),
            colorPrimariesAttachment: Self.colorPrimariesAttachment(for: base),
            transferFunctionAttachment: Self.transferFunctionAttachment(for: base),
            planes: planes
        )
    }

    public func makeTextureBridgePlan() -> PixelBufferTextureBridgePlan {
        let contract = contract
        switch contract.nativeTextureLayout {
        case .directSingleTexture:
            return PixelBufferTextureBridgePlan(
                contract: contract,
                loadStrategy: .directMetalTexture,
                preservesOwnerReference: true,
                planes: contract.planes.map {
                    PixelBufferPlaneBridgeDescriptor(
                        index: $0.index,
                        metalPixelFormat: $0.metalPixelFormat,
                        conversionStrategy: .directMetalTexture,
                        preservesOwnerReference: true
                    )
                }
            )
        case .planeTextures:
            return PixelBufferTextureBridgePlan(
                contract: contract,
                loadStrategy: .directPlaneTexture,
                preservesOwnerReference: true,
                planes: contract.planes.map {
                    PixelBufferPlaneBridgeDescriptor(
                        index: $0.index,
                        metalPixelFormat: $0.metalPixelFormat,
                        conversionStrategy: $0.metalPixelFormat == nil ? .cpuCopyFallback : .directMetalTexture,
                        preservesOwnerReference: $0.metalPixelFormat != nil
                    )
                }
            )
        case .unsupported:
            return PixelBufferTextureBridgePlan(
                contract: contract,
                loadStrategy: .cpuCopyFallback,
                preservesOwnerReference: false,
                planes: contract.planes.map {
                    PixelBufferPlaneBridgeDescriptor(
                        index: $0.index,
                        metalPixelFormat: $0.metalPixelFormat,
                        conversionStrategy: .cpuCopyFallback,
                        preservesOwnerReference: false
                    )
                }
            )
        }
    }
    
    /// Width of the pixel buffer
    public var width: Int {
        CVPixelBufferGetWidth(base)
    }
    
    /// Height of the pixel buffer
    public var height: Int {
        CVPixelBufferGetHeight(base)
    }
    
    /// Calculated size based on plane 0
    private var size: C7Size {
        let width = CVPixelBufferGetWidthOfPlane(self.base, 0)
        let height = CVPixelBufferGetHeightOfPlane(self.base, 0)
        return C7Size(width: width, height: height)
    }
    
    /// Converts pixel buffer to Metal texture
    /// - Parameters:
    ///   - textureCache: The texture cache object that will manage the texture.
    ///   - pixelFormat: Specifies the Metal pixel format.
    ///   - planeIndex: Specifies the plane of the CVImageBuffer to map bind.  Ignored for non-planar CVImageBuffers.
    /// - Returns: Metal texture.
    public func convert2MTLTexture(textureCache: CVMetalTextureCache?,
                                   pixelFormat: MTLPixelFormat = .bgra8Unorm,
                                   planeIndex: Int = 0) -> MTLTexture? {
        guard let textureCache = textureCache else {
            return nil
        }
        #if !targetEnvironment(simulator)
        var cvmTexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                  textureCache,
                                                  self.base,
                                                  nil,
                                                  pixelFormat,
                                                  CVPixelBufferGetWidthOfPlane(base, planeIndex),
                                                  CVPixelBufferGetHeightOfPlane(base, planeIndex),
                                                  planeIndex,
                                                  &cvmTexture)
        if let cvmTexture = cvmTexture, let texture = CVMetalTextureGetTexture(cvmTexture) {
            TextureOwnerRegistry.attach([base, cvmTexture], to: texture)
            return texture
        }
        #endif
        return nil
    }

    public func createPlaneTextures(textureCache: CVMetalTextureCache? = nil) -> [MTLTexture] {
        let plan = makeTextureBridgePlan()
        guard plan.contract.nativeTextureLayout == .planeTextures else {
            return []
        }
        let cache = textureCache ?? Shared.shared.sharedTextureCache
        return plan.contract.planes.compactMap { plane in
            guard let pixelFormat = plane.metalPixelFormat else {
                return nil
            }
            return convert2MTLTexture(
                textureCache: cache,
                pixelFormat: pixelFormat,
                planeIndex: plane.index
            )
        }
    }

    private static func yCbCrMatrixAttachment(for pixelBuffer: CVPixelBuffer) -> YCbCrMatrixAttachment? {
        guard let attachment = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, nil)?.takeUnretainedValue() else {
            return nil
        }
        if CFEqual(attachment, kCVImageBufferYCbCrMatrix_ITU_R_709_2) {
            return .ituR709_2
        }
        if CFEqual(attachment, kCVImageBufferYCbCrMatrix_ITU_R_601_4) {
            return .ituR601_4
        }
        if CFEqual(attachment, kCVImageBufferYCbCrMatrix_SMPTE_240M_1995) {
            return .smpte240M_1995
        }
        if #available(iOS 14.0, macOS 11.0, tvOS 14.0, *) {
            if CFEqual(attachment, kCVImageBufferYCbCrMatrix_ITU_R_2020) {
                return .ituR2020
            }
        }
        return nil
    }

    private static func colorPrimariesAttachment(for pixelBuffer: CVPixelBuffer) -> ColorPrimariesAttachment? {
        guard let attachment = CVBufferGetAttachment(pixelBuffer, kCVImageBufferColorPrimariesKey, nil)?.takeUnretainedValue() else {
            return nil
        }
        if CFEqual(attachment, kCVImageBufferColorPrimaries_ITU_R_709_2) {
            return .ituR709_2
        }
        if CFEqual(attachment, kCVImageBufferColorPrimaries_EBU_3213) {
            return .ebu3213
        }
        if CFEqual(attachment, kCVImageBufferColorPrimaries_SMPTE_C) {
            return .smpteC
        }
        if CFEqual(attachment, kCVImageBufferColorPrimaries_P3_D65) {
            return .p3D65
        }
        if #available(iOS 14.0, macOS 11.0, tvOS 14.0, *) {
            if CFEqual(attachment, kCVImageBufferColorPrimaries_ITU_R_2020) {
                return .ituR2020
            }
        }
        return nil
    }

    private static func cvColorPrimariesValue(for primaries: ColorPrimariesAttachment) -> CFString? {
        switch primaries {
        case .ituR709_2:
            return kCVImageBufferColorPrimaries_ITU_R_709_2
        case .ebu3213:
            return kCVImageBufferColorPrimaries_EBU_3213
        case .smpteC:
            return kCVImageBufferColorPrimaries_SMPTE_C
        case .p3D65:
            return kCVImageBufferColorPrimaries_P3_D65
        case .ituR2020:
            if #available(iOS 14.0, macOS 11.0, tvOS 14.0, *) {
                return kCVImageBufferColorPrimaries_ITU_R_2020
            }
            return nil
        }
    }

    private static func cvColorPrimariesValue(for gamut: ImageColorGamut) -> CFString? {
        switch gamut {
        case .sRGB, .extendedLinearSRGB:
            return kCVImageBufferColorPrimaries_ITU_R_709_2
        case .displayP3:
            return kCVImageBufferColorPrimaries_P3_D65
        case .ituR2020:
            if #available(iOS 14.0, macOS 11.0, tvOS 14.0, *) {
                return kCVImageBufferColorPrimaries_ITU_R_2020
            }
            return nil
        case .preserveInput, .custom:
            return nil
        }
    }

    private static func transferFunctionAttachment(for pixelBuffer: CVPixelBuffer) -> ColorTransferAttachment? {
        guard let attachment = CVBufferGetAttachment(pixelBuffer, kCVImageBufferTransferFunctionKey, nil)?.takeUnretainedValue() else {
            return nil
        }
        if CFEqual(attachment, kCVImageBufferTransferFunction_ITU_R_709_2) {
            return .ituR709_2
        }
        if CFEqual(attachment, kCVImageBufferTransferFunction_UseGamma) {
            return .useGamma
        }
        if CFEqual(attachment, kCVImageBufferTransferFunction_sRGB) {
            return .sRGB
        }
        if #available(iOS 12.0, macOS 10.14, tvOS 12.0, *) {
            if CFEqual(attachment, kCVImageBufferTransferFunction_Linear) {
                return .linear
            }
        }
        if #available(iOS 14.0, macOS 11.0, tvOS 14.0, *) {
            if CFEqual(attachment, kCVImageBufferTransferFunction_ITU_R_2100_HLG) {
                return .ituR2100HLG
            }
            if CFEqual(attachment, kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ) {
                return .smpteSt2084PQ
            }
        }
        return nil
    }

    private static func cvTransferFunctionValue(for transferFunction: ImageTransferFunction) -> CFString? {
        switch transferFunction {
        case .sRGB:
            return kCVImageBufferTransferFunction_sRGB
        case .linear:
            if #available(iOS 13.0, macOS 10.15, tvOS 13.0, *) {
                return kCVImageBufferTransferFunction_Linear
            }
            return nil
        case .perceptualQuantizer:
            if #available(iOS 14.0, macOS 11.0, tvOS 14.0, *) {
                return kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ
            }
            return nil
        case .hybridLogGamma:
            if #available(iOS 14.0, macOS 11.0, tvOS 14.0, *) {
                return kCVImageBufferTransferFunction_ITU_R_2100_HLG
            }
            return nil
        case .preserveInput, .custom:
            return nil
        }
    }
    
    /// Creates CGImage from pixel buffer
    /// - Returns: CGImage or nil
    public func toCGImage() -> CGImage? {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(base, options: nil, imageOut: &cgImage)
        return cgImage
    }
    
    /// Copies texture data to pixel buffer
    /// - Parameter texture: Source Metal texture
    @discardableResult
    public func copyToPixelBuffer(with texture: MTLTexture) -> Bool {
        guard textureCopyCompatibilityError(for: texture) == nil else {
            return false
        }
        guard lockBaseAddress([]) == kCVReturnSuccess else {
            return false
        }
        defer { unlockBaseAddress([]) }
        guard let pixelBufferBytes = CVPixelBufferGetBaseAddress(base) else {
            return false
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(base)
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        texture.getBytes(pixelBufferBytes, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        return true
    }

    public func canCopyTextureData(from texture: MTLTexture) -> Bool {
        textureCopyCompatibilityError(for: texture) == nil
    }

    public func copyAttachments(from imageBuffer: CVImageBuffer) {
        let sourceContract = imageBuffer.c7.contract
        if contract.requiresYCbCrConversion {
            copyAttachment(kCVImageBufferYCbCrMatrixKey, from: imageBuffer)
        }
        copyAttachment(kCVImageBufferColorPrimariesKey, from: imageBuffer)
        if sourceContract.colorPrimariesAttachment == nil,
           let fallbackPrimaries = sourceContract.yCbCrMatrixAttachment?.fallbackColorPrimariesAttachment {
            setColorPrimariesAttachmentIfMissing(fallbackPrimaries)
        }
        copyAttachment(kCVImageBufferTransferFunctionKey, from: imageBuffer)
    }

    public func copyAttachment(_ key: CFString, from imageBuffer: CVImageBuffer) {
        var attachmentMode = CVAttachmentMode.shouldPropagate
        guard let attachment = CVBufferGetAttachment(imageBuffer, key, &attachmentMode) else {
            return
        }
        CVBufferSetAttachment(base, key, attachment.takeUnretainedValue(), attachmentMode)
    }

    public func setColorPrimariesAttachmentIfMissing(_ primaries: ColorPrimariesAttachment) {
        guard CVBufferGetAttachment(base, kCVImageBufferColorPrimariesKey, nil) == nil else {
            return
        }
        guard let value = Self.cvColorPrimariesValue(for: primaries) else {
            return
        }
        CVBufferSetAttachment(base, kCVImageBufferColorPrimariesKey, value, .shouldPropagate)
    }

    public func setColorSpaceAttachments(_ colorSpace: ImageColorSpaceContract) {
        guard colorSpace.preservesInput == false else {
            return
        }
        if let primaries = Self.cvColorPrimariesValue(for: colorSpace.gamut) {
            CVBufferSetAttachment(base, kCVImageBufferColorPrimariesKey, primaries, .shouldPropagate)
        }
        if let transfer = Self.cvTransferFunctionValue(for: colorSpace.transferFunction) {
            CVBufferSetAttachment(base, kCVImageBufferTransferFunctionKey, transfer, .shouldPropagate)
        }
    }

    public func textureCopyCompatibilityError(for texture: MTLTexture) -> HarbethError? {
        guard base.c7.size == texture.c7.toC7Size() else {
            return .textureSizeMismatch
        }
        let contract = self.contract
        guard contract.planar == false else {
            return .configurationInvalid("Pixel buffer copy-back only supports non-planar outputs.")
        }
        guard let expectedPixelFormat = contract.preferredMetalPixelFormat else {
            return .configurationInvalid(
                "Pixel buffer copy-back does not support CV pixel format type \(contract.cvPixelFormatType)."
            )
        }
        guard texture.pixelFormat == expectedPixelFormat else {
            return .configurationInvalid(
                "Pixel buffer copy-back pixel format mismatch. Texture pixelFormat=\(texture.pixelFormat), expected \(expectedPixelFormat)."
            )
        }
        return nil
    }
    
    /// Creates new pixel buffer from texture
    /// - Parameter texture: Source Metal texture
    /// - Returns: New pixel buffer
    public func copyToCVPixelBuffer(with texture: MTLTexture) -> CVPixelBuffer {
        lockBaseAddress(.readOnly)
        defer { unlockBaseAddress(.readOnly) }
        var outPixelbuffer: CVPixelBuffer? = base
        if let datas = texture.buffer?.contents() {
            CVPixelBufferCreateWithBytes(kCFAllocatorDefault,
                                         texture.width,
                                         texture.height,
                                         kCVPixelFormatType_64RGBAHalf,
                                         datas,
                                         texture.bufferBytesPerRow,
                                         nil, nil, nil,
                                         &outPixelbuffer);
        }
        return outPixelbuffer ?? base
    }
    
    /// Creates CMSampleBuffer from pixel buffer
    /// - Returns: CMSampleBuffer or nil
    public func toCMSampleBuffer(reference sampleBuffer: CMSampleBuffer? = nil) -> CMSampleBuffer? {
        if let sampleBuffer {
            if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                base.c7.copyAttachments(from: imageBuffer)
            }
            return sampleBuffer.c7.makeDerivedSampleBuffer(imageBuffer: base)
        }
        var newSampleBuffer: CMSampleBuffer?
        var timimgInfo = CMSampleTimingInfo.invalid
        var videoInfo: CMVideoFormatDescription?
        
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: base, formatDescriptionOut: &videoInfo)
        guard let videoInfo = videoInfo else {
            return nil
        }
        CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                           imageBuffer: base,
                                           dataReady: true,
                                           makeDataReadyCallback: nil,
                                           refcon: nil,
                                           formatDescription: videoInfo,
                                           sampleTiming: &timimgInfo,
                                           sampleBufferOut: &newSampleBuffer)
        return newSampleBuffer
    }
    
    /// Converts to Metal texture based on environment
    /// - Parameter textureCache: Texture cache (real device only)
    /// - Returns: Metal texture or nil
    public func toMTLTexture(textureCache: CVMetalTextureCache? = nil) -> MTLTexture? {
        let bridgePlan = makeTextureBridgePlan()
        switch bridgePlan.loadStrategy {
        case .directMetalTexture:
            #if targetEnvironment(simulator)
            return base.c7.toCGImage()?.c7.toTexture(pixelFormat: .rgba8Unorm)
            #else
            let cache = textureCache ?? Shared.shared.sharedTextureCache
            return convert2MTLTexture(
                textureCache: cache,
                pixelFormat: bridgePlan.contract.preferredMetalPixelFormat ?? .bgra8Unorm,
                planeIndex: 0
            )
            #endif
        case .directPlaneTexture:
            #if targetEnvironment(simulator)
            return base.c7.toCGImage()?.c7.toTexture(pixelFormat: .rgba8Unorm)
            #else
            let cache = textureCache ?? Shared.shared.sharedTextureCache
            let textures = createPlaneTextures(textureCache: cache)
            guard let primary = textures.first else {
                return nil
            }
            TextureOwnerRegistry.attach(base, to: primary)
            return primary
            #endif
        case .cgImageFallback:
            return base.c7.toCGImage()?.c7.toTexture(pixelFormat: .rgba8Unorm)
        case .cpuCopyFallback:
            return nil
        }
    }
    
    /// Creates new Metal texture from pixel buffer
    /// - Parameters:
    ///   - pixelFormat: Metal pixel format
    ///   - planeIndex: Plane index for planar buffers
    /// - Returns: New Metal texture
    /// - Throws: Texture creation error
    public func createMTLTexture(pixelFormat: MTLPixelFormat = .bgra8Unorm, planeIndex: Int = 0) throws -> MTLTexture {
        let isPlanar = CVPixelBufferIsPlanar(base)
        let width = Self.width(of: base, planeIndex: planeIndex, planar: isPlanar)
        let height = Self.height(of: base, planeIndex: planeIndex, planar: isPlanar)
        let texture = try TextureLoader.makeTexture(width: width, height: height, options: [
            .texturePixelFormat: pixelFormat
        ])
        let success = base.c7.copyToPixelBuffer(with: texture)
        if !success {
            throw HarbethError.textureCopyPixelBufferFailed
        }
        return texture
    }
    
    /// Locks pixel buffer memory for access
    /// - Parameter lockFlags: Lock flags
    /// - Returns: Lock status
    @discardableResult
    public func lockBaseAddress(_ lockFlags: CVPixelBufferLockFlags = .readOnly) -> CVReturn {
        return CVPixelBufferLockBaseAddress(base, lockFlags)
    }
    
    /// Unlocks pixel buffer memory
    /// - Parameter lockFlags: Lock flags
    /// - Returns: Unlock status
    @discardableResult
    public func unlockBaseAddress(_ lockFlags: CVPixelBufferLockFlags = .readOnly) -> CVReturn {
        return CVPixelBufferUnlockBaseAddress(base, lockFlags)
    }

    private static func colorModel(for pixelFormatType: OSType, planeCount: Int) -> PixelBufferColorModel {
        switch pixelFormatType {
        case kCVPixelFormatType_32BGRA, kCVPixelFormatType_32RGBA, kCVPixelFormatType_32ARGB, kCVPixelFormatType_64RGBAHalf:
            return .rgba
        case kCVPixelFormatType_OneComponent8:
            return .monochrome
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
             kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            return .yCbCrBiPlanar
        case kCVPixelFormatType_420YpCbCr8Planar,
             kCVPixelFormatType_420YpCbCr8PlanarFullRange:
            return .yCbCrTriPlanar
        default:
            return planeCount == 1 ? .unknown : .unknown
        }
    }

    private static func preferredMetalPixelFormat(for pixelFormatType: OSType,
                                                  planeIndex: Int,
                                                  planar: Bool) -> MTLPixelFormat? {
        if planar == false {
            switch pixelFormatType {
            case kCVPixelFormatType_32BGRA:
                return .bgra8Unorm
            case kCVPixelFormatType_32RGBA, kCVPixelFormatType_32ARGB:
                return .rgba8Unorm
            case kCVPixelFormatType_64RGBAHalf:
                return .rgba16Float
            case kCVPixelFormatType_OneComponent8:
                return .r8Unorm
            default:
                return nil
            }
        }
        switch pixelFormatType {
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
             kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            return planeIndex == 0 ? .r8Unorm : .rg8Unorm
        case kCVPixelFormatType_420YpCbCr8Planar,
             kCVPixelFormatType_420YpCbCr8PlanarFullRange:
            return .r8Unorm
        default:
            return nil
        }
    }

    private static func width(of pixelBuffer: CVPixelBuffer, planeIndex: Int, planar: Bool) -> Int {
        planar ? CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex) : CVPixelBufferGetWidth(pixelBuffer)
    }

    private static func height(of pixelBuffer: CVPixelBuffer, planeIndex: Int, planar: Bool) -> Int {
        planar ? CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex) : CVPixelBufferGetHeight(pixelBuffer)
    }

    private static func bytesPerRow(of pixelBuffer: CVPixelBuffer, planeIndex: Int, planar: Bool) -> Int {
        planar ? CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, planeIndex) : CVPixelBufferGetBytesPerRow(pixelBuffer)
    }
}
