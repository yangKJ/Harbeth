//
//  ImageContracts.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//
import Foundation
import CoreGraphics
import CoreVideo
import Metal

/// 图像 alpha 的语义类型。
///
/// 这层语义保持 Harbeth 当前底座足够轻量：
/// - premultiplied: RGB 已经乘过 alpha
/// - nonPremultiplied: 直通颜色，RGB 未乘 alpha
/// - alphaIsOne: 图像可视为不透明
public enum AlphaType: String, Sendable, Codable, Equatable {
    case premultiplied
    case nonPremultiplied
    case alphaIsOne

    public init(cgImageAlphaInfo: CGImageAlphaInfo) {
        switch cgImageAlphaInfo {
        case .premultipliedFirst, .premultipliedLast:
            self = .premultiplied
        case .first, .last, .alphaOnly:
            self = .nonPremultiplied
        case .none, .noneSkipFirst, .noneSkipLast:
            self = .alphaIsOne
        @unknown default:
            self = .premultiplied
        }
    }

    public var cgImageAlphaInfoForRGBA: CGImageAlphaInfo {
        switch self {
        case .premultiplied:
            return .premultipliedLast
        case .nonPremultiplied:
            return .last
        case .alphaIsOne:
            return .noneSkipLast
        }
    }
}

public enum ImageAlphaContract: Sendable, Codable, Equatable, Hashable {
    case opaque
    case premultiplied
    case nonPremultiplied
    case preserveInput
    case forcePremultiply
    case forceUnpremultiply

    public var expectedAlphaType: AlphaType? {
        switch self {
        case .opaque:
            return .alphaIsOne
        case .premultiplied, .forcePremultiply:
            return .premultiplied
        case .nonPremultiplied, .forceUnpremultiply:
            return .nonPremultiplied
        case .preserveInput:
            return nil
        }
    }
}

public enum ImageColorGamut: String, Sendable, Codable, Equatable, Hashable {
    case preserveInput
    case sRGB
    case displayP3
    case extendedLinearSRGB
    case custom
}

public enum ImageTransferFunction: String, Sendable, Codable, Equatable, Hashable {
    case preserveInput
    case sRGB
    case linear
    case perceptualQuantizer
    case hybridLogGamma
    case custom
}

public struct ImageColorSpaceContract: Sendable, Codable, Equatable, Hashable {
    public let name: String
    public let preservesInput: Bool
    public let gamut: ImageColorGamut
    public let transferFunction: ImageTransferFunction

    public init(name: String = "preserveInput",
                preservesInput: Bool = true,
                gamut: ImageColorGamut = .preserveInput,
                transferFunction: ImageTransferFunction = .preserveInput) {
        self.name = name
        self.preservesInput = preservesInput
        self.gamut = gamut
        self.transferFunction = transferFunction
    }

    public static let preserveInput = ImageColorSpaceContract()
    public static let sRGB = ImageColorSpaceContract(
        name: "sRGB",
        preservesInput: false,
        gamut: .sRGB,
        transferFunction: .sRGB
    )
    public static let displayP3 = ImageColorSpaceContract(
        name: "DisplayP3",
        preservesInput: false,
        gamut: .displayP3,
        transferFunction: .sRGB
    )
    public static let extendedLinearSRGB = ImageColorSpaceContract(
        name: "extendedLinearSRGB",
        preservesInput: false,
        gamut: .extendedLinearSRGB,
        transferFunction: .linear
    )

    public var isWideGamut: Bool {
        switch gamut {
        case .displayP3, .extendedLinearSRGB:
            return true
        case .preserveInput, .sRGB, .custom:
            return false
        }
    }

    public var isHDRTransfer: Bool {
        switch transferFunction {
        case .perceptualQuantizer, .hybridLogGamma:
            return true
        case .preserveInput, .sRGB, .linear, .custom:
            return false
        }
    }

    public var fingerprint: String {
        [
            "color=\(name)",
            "gamut=\(gamut.rawValue)",
            "transfer=\(transferFunction.rawValue)",
            "preserve=\(preservesInput ? 1 : 0)"
        ].joined(separator: "|")
    }

