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

    var cgImageAlphaInfoForRGBA: CGImageAlphaInfo {
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

    var expectedAlphaType: AlphaType? {
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "opaque":
            self = .opaque
        case "premultiplied":
            self = .premultiplied
        case "nonPremultiplied":
            self = .nonPremultiplied
        case "preserveInput":
            self = .preserveInput
        case "forcePremultiply":
            self = .forcePremultiply
        case "forceUnpremultiply":
            self = .forceUnpremultiply
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown ImageAlphaContract value: \(rawValue)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let rawValue: String
        switch self {
        case .opaque:
            rawValue = "opaque"
        case .premultiplied:
            rawValue = "premultiplied"
        case .nonPremultiplied:
            rawValue = "nonPremultiplied"
        case .preserveInput:
            rawValue = "preserveInput"
        case .forcePremultiply:
            rawValue = "forcePremultiply"
        case .forceUnpremultiply:
            rawValue = "forceUnpremultiply"
        }
        try container.encode(rawValue)
    }
}

public enum ImageColorGamut: String, Sendable, Codable, Equatable, Hashable {
    case preserveInput
    case sRGB
    case displayP3
    case ituR2020
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
    public static let extendedLinearDisplayP3 = ImageColorSpaceContract(
        name: "extendedLinearDisplayP3",
        preservesInput: false,
        gamut: .displayP3,
        transferFunction: .linear
    )
    public static let extendedLinearSRGB = ImageColorSpaceContract(
        name: "extendedLinearSRGB",
        preservesInput: false,
        gamut: .extendedLinearSRGB,
        transferFunction: .linear
    )

