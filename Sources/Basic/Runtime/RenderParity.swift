//
//  RenderParity.swift
//  Harbeth
//
//  Created by Condy on 2026/7/28.
//

import Foundation

/// 预览与最终交付请求之间可比较的合同维度。
public enum RenderParityField: String, Sendable, Codable, Equatable, Hashable {
    case processing
    case sampler
    case inputColor
    case outputColor
    case inputAlpha
    case outputAlpha
    case colorTransfer
    case toneMapping
    case compilationSource
    case sourceKind
    case profile
    case renderIntent
    case derivative
    case inputPixelFormat
    case outputPixelFormat
    case outputAttachments
    case quantization
}

/// parity 偏差对视觉结果的影响层级。
public enum RenderParityImpact: String, Sendable, Codable, Equatable, Hashable {
    /// 会改变编辑内容、采样、色彩、Alpha 或 tone mapping，不能静默接受。
    case visual
    /// 只影响档位、尺寸、精度、附件或交付编码，可以由产品层显式接受。
    case delivery
}

public struct RenderParityDifference: Sendable, Codable, Equatable, Hashable {
    public let field: RenderParityField
    public let impact: RenderParityImpact
    public let baselineValue: String
    public let candidateValue: String

    public init(field: RenderParityField, impact: RenderParityImpact, baselineValue: String, candidateValue: String) {
        self.field = field
        self.impact = impact
        self.baselineValue = baselineValue
        self.candidateValue = candidateValue
    }
}

/// 单个 `RenderRequest` 的稳定预检签名。它不读取像素，也不会等待 GPU。
public struct RenderParitySignature: Sendable, Codable, Equatable, Hashable {
    public let processingFingerprint: String
    public let samplerFingerprint: String
    public let inputColorFingerprint: String
    public let outputColorFingerprint: String
    public let inputAlpha: String
    public let outputAlpha: String
    public let colorTransfer: String
    public let toneMapping: String
    public let compilationSource: RenderCompilationSource
    public let sourceKind: String
    public let profile: RenderProfile
    public let renderIntent: RenderIntent
    public let derivativeFingerprint: String
    public let inputPixelFormatFingerprint: String
    public let outputPixelFormatFingerprint: String
    public let outputAttachmentsFingerprint: String
    public let quantizationFingerprint: String

    public var fingerprint: String {
        [
            "processing={\(processingFingerprint)}",
            "sampler={\(samplerFingerprint)}",
            "inputColor={\(inputColorFingerprint)}",
            "outputColor={\(outputColorFingerprint)}",
            "inputAlpha=\(inputAlpha)",
            "outputAlpha=\(outputAlpha)",
            "transfer=\(colorTransfer)",
            "toneMap=\(toneMapping)",
            "source=\(compilationSource.rawValue):\(sourceKind)",
            "profile=\(profile.rawValue)",
            "intent=\(renderIntent.rawValue)",
            "derivative={\(derivativeFingerprint)}",
            "inputPixel={\(inputPixelFormatFingerprint)}",
            "outputPixel={\(outputPixelFormatFingerprint)}",
            "attachments={\(outputAttachmentsFingerprint)}",
            "quantization={\(quantizationFingerprint)}"
        ].joined(separator: "||")
    }