    enum CodingKeys: String, CodingKey {
        case name
        case preservesInput
        case gamut
        case transferFunction
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.preservesInput = try container.decode(Bool.self, forKey: .preservesInput)
        self.gamut = try container.decodeIfPresent(ImageColorGamut.self, forKey: .gamut) ?? .preserveInput
        self.transferFunction = try container.decodeIfPresent(ImageTransferFunction.self, forKey: .transferFunction) ?? .preserveInput
    }

    public func transferConversionMode(from source: ImageColorSpaceContract) -> C7RGBTransferConversion.Mode? {
        guard preservesInput == false,
              source.preservesInput == false,
              supportsTransferOnlyConversion(from: source) else {
            return nil
        }
        switch (source.transferFunction, transferFunction) {
        case (.sRGB, .linear):
            return .sRGBToLinear
        case (.linear, .sRGB):
            return .linearToSRGB
        default:
            return nil
        }
    }

    public func makeTransferConversionFilter(from source: ImageColorSpaceContract) -> C7RGBTransferConversion? {
        C7RGBTransferConversion(from: source, to: self)
    }

    private func supportsTransferOnlyConversion(from source: ImageColorSpaceContract) -> Bool {
        switch (source.gamut, gamut) {
        case (.sRGB, .sRGB),
             (.sRGB, .extendedLinearSRGB),
             (.extendedLinearSRGB, .sRGB),
             (.extendedLinearSRGB, .extendedLinearSRGB):
            return true
        default:
            return false
        }
    }
}

public enum PixelPrecision: String, Sendable, Codable, Equatable, Hashable {
    case preserveInput
    case unorm8
    case float16
    case float32
    case custom
}

public struct PixelFormatContract: Sendable, Codable, Equatable, Hashable {
    public let name: String
    public let preservesInput: Bool
    public let metalPixelFormatRawValue: UInt?
    public let precision: PixelPrecision

    public init(pixelFormat: MTLPixelFormat? = nil,
                preservesInput: Bool = true,
                precision: PixelPrecision? = nil) {
        self.name = pixelFormat.map { String(describing: $0) } ?? "preserveInput"
        self.preservesInput = preservesInput
        self.metalPixelFormatRawValue = pixelFormat?.rawValue
        self.precision = precision ?? PixelFormatContract.precision(for: pixelFormat)
    }

    public static let preserveInput = PixelFormatContract()
    public static let rgba8Unorm = PixelFormatContract(pixelFormat: .rgba8Unorm, preservesInput: false)
    public static let bgra8Unorm = PixelFormatContract(pixelFormat: .bgra8Unorm, preservesInput: false)
    public static let rgba16Float = PixelFormatContract(pixelFormat: .rgba16Float, preservesInput: false)
    public static let rgba32Float = PixelFormatContract(pixelFormat: .rgba32Float, preservesInput: false)

    public var isHighPrecision: Bool {
        switch precision {
        case .float16, .float32:
            return true
        case .preserveInput, .unorm8, .custom:
            return false
        }
    }

    public var fingerprint: String {
        [
            "pixelFormat=\(name)",
            "raw=\(metalPixelFormatRawValue.map(String.init) ?? "preserve")",
            "precision=\(precision.rawValue)",
            "preserve=\(preservesInput ? 1 : 0)"
        ].joined(separator: "|")
    }

    public var metalPixelFormat: MTLPixelFormat? {
        metalPixelFormatRawValue.flatMap { MTLPixelFormat(rawValue: $0) }
    }

    private static func precision(for pixelFormat: MTLPixelFormat?) -> PixelPrecision {
        switch pixelFormat {
        case .none:
            return .preserveInput
        case .some(.rgba8Unorm), .some(.bgra8Unorm), .some(.rgba8Unorm_srgb), .some(.bgra8Unorm_srgb):
            return .unorm8
        case .some(.rgba16Float), .some(.r16Float), .some(.rg16Float):
            return .float16
        case .some(.rgba32Float), .some(.r32Float), .some(.rg32Float):
            return .float32
        default:
            return .custom
        }
    }