    public var isWideGamut: Bool {
        switch gamut {
        case .displayP3, .ituR2020, .extendedLinearSRGB:
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

    func transferConversionMode(from source: ImageColorSpaceContract) -> C7RGBTransferConversion.Mode? {
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

    func makeTransferConversionFilter(from source: ImageColorSpaceContract) -> C7RGBTransferConversion? {
        C7RGBTransferConversion(from: source, to: self)
    }

    func colorConversionMode(from source: ImageColorSpaceContract) -> C7RGBColorSpaceConversion.Mode? {
        guard preservesInput == false,
              source.preservesInput == false else {
            return nil
        }
        switch (source.gamut, gamut) {
        case (.sRGB, .displayP3),
             (.extendedLinearSRGB, .displayP3):
            return .linearSRGBToLinearDisplayP3
        case (.displayP3, .sRGB),
             (.displayP3, .extendedLinearSRGB):
            return .linearDisplayP3ToLinearSRGB
        default:
            return nil
        }
    }

    func makeColorConversionFilters(from source: ImageColorSpaceContract) -> [C7FilterProtocol] {
        guard preservesInput == false,
              source.preservesInput == false else {
            return []
        }
        if let transferOnly = C7RGBTransferConversion(from: source, to: self) {
            return [transferOnly]
        }
        guard let gamutMode = colorConversionMode(from: source) else {
            return []
        }
        let decodeTransfer = source.transferFunction == .sRGB
            && (source.gamut == .sRGB || source.gamut == .displayP3)
        let encodeTransfer = transferFunction == .sRGB
            && (gamut == .sRGB || gamut == .displayP3)

        var filters: [C7FilterProtocol] = []
        if decodeTransfer {
            filters.append(C7RGBTransferConversion(mode: .sRGBToLinear))
        }
        filters.append(C7RGBColorSpaceConversion(mode: gamutMode))
        if encodeTransfer {
            filters.append(C7RGBTransferConversion(mode: .linearToSRGB))
        }
        return filters
    }

    private func supportsTransferOnlyConversion(from source: ImageColorSpaceContract) -> Bool {
        switch (source.gamut, gamut) {
        case (.sRGB, .sRGB),
             (.displayP3, .displayP3),
             (.sRGB, .extendedLinearSRGB),
             (.extendedLinearSRGB, .sRGB),
             (.extendedLinearSRGB, .extendedLinearSRGB):
            return true
        default:
            return false
        }
    }
}

extension ImageColorSpaceContract {
    var cgColorSpace: CGColorSpace? {
        switch (gamut, transferFunction) {
        case (.sRGB, _):
            return CGColorSpace(name: CGColorSpace.sRGB)
        case (.displayP3, .linear):
            if #available(macOS 10.14.3, iOS 12.3, tvOS 12.3, watchOS 5.1, *) {
                return CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
            }
            return CGColorSpace(name: CGColorSpace.displayP3)
        case (.displayP3, _):
            return CGColorSpace(name: CGColorSpace.displayP3)
        case (.extendedLinearSRGB, _):
            return CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
        case (.preserveInput, _), (.ituR2020, _), (.custom, _):
            return nil
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
        self.name = PixelFormatContract.name(for: pixelFormat)
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

    private static func name(for pixelFormat: MTLPixelFormat?) -> String {
        switch pixelFormat {
        case .none:
            return "preserveInput"
        case .some(.rgba8Unorm):
            return "rgba8Unorm"
        case .some(.bgra8Unorm):
            return "bgra8Unorm"
        case .some(.rgba8Unorm_srgb):
            return "rgba8Unorm_srgb"
        case .some(.bgra8Unorm_srgb):
            return "bgra8Unorm_srgb"
        case .some(.rgba16Float):
            return "rgba16Float"
        case .some(.rgba32Float):
            return "rgba32Float"
        case .some(.r8Unorm):
            return "r8Unorm"
        case .some(.rg8Unorm):
            return "rg8Unorm"
        case .some(.r16Float):
            return "r16Float"
        case .some(.rg16Float):
            return "rg16Float"
        case .some(.r32Float):
            return "r32Float"
        case .some(.rg32Float):
            return "rg32Float"
        case .some(let format):
            return "raw:\(format.rawValue)"
        }
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
    public let inputAlphaExpectation: ImageAlphaContract
    public let attachments: [RenderOutputAttachmentContract]
    public let colorTransferPolicy: ColorTransferPolicy
    public let pixelFormatFallbackPolicy: PixelFormatFallbackPolicy
    public let allowsLossyConversion: Bool
    public let preservesOrientation: Bool

    public init(inputAlphaExpectation: ImageAlphaContract = .preserveInput,
                alpha: ImageAlphaContract = .preserveInput,
                colorSpace: ImageColorSpaceContract = .preserveInput,
                pixelFormat: PixelFormatContract = .preserveInput,
                additionalAttachments: [RenderOutputAttachmentContract] = [],
                colorTransferPolicy: ColorTransferPolicy = .automatic,
                pixelFormatFallbackPolicy: PixelFormatFallbackPolicy = .preserveInput,
                allowsLossyConversion: Bool = false,
                preservesOrientation: Bool = true) {
        self.inputAlphaExpectation = inputAlphaExpectation
        self.attachments = RenderOutputContract.normalizeAttachments(
            primary: RenderOutputAttachmentContract(
                index: 0,
                semantic: .primaryColor,
                alpha: alpha,
                colorSpace: colorSpace,
                pixelFormat: pixelFormat
            ),
            additional: additionalAttachments
        )
        self.colorTransferPolicy = colorTransferPolicy
        self.pixelFormatFallbackPolicy = pixelFormatFallbackPolicy
        self.allowsLossyConversion = allowsLossyConversion
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

    public static let highPrecisionLinearDisplayP3Texture = RenderOutputContract(
        colorSpace: .extendedLinearDisplayP3,
        pixelFormat: .rgba16Float
    )

    public var primaryAttachment: RenderOutputAttachmentContract {
        attachments.first ?? RenderOutputAttachmentContract(index: 0)
    }

    public var alpha: ImageAlphaContract {
        primaryAttachment.alpha
    }

    public var colorSpace: ImageColorSpaceContract {
        primaryAttachment.colorSpace
    }

    public var pixelFormat: PixelFormatContract {
        primaryAttachment.pixelFormat
    }

    public var secondaryAttachments: [RenderOutputAttachmentContract] {
        Array(attachments.dropFirst())
    }

    public var hasMultipleAttachments: Bool {
        attachments.count > 1
    }

    public var attachmentCount: Int {
        attachments.count
    }

    public func attachmentContract(at index: Int) -> RenderOutputAttachmentContract? {
        attachments.first(where: { $0.index == index })
    }

    public var auxiliaryAttachments: [RenderOutputAttachmentContract] {
        attachments.filter(\.carriesAuxiliaryData)
    }

    public var auxiliaryAttachmentCount: Int {
        auxiliaryAttachments.count
    }

    public var attachmentDebugPolicies: [RenderOutputAttachmentDebugPolicy] {
        attachments.map(\.debugPolicy)
    }

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

    public var hasWideGamutAttachment: Bool {
        attachments.contains(where: { $0.colorSpace.isWideGamut })
    }

    public var hasHighPrecisionAttachment: Bool {
        attachments.contains(where: { $0.pixelFormat.isHighPrecision })
    }

    public var hasHDRFriendlyAttachment: Bool {
        attachments.contains(where: { $0.isHDRFriendlyOutput })
    }

    public var fingerprint: String {
        [
            "inputAlpha=\(inputAlphaExpectation)",
            "attachments=\(attachments.map(\.fingerprint).joined(separator: "||"))",
            "transferPolicy=\(colorTransferPolicy.rawValue)",
            "pixelFallback=\(pixelFormatFallbackPolicy.rawValue)",
            "lossy=\(allowsLossyConversion ? 1 : 0)",
            "orientation=\(preservesOrientation ? "preserve" : "reset")"
        ].joined(separator: "|")
    }

    enum CodingKeys: String, CodingKey {
        case inputAlphaExpectation
        case alpha
        case colorSpace
        case pixelFormat
        case attachments
        case colorTransferPolicy
        case pixelFormatFallbackPolicy
        case allowsLossyConversion
        case preservesOrientation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let inputAlphaExpectation = try container.decodeIfPresent(ImageAlphaContract.self, forKey: .inputAlphaExpectation) ?? .preserveInput
        let colorTransferPolicy = try container.decodeIfPresent(ColorTransferPolicy.self, forKey: .colorTransferPolicy) ?? .automatic
        let pixelFormatFallbackPolicy = try container.decodeIfPresent(PixelFormatFallbackPolicy.self, forKey: .pixelFormatFallbackPolicy) ?? .preserveInput
        let allowsLossyConversion = try container.decodeIfPresent(Bool.self, forKey: .allowsLossyConversion) ?? false
        let preservesOrientation = try container.decodeIfPresent(Bool.self, forKey: .preservesOrientation) ?? true
        let storedAttachments = try container.decodeIfPresent([RenderOutputAttachmentContract].self, forKey: .attachments)
        let alpha = try container.decodeIfPresent(ImageAlphaContract.self, forKey: .alpha) ?? .preserveInput
        let colorSpace = try container.decodeIfPresent(ImageColorSpaceContract.self, forKey: .colorSpace) ?? .preserveInput
        let pixelFormat = try container.decodeIfPresent(PixelFormatContract.self, forKey: .pixelFormat) ?? .preserveInput
        let primaryAttachment = storedAttachments?.first ?? RenderOutputAttachmentContract(
            index: 0,
            semantic: .primaryColor,
            alpha: alpha,
            colorSpace: colorSpace,
            pixelFormat: pixelFormat
        )

        self.init(
            inputAlphaExpectation: inputAlphaExpectation,
            alpha: primaryAttachment.alpha,
            colorSpace: primaryAttachment.colorSpace,
            pixelFormat: primaryAttachment.pixelFormat,
            additionalAttachments: Array((storedAttachments ?? [primaryAttachment]).dropFirst()),
            colorTransferPolicy: colorTransferPolicy,
            pixelFormatFallbackPolicy: pixelFormatFallbackPolicy,
            allowsLossyConversion: allowsLossyConversion,
            preservesOrientation: preservesOrientation
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(inputAlphaExpectation, forKey: .inputAlphaExpectation)
        try container.encode(alpha, forKey: .alpha)
        try container.encode(colorSpace, forKey: .colorSpace)
        try container.encode(pixelFormat, forKey: .pixelFormat)
        try container.encode(attachments, forKey: .attachments)
        try container.encode(colorTransferPolicy, forKey: .colorTransferPolicy)
        try container.encode(pixelFormatFallbackPolicy, forKey: .pixelFormatFallbackPolicy)
        try container.encode(allowsLossyConversion, forKey: .allowsLossyConversion)
        try container.encode(preservesOrientation, forKey: .preservesOrientation)
    }

    private static func normalizeAttachments(primary: RenderOutputAttachmentContract,
                                             additional: [RenderOutputAttachmentContract]) -> [RenderOutputAttachmentContract] {
        let combined = [primary] + additional
        let normalized = combined.map { attachment in
            RenderOutputAttachmentContract(
                index: max(attachment.index, 0),
                semantic: attachment.index == 0 ? .primaryColor : attachment.semantic,
                alpha: attachment.alpha,
                colorSpace: attachment.colorSpace,
                pixelFormat: attachment.pixelFormat
            )
        }.sorted { lhs, rhs in
            if lhs.index == rhs.index {
                return lhs.fingerprint < rhs.fingerprint
            }
            return lhs.index < rhs.index
        }
        var seen = Set<Int>()
        var result: [RenderOutputAttachmentContract] = []
        for attachment in normalized where seen.insert(attachment.index).inserted {
            result.append(attachment)
        }
        return result.isEmpty ? [RenderOutputAttachmentContract(index: 0)] : result
    }
}

public struct RenderOutputAttachmentContract: Sendable, Codable, Equatable, Hashable {
    public let index: Int
    public let semantic: RenderOutputAttachmentSemantic
    public let alpha: ImageAlphaContract
    public let colorSpace: ImageColorSpaceContract
    public let pixelFormat: PixelFormatContract

    public init(index: Int,
                semantic: RenderOutputAttachmentSemantic = .primaryColor,
                alpha: ImageAlphaContract = .preserveInput,
                colorSpace: ImageColorSpaceContract = .preserveInput,
                pixelFormat: PixelFormatContract = .preserveInput) {
        self.index = max(index, 0)
        self.semantic = semantic
        self.alpha = alpha
        self.colorSpace = colorSpace
        self.pixelFormat = pixelFormat
    }

    public var carriesAuxiliaryData: Bool {
        semantic != .primaryColor
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

    public var debugPolicy: RenderOutputAttachmentDebugPolicy {
        RenderOutputAttachmentDebugPolicy(
            label: semantic.defaultDebugLabel(for: index),
            interpretation: semantic.debugInterpretation,
            preferredReadbackPixelFormat: semantic.preferredReadbackPixelFormat(
                declared: pixelFormat
            ),
            preservesDynamicRange: semantic.preservesDynamicRange(declared: pixelFormat),
            prefersMonochromePreview: semantic.prefersMonochromePreview
        )
    }

    public var fingerprint: String {
        [
            "attachment=\(index)",
            "semantic=\(semantic.rawValue)",
            "alpha=\(alpha)",
            colorSpace.fingerprint,
            pixelFormat.fingerprint
        ].joined(separator: "|")
    }

    enum CodingKeys: String, CodingKey {
        case index
        case semantic
        case alpha
        case colorSpace
        case pixelFormat
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let index = try container.decode(Int.self, forKey: .index)
        let semantic = try container.decodeIfPresent(RenderOutputAttachmentSemantic.self, forKey: .semantic)
            ?? (index == 0 ? .primaryColor : .auxiliaryColor)
        let alpha = try container.decodeIfPresent(ImageAlphaContract.self, forKey: .alpha) ?? .preserveInput
        let colorSpace = try container.decodeIfPresent(ImageColorSpaceContract.self, forKey: .colorSpace) ?? .preserveInput
        let pixelFormat = try container.decodeIfPresent(PixelFormatContract.self, forKey: .pixelFormat) ?? .preserveInput
        self.init(index: index, semantic: semantic, alpha: alpha, colorSpace: colorSpace, pixelFormat: pixelFormat)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(semantic, forKey: .semantic)
        try container.encode(alpha, forKey: .alpha)
        try container.encode(colorSpace, forKey: .colorSpace)
        try container.encode(pixelFormat, forKey: .pixelFormat)
    }

    public static func auxiliaryColor(index: Int,
                                      alpha: ImageAlphaContract = .preserveInput,
                                      colorSpace: ImageColorSpaceContract = .preserveInput,
                                      pixelFormat: PixelFormatContract = .preserveInput) -> RenderOutputAttachmentContract {
        RenderOutputAttachmentContract(
            index: index,
            semantic: .auxiliaryColor,
            alpha: alpha,
            colorSpace: colorSpace,
            pixelFormat: pixelFormat
        )
    }

    public static func maskCoverage(index: Int, pixelFormat: PixelFormatContract = .rgba8Unorm) -> RenderOutputAttachmentContract {
        RenderOutputAttachmentContract(
            index: index,
            semantic: .maskCoverage,
            alpha: .opaque,
            colorSpace: .sRGB,
            pixelFormat: pixelFormat
        )
    }

    public static func luminance(index: Int, pixelFormat: PixelFormatContract = .rgba8Unorm) -> RenderOutputAttachmentContract {
        RenderOutputAttachmentContract(
            index: index,
            semantic: .luminance,
            alpha: .opaque,
            colorSpace: .sRGB,
            pixelFormat: pixelFormat
        )
    }

    public static func analysis(index: Int, pixelFormat: PixelFormatContract = .rgba8Unorm) -> RenderOutputAttachmentContract {
        RenderOutputAttachmentContract(
            index: index,
            semantic: .analysis,
            alpha: .opaque,
            colorSpace: .sRGB,
            pixelFormat: pixelFormat
        )
    }

    public static func histogram(index: Int, pixelFormat: PixelFormatContract = .rgba16Float) -> RenderOutputAttachmentContract {
        RenderOutputAttachmentContract(
            index: index,
            semantic: .histogram,
            alpha: .opaque,
            colorSpace: .extendedLinearSRGB,
            pixelFormat: pixelFormat
        )
    }
}

public enum RenderOutputAttachmentSemantic: String, Sendable, Codable, Equatable, Hashable {
    case primaryColor
    case auxiliaryColor
    case maskCoverage
    case luminance
    case histogram
    case analysis
    case debug

    fileprivate var debugInterpretation: RenderOutputAttachmentDebugInterpretation {
        switch self {
        case .primaryColor, .auxiliaryColor, .debug:
            return .color
        case .maskCoverage, .luminance:
            return .monochrome
        case .histogram, .analysis:
            return .scalarField
        }
    }

    fileprivate var prefersMonochromePreview: Bool {
        switch self {
        case .maskCoverage, .luminance, .histogram:
            return true
        case .primaryColor, .auxiliaryColor, .analysis, .debug:
            return false
        }
    }

    fileprivate func preferredReadbackPixelFormat(declared: PixelFormatContract) -> PixelFormatContract {
        switch self {
        case .maskCoverage, .luminance:
            return .rgba8Unorm
        case .histogram:
            return declared.preservesInput ? .rgba16Float : declared
        case .analysis:
            if declared.isHighPrecision {
                return declared
            }
            return declared.preservesInput ? .rgba8Unorm : declared
        case .primaryColor, .auxiliaryColor, .debug:
            return declared.preservesInput ? .rgba8Unorm : declared
        }
    }

    fileprivate func preservesDynamicRange(declared: PixelFormatContract) -> Bool {
        switch self {
        case .histogram:
            return true
        case .primaryColor, .auxiliaryColor, .analysis, .debug:
            return declared.isHighPrecision
        case .maskCoverage, .luminance:
            return false
        }
    }

    fileprivate func defaultDebugLabel(for index: Int) -> String {
        switch self {
        case .primaryColor:
            return "primaryColor"
        case .auxiliaryColor:
            return "auxiliaryColor\(index)"
        case .maskCoverage:
            return "maskCoverage"
        case .luminance:
            return "luminance"
        case .histogram:
            return "histogram"
        case .analysis:
            return "analysis"
        case .debug:
            return "debug\(index)"
        }
    }
}

public struct RenderOutputAttachmentDebugPolicy: Sendable, Codable, Equatable, Hashable {
    public let label: String
    public let interpretation: RenderOutputAttachmentDebugInterpretation
    public let preferredReadbackPixelFormat: PixelFormatContract
    public let preservesDynamicRange: Bool
    public let prefersMonochromePreview: Bool

    public init(label: String,
                interpretation: RenderOutputAttachmentDebugInterpretation,
                preferredReadbackPixelFormat: PixelFormatContract,
                preservesDynamicRange: Bool,
                prefersMonochromePreview: Bool) {
        self.label = label
        self.interpretation = interpretation
        self.preferredReadbackPixelFormat = preferredReadbackPixelFormat
        self.preservesDynamicRange = preservesDynamicRange
        self.prefersMonochromePreview = prefersMonochromePreview
    }
}

public enum RenderOutputAttachmentDebugInterpretation: String, Sendable, Codable, Equatable, Hashable {
    case color
    case monochrome
    case scalarField
}

public enum ColorTransferPolicy: String, Sendable, Codable, Equatable, Hashable {
    case automatic
    case preserveInput
    case convertToOutput
}

public enum PixelFormatFallbackPolicy: String, Sendable, Codable, Equatable, Hashable {
    case preserveInput
    case nearestSupported
    case exactRequired
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
    case directPlaneTexture
    case cgImageFallback
    case cpuCopyFallback
}

public enum PixelBufferBridgePolicy: String, Sendable, Codable, Equatable, Hashable {
    case directTexturePassthrough
    case directPlanePassthrough
    case directPlaneDecodeToRGBA
    case cgImageMaterialization
    case cpuCopyMaterialization
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

public struct PixelBufferPlaneBridgeDescriptor: Sendable, Codable, Equatable, Hashable {
    public let index: Int
    public let metalPixelFormatRawValue: UInt?
    public let conversionStrategy: PixelBufferTextureLoadStrategy
    public let preservesOwnerReference: Bool

    public init(index: Int,
                metalPixelFormat: MTLPixelFormat?,
                conversionStrategy: PixelBufferTextureLoadStrategy,
                preservesOwnerReference: Bool) {
        self.index = index
        self.metalPixelFormatRawValue = metalPixelFormat?.rawValue
        self.conversionStrategy = conversionStrategy
        self.preservesOwnerReference = preservesOwnerReference
    }

    public var metalPixelFormat: MTLPixelFormat? {
        metalPixelFormatRawValue.flatMap(MTLPixelFormat.init(rawValue:))
    }

    public var fingerprint: String {
        [
            "plane=\(index)",
            "metal=\(metalPixelFormatRawValue.map(String.init) ?? "none")",
            "strategy=\(conversionStrategy.rawValue)",
            "owner=\(preservesOwnerReference ? 1 : 0)"
        ].joined(separator: "|")
    }
}

public enum YCbCrMatrixAttachment: String, Sendable, Codable, Equatable, Hashable {
    case ituR601_4
    case ituR709_2
    case ituR2020
    case smpte240M_1995

    public var imageColorGamut: ImageColorGamut {
        switch self {
        case .ituR2020:
            return .ituR2020
        case .ituR601_4, .ituR709_2, .smpte240M_1995:
            return .sRGB
        }
    }

    public var fallbackColorPrimariesAttachment: ColorPrimariesAttachment? {
        switch self {
        case .ituR2020:
            return .ituR2020
        case .ituR709_2:
            return .ituR709_2
        case .ituR601_4, .smpte240M_1995:
            return nil
        }
    }
}

public enum ColorPrimariesAttachment: String, Sendable, Codable, Equatable, Hashable {
    case ituR709_2
    case ituR2020
    case p3D65
    case ebu3213
    case smpteC

    public var imageColorGamut: ImageColorGamut {
        switch self {
        case .ituR2020:
            return .ituR2020
        case .p3D65:
            return .displayP3
        case .ituR709_2, .ebu3213, .smpteC:
            return .sRGB
        }
    }
}

public enum ColorTransferAttachment: String, Sendable, Codable, Equatable, Hashable {
    case ituR709_2
    case linear
    case sRGB
    case smpteSt2084PQ
    case ituR2100HLG
    case useGamma

    public var imageTransferFunction: ImageTransferFunction {
        switch self {
        case .linear:
            return .linear
        case .smpteSt2084PQ:
            return .perceptualQuantizer
        case .ituR2100HLG:
            return .hybridLogGamma
        case .ituR709_2, .sRGB, .useGamma:
            return .sRGB
        }
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
    public let yCbCrMatrixAttachment: YCbCrMatrixAttachment?
    public let colorPrimariesAttachment: ColorPrimariesAttachment?
    public let transferFunctionAttachment: ColorTransferAttachment?
    public let planes: [PixelBufferPlaneContract]

    public init(width: Int,
                height: Int,
                cvPixelFormatType: OSType,
                planeCount: Int,
                planar: Bool,
                colorModel: PixelBufferColorModel,
                nativeTextureLayout: PixelBufferNativeTextureLayout,
                yCbCrMatrixAttachment: YCbCrMatrixAttachment? = nil,
                colorPrimariesAttachment: ColorPrimariesAttachment? = nil,
                transferFunctionAttachment: ColorTransferAttachment? = nil,
                planes: [PixelBufferPlaneContract]) {
        self.width = width
        self.height = height
        self.cvPixelFormatType = cvPixelFormatType
        self.planeCount = planeCount
        self.planar = planar
        self.colorModel = colorModel
        self.nativeTextureLayout = nativeTextureLayout
        self.yCbCrMatrixAttachment = yCbCrMatrixAttachment
        self.colorPrimariesAttachment = colorPrimariesAttachment
        self.transferFunctionAttachment = transferFunctionAttachment
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

    public var supportsDirectPlaneTextures: Bool {
        planeCount > 1 && planes.allSatisfy { $0.metalPixelFormat != nil }
    }

    public var attachmentColorSpace: ImageColorSpaceContract? {
        guard colorPrimariesAttachment != nil || transferFunctionAttachment != nil || yCbCrMatrixAttachment != nil else {
            return nil
        }
        let gamut = colorPrimariesAttachment?.imageColorGamut
            ?? yCbCrMatrixAttachment?.imageColorGamut
            ?? .custom
        let transferFunction = transferFunctionAttachment?.imageTransferFunction ?? .custom
        let name = [
            colorPrimariesAttachment?.rawValue ?? yCbCrMatrixAttachment?.rawValue,
            transferFunctionAttachment?.rawValue
        ]
        .compactMap { $0 }
        .joined(separator: "+")
        return ImageColorSpaceContract(
            name: name.isEmpty ? "attachmentDerived" : name,
            preservesInput: false,
            gamut: gamut,
            transferFunction: transferFunction
        )
    }

    public var fingerprint: String {
        [
            "size=\(width)x\(height)",
            "cv=\(cvPixelFormatType)",
            "planes=\(planeCount)",
            "planar=\(planar ? 1 : 0)",
            "model=\(colorModel.rawValue)",
            "layout=\(nativeTextureLayout.rawValue)",
            "ycbcrAttachment=\(yCbCrMatrixAttachment?.rawValue ?? "none")",
            "primaries=\(colorPrimariesAttachment?.rawValue ?? "none")",
            "transferAttachment=\(transferFunctionAttachment?.rawValue ?? "none")",
            planes.map(\.fingerprint).joined(separator: "||")
        ].joined(separator: "|")
    }
}

public struct PixelBufferTextureBridgePlan: Sendable, Codable, Equatable, Hashable {
    public let contract: PixelBufferContract
    public let loadStrategy: PixelBufferTextureLoadStrategy
    public let preservesOwnerReference: Bool
    public let planes: [PixelBufferPlaneBridgeDescriptor]

    public init(contract: PixelBufferContract,
                loadStrategy: PixelBufferTextureLoadStrategy,
                preservesOwnerReference: Bool,
                planes: [PixelBufferPlaneBridgeDescriptor] = []) {
        self.contract = contract
        self.loadStrategy = loadStrategy
        self.preservesOwnerReference = preservesOwnerReference
        self.planes = planes
    }

    public var requiresColorConversion: Bool {
        contract.requiresYCbCrConversion
    }

    public var directPlaneBridgeCount: Int {
        planes.filter { $0.conversionStrategy == .directMetalTexture }.count
    }

    public var supportsDirectPlaneTextures: Bool {
        directPlaneBridgeCount == contract.planeCount && contract.planeCount > 1
    }

    public var primaryDirectPlane: PixelBufferPlaneBridgeDescriptor? {
        planes.first { $0.conversionStrategy == .directMetalTexture }
    }

    public var fingerprint: String {
        [
            contract.fingerprint,
            "load=\(loadStrategy.rawValue)",
            "owner=\(preservesOwnerReference ? 1 : 0)",
            "planes=\(planes.map(\.fingerprint).joined(separator: "||"))"
        ].joined(separator: "|")
    }
}

public enum YCbCrDecodeMatrix: String, Sendable, Codable, Equatable, Hashable {
    case bt601VideoRange
    case bt601FullRange
    case bt709VideoRange
    case bt709FullRange
    case bt2020VideoRange
    case bt2020FullRange
}

public enum YCbCrPlaneLayout: String, Sendable, Codable, Equatable, Hashable {
    case biPlanar
    case triPlanar
}

public struct YCbCrDecodeContract: Sendable, Codable, Equatable, Hashable {
    public let layout: YCbCrPlaneLayout
    public let matrix: YCbCrDecodeMatrix
    public let componentBitDepth: Int
    public let destinationPixelFormatRawValue: UInt

    public init(layout: YCbCrPlaneLayout,
                matrix: YCbCrDecodeMatrix,
                componentBitDepth: Int = 8,
                destinationPixelFormat: MTLPixelFormat) {
        self.layout = layout
        self.matrix = matrix
        self.componentBitDepth = componentBitDepth
        self.destinationPixelFormatRawValue = destinationPixelFormat.rawValue
    }

    public var destinationPixelFormat: MTLPixelFormat? {
        MTLPixelFormat(rawValue: destinationPixelFormatRawValue)
    }

    public var fingerprint: String {
        [
            "layout=\(layout.rawValue)",
            "matrix=\(matrix.rawValue)",
            "bitDepth=\(componentBitDepth)",
            "destPixel=\(destinationPixelFormatRawValue)"
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
    public let frameContract: SampleBufferFrameContract
    public let attachments: SampleAttachmentContract

    public init(numSamples: Int,
                isValid: Bool,
                presentationTimeStamp: TimeValueContract,
                decodeTimeStamp: TimeValueContract,
                duration: TimeValueContract,
                formatDescriptionMediaType: FourCharCode?,
                formatDescriptionMediaSubType: FourCharCode?,
                pixelBufferContract: PixelBufferContract?,
                frameContract: SampleBufferFrameContract,
                attachments: SampleAttachmentContract) {
        self.numSamples = numSamples
        self.isValid = isValid
        self.presentationTimeStamp = presentationTimeStamp
        self.decodeTimeStamp = decodeTimeStamp
        self.duration = duration
        self.formatDescriptionMediaType = formatDescriptionMediaType
        self.formatDescriptionMediaSubType = formatDescriptionMediaSubType
        self.pixelBufferContract = pixelBufferContract
        self.frameContract = frameContract
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
            "frame={\(frameContract.fingerprint)}",
            attachments.fingerprint,
            pixelBufferContract.map { "pixelBuffer={\($0.fingerprint)}" } ?? "pixelBuffer=none"
        ].joined(separator: "|")
    }
}

public struct SampleBufferFrameContract: Sendable, Codable, Equatable, Hashable {
    public let ownerRetained: Bool
    public let conversionStrategy: PixelBufferTextureLoadStrategy?
    public let directPlaneBridgeCount: Int
    public let orientation: FrameOrientation
    public let mirrorHorizontally: Bool
    public let mirrorVertically: Bool
    public let followsDeviceOrientation: Bool
    public let hasExplicitOrientation: Bool
    public let hasExplicitMirror: Bool
    public let hasExplicitDeviceOrientation: Bool

    public init(ownerRetained: Bool,
                conversionStrategy: PixelBufferTextureLoadStrategy?,
                directPlaneBridgeCount: Int = 0,
                orientation: FrameOrientation = .up,
                mirrorHorizontally: Bool = false,
                mirrorVertically: Bool = false,
                followsDeviceOrientation: Bool = false,
                hasExplicitOrientation: Bool = false,
                hasExplicitMirror: Bool = false,
                hasExplicitDeviceOrientation: Bool = false) {
        self.ownerRetained = ownerRetained
        self.conversionStrategy = conversionStrategy
        self.directPlaneBridgeCount = directPlaneBridgeCount
        self.orientation = orientation
        self.mirrorHorizontally = mirrorHorizontally
        self.mirrorVertically = mirrorVertically
        self.followsDeviceOrientation = followsDeviceOrientation
        self.hasExplicitOrientation = hasExplicitOrientation
        self.hasExplicitMirror = hasExplicitMirror
        self.hasExplicitDeviceOrientation = hasExplicitDeviceOrientation
    }

    public var supportsDirectPlaneTextures: Bool {
        directPlaneBridgeCount > 1
    }

    public var fingerprint: String {
        [
            "owner=\(ownerRetained ? 1 : 0)",
            "strategy=\(conversionStrategy?.rawValue ?? "none")",
            "directPlanes=\(directPlaneBridgeCount)",
            "orientation=\(orientation.rawValue)",
            "mirrorH=\(mirrorHorizontally ? 1 : 0)",
            "mirrorV=\(mirrorVertically ? 1 : 0)",
            "followDevice=\(followsDeviceOrientation ? 1 : 0)",
            "hasOrientation=\(hasExplicitOrientation ? 1 : 0)",
            "hasMirror=\(hasExplicitMirror ? 1 : 0)",
            "hasDeviceOrientation=\(hasExplicitDeviceOrientation ? 1 : 0)"
        ].joined(separator: "|")
    }
}

public struct FrameHostMetadataCompleteness: Sendable, Codable, Equatable, Hashable {
    public let hasFrameSize: Bool
    public let hasOrientation: Bool
    public let hasMirror: Bool
    public let hasDeviceOrientation: Bool
    public let hasTiming: Bool
    public let hasSampleAttachments: Bool

    public init(hasFrameSize: Bool,
                hasOrientation: Bool,
                hasMirror: Bool,
                hasDeviceOrientation: Bool,
                hasTiming: Bool,
                hasSampleAttachments: Bool) {
        self.hasFrameSize = hasFrameSize
        self.hasOrientation = hasOrientation
        self.hasMirror = hasMirror
        self.hasDeviceOrientation = hasDeviceOrientation
        self.hasTiming = hasTiming
        self.hasSampleAttachments = hasSampleAttachments
    }

    public var isCompleteForRealtimePreview: Bool {
        hasFrameSize && hasTiming
    }

    public var fingerprint: String {
        [
            "frameSize=\(hasFrameSize ? 1 : 0)",
            "orientation=\(hasOrientation ? 1 : 0)",
            "mirror=\(hasMirror ? 1 : 0)",
            "deviceOrientation=\(hasDeviceOrientation ? 1 : 0)",
            "timing=\(hasTiming ? 1 : 0)",
            "attachments=\(hasSampleAttachments ? 1 : 0)"
        ].joined(separator: "|")
    }
}

public struct FrameHostSourceDescriptor: Sendable, Codable, Equatable, Hashable {
    public let frameSize: C7Size
    public let orientation: FrameOrientation
    public let mirrorHorizontally: Bool
    public let mirrorVertically: Bool
    public let followsDeviceOrientation: Bool
    public let directPlaneBridgeCount: Int
    public let bridgePolicy: PixelBufferBridgePolicy?
    public let yCbCrDecodeContract: YCbCrDecodeContract?
    public let metadataCompleteness: FrameHostMetadataCompleteness

    public init(frameSize: C7Size,
                orientation: FrameOrientation,
                mirrorHorizontally: Bool = false,
                mirrorVertically: Bool = false,
                followsDeviceOrientation: Bool = false,
                directPlaneBridgeCount: Int = 0,
                bridgePolicy: PixelBufferBridgePolicy? = nil,
                yCbCrDecodeContract: YCbCrDecodeContract? = nil,
                metadataCompleteness: FrameHostMetadataCompleteness) {
        self.frameSize = frameSize
        self.orientation = orientation
        self.mirrorHorizontally = mirrorHorizontally
        self.mirrorVertically = mirrorVertically
        self.followsDeviceOrientation = followsDeviceOrientation
        self.directPlaneBridgeCount = directPlaneBridgeCount
        self.bridgePolicy = bridgePolicy
        self.yCbCrDecodeContract = yCbCrDecodeContract
        self.metadataCompleteness = metadataCompleteness
    }

    public var fingerprint: String {
        [
            "size=\(frameSize.width)x\(frameSize.height)",
            "orientation=\(orientation.rawValue)",
            "mirrorH=\(mirrorHorizontally ? 1 : 0)",
            "mirrorV=\(mirrorVertically ? 1 : 0)",
            "followDevice=\(followsDeviceOrientation ? 1 : 0)",
            "directPlanes=\(directPlaneBridgeCount)",
            "bridgePolicy=\(bridgePolicy?.rawValue ?? "none")",
            "ycbcr=\(yCbCrDecodeContract?.fingerprint ?? "none")",
            "completeness={\(metadataCompleteness.fingerprint)}"
        ].joined(separator: "|")
    }
}

public enum PreviewHostRenderingDecision: String, Sendable, Codable, Equatable, Hashable {
    case directTexturePassthrough
    case directPlanePassthrough
    case directPlaneDecodeToRGBA
    case materializedFallback
}

public enum PreviewHostTimingPolicy: String, Sendable, Codable, Equatable, Hashable {
    case lowLatency
    case displayStable
    case completedGPUReadback
}

public struct FrameHostRuntimeHint: Sendable, Codable, Equatable, Hashable {
    public let decision: PreviewHostRenderingDecision
    public let timingPolicy: PreviewHostTimingPolicy
    public let isRealtimePreviewEligible: Bool
    public let supportsVisibilityPause: Bool
    public let requiresPlaneAwareDecode: Bool
    public let metadataCompleteness: FrameHostMetadataCompleteness

    public init(decision: PreviewHostRenderingDecision,
                timingPolicy: PreviewHostTimingPolicy,
                isRealtimePreviewEligible: Bool,
                supportsVisibilityPause: Bool,
                requiresPlaneAwareDecode: Bool,
                metadataCompleteness: FrameHostMetadataCompleteness) {
        self.decision = decision
        self.timingPolicy = timingPolicy
        self.isRealtimePreviewEligible = isRealtimePreviewEligible
        self.supportsVisibilityPause = supportsVisibilityPause
        self.requiresPlaneAwareDecode = requiresPlaneAwareDecode
        self.metadataCompleteness = metadataCompleteness
    }

    public var fingerprint: String {
        [
            "decision=\(decision.rawValue)",
            "timing=\(timingPolicy.rawValue)",
            "realtime=\(isRealtimePreviewEligible ? 1 : 0)",
            "visibilityPause=\(supportsVisibilityPause ? 1 : 0)",
            "planeAwareDecode=\(requiresPlaneAwareDecode ? 1 : 0)",
            "completeness={\(metadataCompleteness.fingerprint)}"
        ].joined(separator: "|")
    }
}

/// 图像采样合同，用于 lazy graph、render diagnostics 和 sampler cache。
public struct ImageSamplerDescriptor: Sendable, Codable, Equatable, Hashable {
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

    private enum CodingKeys: String, CodingKey {
        case minFilter
        case magFilter
        case mipFilter
        case sAddressMode
        case tAddressMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            minFilter: MTLSamplerMinMagFilter(rawValue: try container.decode(UInt.self, forKey: .minFilter)) ?? .linear,
            magFilter: MTLSamplerMinMagFilter(rawValue: try container.decode(UInt.self, forKey: .magFilter)) ?? .linear,
            mipFilter: MTLSamplerMipFilter(rawValue: try container.decode(UInt.self, forKey: .mipFilter)) ?? .notMipmapped,
            sAddressMode: MTLSamplerAddressMode(rawValue: try container.decode(UInt.self, forKey: .sAddressMode)) ?? .clampToEdge,
            tAddressMode: MTLSamplerAddressMode(rawValue: try container.decode(UInt.self, forKey: .tAddressMode)) ?? .clampToEdge
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(minFilter.rawValue, forKey: .minFilter)
        try container.encode(magFilter.rawValue, forKey: .magFilter)
        try container.encode(mipFilter.rawValue, forKey: .mipFilter)
        try container.encode(sAddressMode.rawValue, forKey: .sAddressMode)
        try container.encode(tAddressMode.rawValue, forKey: .tAddressMode)
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

public struct ImageSourceDescriptor: Sendable, Hashable, Codable {
    public let kind: String
    public let sourceTier: ImageSourceTier
    public let alphaType: AlphaType
    public let orientation: FrameOrientation
    public let cachePolicy: ImageCachePolicy
    public let semantic: ImageSemanticDescriptor
    public let loadingOptions: ImageLoadingOptions
    public let pixelBufferContract: PixelBufferContract?
    public let pixelBufferBridgePlan: PixelBufferTextureBridgePlan?
    public let pixelBufferBridgePolicy: PixelBufferBridgePolicy?
    public let yCbCrDecodeContract: YCbCrDecodeContract?
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
                pixelBufferBridgePolicy: PixelBufferBridgePolicy? = nil,
                yCbCrDecodeContract: YCbCrDecodeContract? = nil,
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
        self.pixelBufferBridgePolicy = pixelBufferBridgePolicy
        self.yCbCrDecodeContract = yCbCrDecodeContract
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
        if let pixelBufferBridgePolicy {
            parts.append("bridgePolicy=\(pixelBufferBridgePolicy.rawValue)")
        }
        if let yCbCrDecodeContract {
            parts.append("ycbcrDecode={\(yCbCrDecodeContract.fingerprint)}")
        }
        if let sampleBufferContract {
            parts.append("sampleBuffer={\(sampleBufferContract.fingerprint)}")
        }
        return parts.joined(separator: "|")
    }

    public var frameHostSourceDescriptor: FrameHostSourceDescriptor {
        let size = C7Size(
            width: sampleBufferContract?.pixelBufferContract?.width
                ?? pixelBufferContract?.width
                ?? 0,
            height: sampleBufferContract?.pixelBufferContract?.height
                ?? pixelBufferContract?.height
                ?? 0
        )
        let sampleFrameContract = sampleBufferContract?.frameContract
        let completeness = FrameHostMetadataCompleteness(
            hasFrameSize: size.width > 0 && size.height > 0,
            hasOrientation: sampleFrameContract?.hasExplicitOrientation ?? false,
            hasMirror: sampleFrameContract?.hasExplicitMirror ?? false,
            hasDeviceOrientation: sampleFrameContract?.hasExplicitDeviceOrientation ?? false,
            hasTiming: sampleBufferContract.map {
                $0.presentationTimeStamp.isValid || $0.decodeTimeStamp.isValid || $0.duration.isValid
            } ?? false,
            hasSampleAttachments: sampleBufferContract.map {
                $0.attachments.notSync != nil
                    || $0.attachments.dependsOnOthers != nil
                    || $0.attachments.earlierDisplayTimesAllowed != nil
                    || $0.attachments.displayImmediately != nil
                    || $0.attachments.doNotDisplay != nil
            } ?? false
        )
        return FrameHostSourceDescriptor(
            frameSize: size,
            orientation: sampleFrameContract?.orientation ?? orientation,
            mirrorHorizontally: sampleFrameContract?.mirrorHorizontally ?? false,
            mirrorVertically: sampleFrameContract?.mirrorVertically ?? false,
            followsDeviceOrientation: sampleFrameContract?.followsDeviceOrientation ?? false,
            directPlaneBridgeCount: sampleFrameContract?.directPlaneBridgeCount
                ?? pixelBufferBridgePlan?.directPlaneBridgeCount
                ?? 0,
            bridgePolicy: pixelBufferBridgePolicy,
            yCbCrDecodeContract: yCbCrDecodeContract,
            metadataCompleteness: completeness
        )
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
    var defaultFrameHostTimingPolicy: PreviewHostTimingPolicy {
        switch self {
        case .interactiveLatency, .responseLatency:
            return .lowLatency
        case .stablePreview, .inspectionQuality:
            return .displayStable
        case .exportQuality, .readbackQuality:
            return .completedGPUReadback
        }
    }

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

public extension FrameHostRuntimeHint {
    init(source: ImageSourceDescriptor, profile: RenderProfile) {
        let hostSource = source.frameHostSourceDescriptor
        let decision: PreviewHostRenderingDecision
        switch hostSource.bridgePolicy {
        case .directTexturePassthrough, .none:
            decision = .directTexturePassthrough
        case .directPlanePassthrough:
            decision = .directPlanePassthrough
        case .directPlaneDecodeToRGBA:
            decision = .directPlaneDecodeToRGBA
        case .cgImageMaterialization, .cpuCopyMaterialization:
            decision = .materializedFallback
        }
        let timingPolicy = profile.defaultFrameHostTimingPolicy
        let requiresPlaneAwareDecode = hostSource.yCbCrDecodeContract != nil || hostSource.bridgePolicy == .directPlaneDecodeToRGBA
        let isRealtimePreviewEligible = timingPolicy != .completedGPUReadback
            && decision != .materializedFallback
            && hostSource.metadataCompleteness.hasFrameSize
        self.init(
            decision: decision,
            timingPolicy: timingPolicy,
            isRealtimePreviewEligible: isRealtimePreviewEligible,
            supportsVisibilityPause: isRealtimePreviewEligible,
            requiresPlaneAwareDecode: requiresPlaneAwareDecode,
            metadataCompleteness: hostSource.metadataCompleteness
        )
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
public struct ImageAsset: @unchecked Sendable {
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