    public func report(comparedTo candidate: RenderParitySignature) -> RenderParityReport {
        var differences: [RenderParityDifference] = []
        compare(.processing, impact: .visual, processingFingerprint, candidate.processingFingerprint, into: &differences)
        compare(.sampler, impact: .visual, samplerFingerprint, candidate.samplerFingerprint, into: &differences)
        compare(.inputColor, impact: .visual, inputColorFingerprint, candidate.inputColorFingerprint, into: &differences)
        compare(.outputColor, impact: .visual, outputColorFingerprint, candidate.outputColorFingerprint, into: &differences)
        compare(.inputAlpha, impact: .visual, inputAlpha, candidate.inputAlpha, into: &differences)
        compare(.outputAlpha, impact: .visual, outputAlpha, candidate.outputAlpha, into: &differences)
        compare(.colorTransfer, impact: .visual, colorTransfer, candidate.colorTransfer, into: &differences)
        compare(.toneMapping, impact: .visual, toneMapping, candidate.toneMapping, into: &differences)
        compare(.compilationSource, impact: .delivery, compilationSource.rawValue, candidate.compilationSource.rawValue, into: &differences)
        compare(.sourceKind, impact: .delivery, sourceKind, candidate.sourceKind, into: &differences)
        compare(.profile, impact: .delivery, profile.rawValue, candidate.profile.rawValue, into: &differences)
        compare(.renderIntent, impact: .delivery, renderIntent.rawValue, candidate.renderIntent.rawValue, into: &differences)
        compare(.derivative, impact: .delivery, derivativeFingerprint, candidate.derivativeFingerprint, into: &differences)
        compare(.inputPixelFormat, impact: .delivery, inputPixelFormatFingerprint, candidate.inputPixelFormatFingerprint, into: &differences)
        compare(.outputPixelFormat, impact: .delivery, outputPixelFormatFingerprint, candidate.outputPixelFormatFingerprint, into: &differences)
        compare(.outputAttachments, impact: .delivery, outputAttachmentsFingerprint, candidate.outputAttachmentsFingerprint, into: &differences)
        compare(.quantization, impact: .delivery, quantizationFingerprint, candidate.quantizationFingerprint, into: &differences)
        return RenderParityReport(baseline: self, candidate: candidate, differences: differences)
    }

    private func compare(_ field: RenderParityField,
                         impact: RenderParityImpact,
                         _ baseline: String,
                         _ candidate: String,
                         into differences: inout [RenderParityDifference]) {
        guard baseline != candidate else { return }
        differences.append(
            RenderParityDifference(
                field: field,
                impact: impact,
                baselineValue: baseline,
                candidateValue: candidate
            )
        )
    }
}

/// 两个渲染请求的 parity 结论。`isVisuallyEquivalent` 允许合法的交付差异，
/// `isExactlyEquivalent` 则要求所有合同维度完全一致。
public struct RenderParityReport: Sendable, Codable, Equatable, Hashable {
    public let baseline: RenderParitySignature
    public let candidate: RenderParitySignature
    public let differences: [RenderParityDifference]

    public var visualDifferences: [RenderParityDifference] {
        differences.filter { $0.impact == .visual }
    }

    public var deliveryDifferences: [RenderParityDifference] {
        differences.filter { $0.impact == .delivery }
    }

    public var isVisuallyEquivalent: Bool {
        visualDifferences.isEmpty
    }

    public var isExactlyEquivalent: Bool {
        differences.isEmpty
    }
}

public extension RenderRequest {
    /// 在执行前生成完整的预览/导出一致性签名。
    var paritySignature: RenderParitySignature {
        let outputContract = diagnostics.outputContract
        return RenderParitySignature(
            processingFingerprint: renderRecipe?.processingFingerprint ?? diagnostics.graphFingerprint,
            samplerFingerprint: diagnostics.samplerDescriptor.fingerprint,
            inputColorFingerprint: diagnostics.inputColorSpace.fingerprint,
            outputColorFingerprint: diagnostics.outputColorSpace.fingerprint,
            inputAlpha: String(describing: outputContract.inputAlphaExpectation),
            outputAlpha: String(describing: outputContract.alpha),
            colorTransfer: outputContract.colorTransferPolicy.rawValue,
            toneMapping: outputContract.toneMappingPolicy.rawValue,
            compilationSource: compilationSource,
            sourceKind: source.kind,
            profile: profile,
            renderIntent: derivative.renderIntent,
            derivativeFingerprint: derivative.fingerprint,
            inputPixelFormatFingerprint: diagnostics.inputPixelFormat.fingerprint,
            outputPixelFormatFingerprint: diagnostics.outputPixelFormat.fingerprint,
            outputAttachmentsFingerprint: outputContract.attachments.map(\.fingerprint).joined(separator: "||"),
            quantizationFingerprint: outputContract.quantization.fingerprint
        )
    }

    func parityReport(comparedTo candidate: RenderRequest) -> RenderParityReport {
        paritySignature.report(comparedTo: candidate.paritySignature)
    }
}

public extension RenderedFrame {
    /// 由 `RenderRequest.renderFrame` 注入，便于产品层把实际交付帧关联回预检合同。
    var renderParityFingerprint: String? {
        metadata["renderParityFingerprint"]
    }
}