    enum CodingKeys: String, CodingKey {
        case name
        case preservesInput
        case metalPixelFormatRawValue
        case precision
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.preservesInput = try container.decode(Bool.self, forKey: .preservesInput)
        self.metalPixelFormatRawValue = try container.decodeIfPresent(UInt.self, forKey: .metalPixelFormatRawValue)
        self.precision = try container.decodeIfPresent(PixelPrecision.self, forKey: .precision) ?? .custom
    }
}

public struct RenderOutputContract: Sendable, Codable, Equatable, Hashable {
    public let alpha: ImageAlphaContract
    public let colorSpace: ImageColorSpaceContract
    public let pixelFormat: PixelFormatContract
    public let preservesOrientation: Bool

    public init(alpha: ImageAlphaContract = .preserveInput,
                colorSpace: ImageColorSpaceContract = .preserveInput,
                pixelFormat: PixelFormatContract = .preserveInput,
                preservesOrientation: Bool = true) {
        self.alpha = alpha
        self.colorSpace = colorSpace
        self.pixelFormat = pixelFormat
        self.preservesOrientation = preservesOrientation
    }

    public static let preserveInput = RenderOutputContract()

    public static let displayP3Texture = RenderOutputContract(
        colorSpace: .displayP3,
        pixelFormat: .rgba8Unorm
    )

    public static let highPrecisionLinearTexture = RenderOutputContract(
        colorSpace: .extendedLinearSRGB,
        pixelFormat: .rgba16Float
    )

    public var requiresAlphaConversion: Bool {
        switch alpha {
        case .opaque, .premultiplied, .nonPremultiplied, .forcePremultiply, .forceUnpremultiply:
            return true
        case .preserveInput:
            return false
        }
    }

    public var requiresColorSpaceConversion: Bool {
        colorSpace.preservesInput == false
    }

    public var requiresPixelFormatConversion: Bool {
        pixelFormat.preservesInput == false
    }

    public var isWideGamutOutput: Bool {
        colorSpace.isWideGamut
    }

    public var isHighPrecisionOutput: Bool {
        pixelFormat.isHighPrecision
    }

    public var isHDRFriendlyOutput: Bool {
        colorSpace.isWideGamut || colorSpace.isHDRTransfer || pixelFormat.isHighPrecision
    }

    public var fingerprint: String {
        [
            "alpha=\(alpha)",
            colorSpace.fingerprint,
            pixelFormat.fingerprint,
            "orientation=\(preservesOrientation ? "preserve" : "reset")"
        ].joined(separator: "|")
    }
}

public enum PixelBufferColorModel: String, Sendable, Codable, Equatable, Hashable {
    case rgba
    case yCbCrBiPlanar
    case yCbCrTriPlanar
    case monochrome
    case unknown
}

public enum PixelBufferNativeTextureLayout: String, Sendable, Codable, Equatable, Hashable {
    case directSingleTexture
    case planeTextures
    case unsupported
}

public enum PixelBufferTextureLoadStrategy: String, Sendable, Codable, Equatable, Hashable {
    case directMetalTexture
    case cgImageFallback
    case cpuCopyFallback
}

public struct PixelBufferPlaneContract: Sendable, Codable, Equatable, Hashable {
    public let index: Int
    public let width: Int
    public let height: Int
    public let bytesPerRow: Int
    public let cvPixelFormatType: OSType
    public let metalPixelFormatRawValue: UInt?

    public init(index: Int,
                width: Int,
                height: Int,
                bytesPerRow: Int,
                cvPixelFormatType: OSType,
                metalPixelFormat: MTLPixelFormat?) {
        self.index = index
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.cvPixelFormatType = cvPixelFormatType
        self.metalPixelFormatRawValue = metalPixelFormat?.rawValue
    }

    public var metalPixelFormat: MTLPixelFormat? {
        metalPixelFormatRawValue.flatMap(MTLPixelFormat.init(rawValue:))
    }

    public var fingerprint: String {
        [
            "plane=\(index)",
            "size=\(width)x\(height)",
            "bytesPerRow=\(bytesPerRow)",
            "cv=\(cvPixelFormatType)",
            "metal=\(metalPixelFormatRawValue.map(String.init) ?? "none")"
        ].joined(separator: "|")
    }
}

public struct PixelBufferContract: Sendable, Codable, Equatable, Hashable {
    public let width: Int
    public let height: Int
    public let cvPixelFormatType: OSType
    public let planeCount: Int
    public let planar: Bool
    public let colorModel: PixelBufferColorModel
    public let nativeTextureLayout: PixelBufferNativeTextureLayout
    public let planes: [PixelBufferPlaneContract]

    public init(width: Int,
                height: Int,
                cvPixelFormatType: OSType,
                planeCount: Int,
                planar: Bool,
                colorModel: PixelBufferColorModel,
                nativeTextureLayout: PixelBufferNativeTextureLayout,
                planes: [PixelBufferPlaneContract]) {
        self.width = width
        self.height = height
        self.cvPixelFormatType = cvPixelFormatType
        self.planeCount = planeCount
        self.planar = planar
        self.colorModel = colorModel
        self.nativeTextureLayout = nativeTextureLayout
        self.planes = planes
    }

    public var requiresYCbCrConversion: Bool {
        switch colorModel {
        case .yCbCrBiPlanar, .yCbCrTriPlanar:
            return true
        case .rgba, .monochrome, .unknown:
            return false
        }
    }

    public var preferredMetalPixelFormat: MTLPixelFormat? {
        planes.first?.metalPixelFormat
    }

    public var fingerprint: String {
        [
            "size=\(width)x\(height)",
            "cv=\(cvPixelFormatType)",
            "planes=\(planeCount)",
            "planar=\(planar ? 1 : 0)",
            "model=\(colorModel.rawValue)",
            "layout=\(nativeTextureLayout.rawValue)",
            planes.map(\.fingerprint).joined(separator: "||")
        ].joined(separator: "|")
    }
}

public struct PixelBufferTextureBridgePlan: Sendable, Codable, Equatable, Hashable {
    public let contract: PixelBufferContract
    public let loadStrategy: PixelBufferTextureLoadStrategy
    public let preservesOwnerReference: Bool

    public init(contract: PixelBufferContract,
                loadStrategy: PixelBufferTextureLoadStrategy,
                preservesOwnerReference: Bool) {
        self.contract = contract
        self.loadStrategy = loadStrategy
        self.preservesOwnerReference = preservesOwnerReference
    }

    public var requiresColorConversion: Bool {
        contract.requiresYCbCrConversion
    }

    public var fingerprint: String {
        [
            contract.fingerprint,
            "load=\(loadStrategy.rawValue)",
            "owner=\(preservesOwnerReference ? 1 : 0)"
        ].joined(separator: "|")
    }
}

public struct TimeValueContract: Sendable, Codable, Equatable, Hashable {
    public let value: Int64
    public let timescale: Int32
    public let epoch: Int64
    public let flagsRawValue: UInt32
    public let isValid: Bool

    public init(time: CMTime) {
        self.value = time.value
        self.timescale = time.timescale
        self.epoch = time.epoch
        self.flagsRawValue = time.flags.rawValue
        self.isValid = time.isValid
    }

    public var fingerprint: String {
        [
            "value=\(value)",
            "timescale=\(timescale)",
            "epoch=\(epoch)",
            "flags=\(flagsRawValue)",
            "valid=\(isValid ? 1 : 0)"
        ].joined(separator: "|")
    }
}

public struct SampleAttachmentContract: Sendable, Codable, Equatable, Hashable {
    public let notSync: Bool?
    public let dependsOnOthers: Bool?
    public let earlierDisplayTimesAllowed: Bool?
    public let displayImmediately: Bool?
    public let doNotDisplay: Bool?

    public init(notSync: Bool? = nil,
                dependsOnOthers: Bool? = nil,
                earlierDisplayTimesAllowed: Bool? = nil,
                displayImmediately: Bool? = nil,
                doNotDisplay: Bool? = nil) {
        self.notSync = notSync
        self.dependsOnOthers = dependsOnOthers
        self.earlierDisplayTimesAllowed = earlierDisplayTimesAllowed
        self.displayImmediately = displayImmediately
        self.doNotDisplay = doNotDisplay
    }

    public var fingerprint: String {
        [
            "notSync=\(Self.stableBoolDescription(notSync))",
            "depends=\(Self.stableBoolDescription(dependsOnOthers))",
            "early=\(Self.stableBoolDescription(earlierDisplayTimesAllowed))",
            "immediate=\(Self.stableBoolDescription(displayImmediately))",
            "hidden=\(Self.stableBoolDescription(doNotDisplay))"
        ].joined(separator: "|")
    }

    private static func stableBoolDescription(_ value: Bool?) -> String {
        switch value {
        case .some(true):
            return "1"
        case .some(false):
            return "0"
        case .none:
            return "none"
        }
    }
}

public struct SampleBufferContract: Sendable, Codable, Equatable, Hashable {
    public let numSamples: Int
    public let isValid: Bool
    public let presentationTimeStamp: TimeValueContract
    public let decodeTimeStamp: TimeValueContract
    public let duration: TimeValueContract
    public let formatDescriptionMediaType: FourCharCode?
    public let formatDescriptionMediaSubType: FourCharCode?
    public let pixelBufferContract: PixelBufferContract?
    public let attachments: SampleAttachmentContract

    public init(numSamples: Int,
                isValid: Bool,
                presentationTimeStamp: TimeValueContract,
                decodeTimeStamp: TimeValueContract,
                duration: TimeValueContract,
                formatDescriptionMediaType: FourCharCode?,
                formatDescriptionMediaSubType: FourCharCode?,
                pixelBufferContract: PixelBufferContract?,
                attachments: SampleAttachmentContract) {
        self.numSamples = numSamples
        self.isValid = isValid
        self.presentationTimeStamp = presentationTimeStamp
        self.decodeTimeStamp = decodeTimeStamp
        self.duration = duration
        self.formatDescriptionMediaType = formatDescriptionMediaType
        self.formatDescriptionMediaSubType = formatDescriptionMediaSubType
        self.pixelBufferContract = pixelBufferContract
        self.attachments = attachments
    }

    public var fingerprint: String {
        [
            "samples=\(numSamples)",
            "valid=\(isValid ? 1 : 0)",
            "pts={\(presentationTimeStamp.fingerprint)}",
            "dts={\(decodeTimeStamp.fingerprint)}",
            "duration={\(duration.fingerprint)}",
            "mediaType=\(formatDescriptionMediaType.map(String.init) ?? "none")",
            "subType=\(formatDescriptionMediaSubType.map(String.init) ?? "none")",
            attachments.fingerprint,
            pixelBufferContract.map { "pixelBuffer={\($0.fingerprint)}" } ?? "pixelBuffer=none"
        ].joined(separator: "|")
    }
}

/// 图像采样合同，用于 lazy graph、render diagnostics 和 sampler cache。
public struct ImageSamplerDescriptor: Sendable, Equatable, Hashable {
    public let minFilter: MTLSamplerMinMagFilter
    public let magFilter: MTLSamplerMinMagFilter
    public let mipFilter: MTLSamplerMipFilter
    public let sAddressMode: MTLSamplerAddressMode
    public let tAddressMode: MTLSamplerAddressMode

    public init(minFilter: MTLSamplerMinMagFilter = .linear,
                magFilter: MTLSamplerMinMagFilter = .linear,
                mipFilter: MTLSamplerMipFilter = .notMipmapped,
                sAddressMode: MTLSamplerAddressMode = .clampToEdge,
                tAddressMode: MTLSamplerAddressMode = .clampToEdge) {
        self.minFilter = minFilter
        self.magFilter = magFilter
        self.mipFilter = mipFilter
        self.sAddressMode = sAddressMode
        self.tAddressMode = tAddressMode
    }

    public static let `default` = ImageSamplerDescriptor()

    public static let nearest = ImageSamplerDescriptor(
        minFilter: .nearest,
        magFilter: .nearest
    )

    public var fingerprint: String {
        [
            "min=\(minFilter.rawValue)",
            "mag=\(magFilter.rawValue)",
            "mip=\(mipFilter.rawValue)",
            "s=\(sAddressMode.rawValue)",
            "t=\(tAddressMode.rawValue)"
        ].joined(separator: "|")
    }
}

/// 图像或纹理结果的缓存语义。
///
/// 延续 Harbeth 的 transient / persistent 区分，并保持 Harbeth 当前
/// texture-first 结构：
/// - persistent: 外部 source、自身可长期复用的结果
/// - transient: 滤镜中间态、低延迟输出、可重建结果
public enum ImageCachePolicy: String, Sendable, Codable, Equatable {
    case transient
    case persistent
}

public struct HarbethSourceDescriptor: Sendable, Hashable, Codable {
    public let kind: String
    public let sourceTier: ImageSourceTier
    public let alphaType: AlphaType
    public let orientation: FrameOrientation
    public let cachePolicy: ImageCachePolicy
    public let semantic: ImageSemanticDescriptor
    public let loadingOptions: ImageLoadingOptions
    public let pixelBufferContract: PixelBufferContract?
    public let pixelBufferBridgePlan: PixelBufferTextureBridgePlan?
    public let sampleBufferContract: SampleBufferContract?

    public init(kind: String,
                sourceTier: ImageSourceTier = .original,
                alphaType: AlphaType,
                orientation: FrameOrientation,
                cachePolicy: ImageCachePolicy,
                semantic: ImageSemanticDescriptor = .sourceOriginal,
                loadingOptions: ImageLoadingOptions = .default,
                pixelBufferContract: PixelBufferContract? = nil,
                pixelBufferBridgePlan: PixelBufferTextureBridgePlan? = nil,
                sampleBufferContract: SampleBufferContract? = nil) {
        self.kind = kind
        self.sourceTier = sourceTier
        self.alphaType = alphaType
        self.orientation = orientation
        self.cachePolicy = cachePolicy
        self.semantic = semantic
        self.loadingOptions = loadingOptions
        self.pixelBufferContract = pixelBufferContract
        self.pixelBufferBridgePlan = pixelBufferBridgePlan
        self.sampleBufferContract = sampleBufferContract
    }

    public var fingerprint: String {
        var parts = [
            "kind=\(kind)",
            "tier=\(sourceTier.rawValue)",
            "alpha=\(alphaType.rawValue)",
            "orientation=\(orientation.rawValue)",
            "cache=\(cachePolicy.rawValue)",
            semantic.fingerprint,
            loadingOptions.fingerprint
        ]
        if let pixelBufferContract {
            parts.append("pixelBuffer={\(pixelBufferContract.fingerprint)}")
        }
        if let pixelBufferBridgePlan {
            parts.append("bridge={\(pixelBufferBridgePlan.fingerprint)}")
        }
        if let sampleBufferContract {
            parts.append("sampleBuffer={\(sampleBufferContract.fingerprint)}")
        }
        return parts.joined(separator: "|")
    }
}

/// 图像在处理链路中的职责角色。
public enum ImageRole: String, Sendable, Codable, Hashable {
    /// 外部传入、作为真相源的输入。
    case source
    /// 处理中可继续派生其他结果的工作图。
    case derivative
    /// 作为最终交付或读回目标的输出。
    case output
}

/// 图像对上层的使用意图。
public enum ImagePurpose: String, Sendable, Codable, Hashable {
    case processingInput
    case interactive
    case responsive
    case stable
    case inspection
    case thumbnail
    case delivery
    case export
    case readback
}

/// 图像内容的清晰度与保真档位。
public enum ImageFidelity: String, Sendable, Codable, Hashable {
    case original
    case lowLatency
    case displayOptimized
    case thumbnailOptimized
    case fullResolution
}

/// 供 source / frame / recipe 共享的图像语义描述。
public struct ImageSemanticDescriptor: Sendable, Hashable, Codable {
    public let role: ImageRole
    public let purpose: ImagePurpose
    public let fidelity: ImageFidelity

    public init(role: ImageRole, purpose: ImagePurpose, fidelity: ImageFidelity) {
        self.role = role
        self.purpose = purpose
        self.fidelity = fidelity
    }

    public var fingerprint: String {
        [
            "role=\(role.rawValue)",
            "purpose=\(purpose.rawValue)",
            "fidelity=\(fidelity.rawValue)"
        ].joined(separator: "|")
    }

    public static let sourceOriginal = ImageSemanticDescriptor(
        role: .source,
        purpose: .processingInput,
        fidelity: .original
    )
}

public extension RenderProfile {
    var defaultImageSemantic: ImageSemanticDescriptor {
        switch self {
        case .interactiveLatency:
            return ImageSemanticDescriptor(
                role: .derivative,
                purpose: .interactive,
                fidelity: .lowLatency
            )
        case .responseLatency:
            return ImageSemanticDescriptor(
                role: .derivative,
                purpose: .responsive,
                fidelity: .displayOptimized
            )
        case .stablePreview:
            return ImageSemanticDescriptor(
                role: .derivative,
                purpose: .stable,
                fidelity: .displayOptimized
            )
        case .inspectionQuality:
            return ImageSemanticDescriptor(
                role: .derivative,
                purpose: .inspection,
                fidelity: .fullResolution
            )
        case .exportQuality:
            return ImageSemanticDescriptor(
                role: .output,
                purpose: .export,
                fidelity: .fullResolution
            )
        case .readbackQuality:
            return ImageSemanticDescriptor(
                role: .output,
                purpose: .readback,
                fidelity: .fullResolution
            )
        }
    }
}

/// 图像 source 在进入 Harbeth 前的加载尺寸策略。
public enum ImageSourceSizePolicy: Sendable, Hashable, Codable {
    /// 以原始像素尺寸加载。
    case original
    /// 约束最长边到指定像素，保持纵横比。
    case maxPixelSize(Int)
    /// 约束到指定逻辑尺寸的包围盒，保持纵横比。
    case fit(width: Int, height: Int)

    public var fingerprint: String {
        switch self {
        case .original:
            return "size=original"
        case .maxPixelSize(let value):
            return "size=maxPixel:\(max(value, 1))"
        case .fit(let width, let height):
            return "size=fit:\(max(width, 1))x\(max(height, 1))"
        }
    }

    public func resolvedMaxPixelSize() -> Int? {
        switch self {
        case .original:
            return nil
        case .maxPixelSize(let value):
            return max(value, 1)
        case .fit(let width, let height):
            return max(max(width, 1), max(height, 1))
        }
    }

    public static func fit(_ size: CGSize) -> ImageSourceSizePolicy {
        .fit(width: Int(max(size.width.rounded(.up), 1)),
             height: Int(max(size.height.rounded(.up), 1)))
    }
}

/// 图像 source 解码/降采样时的稳定选项。
public struct ImageLoadingOptions: Sendable, Hashable, Codable {
    public let sizePolicy: ImageSourceSizePolicy
    public let flipsVertically: Bool

    public init(sizePolicy: ImageSourceSizePolicy = .original,
                flipsVertically: Bool = false) {
        self.sizePolicy = sizePolicy
        self.flipsVertically = flipsVertically
    }

    public var fingerprint: String {
        [
            sizePolicy.fingerprint,
            "flip=\(flipsVertically ? 1 : 0)"
        ].joined(separator: "|")
    }

    public static let `default` = ImageLoadingOptions()
}

/// 可携带稳定加载策略的外部图像资源。
public struct HarbethImageAsset: @unchecked Sendable {
    public enum Storage {
        case data(Data)
        case url(URL)
        case cgImage(CGImage)

        var kindName: String {
            switch self {
            case .data:
                return "dataAsset"
            case .url:
                return "urlAsset"
            case .cgImage:
                return "cgImageAsset"
            }
        }
    }

    public let storage: Storage
    public let loadingOptions: ImageLoadingOptions
    public let sourceTier: ImageSourceTier

    public init(storage: Storage, loadingOptions: ImageLoadingOptions = .default, sourceTier: ImageSourceTier = .original) {
        self.storage = storage
        self.loadingOptions = loadingOptions
        self.sourceTier = sourceTier
    }
}

/// 输出资源的目标尺寸策略。
public enum OutputSizePolicy: Sendable, Hashable, Codable {
    case source
    case fit(C7Size)
    case exact(C7Size)
    case maxPixelSize(Int)

    public var fingerprint: String {
        switch self {
        case .source:
            return "output=source"
        case .fit(let size):
            return "output=fit:\(size.width)x\(size.height)"
        case .exact(let size):
            return "output=exact:\(size.width)x\(size.height)"
        case .maxPixelSize(let value):
            return "output=maxPixel:\(max(value, 1))"
        }
    }

    public func resolve(baseSize: C7Size) -> C7Size {
        switch self {
        case .source:
            return baseSize
        case .exact(let size):
            return C7Size(width: max(size.width, 1), height: max(size.height, 1))
        case .fit(let size):
            return CGSize(width: baseSize.width, height: baseSize.height)
                .c7.constrained(CGSize(width: max(size.width, 1), height: max(size.height, 1)))
                .c7.toC7Size()
        case .maxPixelSize(let value):
            let maxPixel = max(value, 1)
            return CGSize(width: baseSize.width, height: baseSize.height)
                .c7.constrained(CGSize(width: maxPixel, height: maxPixel))
                .c7.toC7Size()
        }
    }
}

/// 一份稳定的派生图规格。它描述“这次渲染想产出哪一类资源”，
/// 供 Harbeth 与上层共享，而不是让业务层重复拼装尺寸/语义。
public struct ImageDerivativeSpec: Sendable, Hashable, Codable {
    public let name: String
    public let renderIntent: RenderIntent
    public let sourceTier: ImageSourceTier
    public let semantic: ImageSemanticDescriptor
    public let outputSizePolicy: OutputSizePolicy

    public init(name: String,
                renderIntent: RenderIntent,
                sourceTier: ImageSourceTier,
                semantic: ImageSemanticDescriptor,
                outputSizePolicy: OutputSizePolicy) {
        self.name = name
        self.renderIntent = renderIntent
        self.sourceTier = sourceTier
        self.semantic = semantic
        self.outputSizePolicy = outputSizePolicy
    }

    public var fingerprint: String {
        [
            "name=\(name)",
            "intent=\(renderIntent.rawValue)",
            "tier=\(sourceTier.rawValue)",
            semantic.fingerprint,
            outputSizePolicy.fingerprint
        ].joined(separator: "|")
    }

    public func resolvedOutputSize(for baseSize: C7Size) -> C7Size {
        outputSizePolicy.resolve(baseSize: baseSize)
    }
}

public extension RenderProfile {
    var defaultDerivativeSpec: ImageDerivativeSpec {
        switch self {
        case .interactiveLatency:
            return ImageDerivativeSpec(
                name: "interactiveLatency",
                renderIntent: .interactive,
                sourceTier: .stableReusable,
                semantic: defaultImageSemantic,
                outputSizePolicy: .source
            )
        case .responseLatency:
            return ImageDerivativeSpec(
                name: "responseLatency",
                renderIntent: .responsive,
                sourceTier: .stableReusable,
                semantic: defaultImageSemantic,
                outputSizePolicy: .source
            )
        case .stablePreview:
            return ImageDerivativeSpec(
                name: "stablePreview",
                renderIntent: .stable,
                sourceTier: .stableReusable,
                semantic: defaultImageSemantic,
                outputSizePolicy: .source
            )
        case .inspectionQuality:
            return ImageDerivativeSpec(
                name: "inspectionQuality",
                renderIntent: .inspection,
                sourceTier: .fullResolutionReusable,
                semantic: defaultImageSemantic,
                outputSizePolicy: .source
            )
        case .exportQuality:
            return ImageDerivativeSpec(
                name: "exportQuality",
                renderIntent: .export,
                sourceTier: .fullResolutionReusable,
                semantic: defaultImageSemantic,
                outputSizePolicy: .source
            )
        case .readbackQuality:
            return ImageDerivativeSpec(
                name: "readbackQuality",
                renderIntent: .readback,
                sourceTier: .fullResolutionReusable,
                semantic: defaultImageSemantic,
                outputSizePolicy: .source
            )
        }
    }
}
