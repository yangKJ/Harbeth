//
//  TextureRegionDiagnostics.swift
//  Harbeth
//
//  Created by Condy on 2026/7/10.
//

import CoreGraphics
import Foundation

public struct TextureDiagnosticRect: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(_ rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }
}

public enum TextureRegionExecutionStatus: String, Codable, Equatable, Sendable {
    case completed
    case cancelled
    case failed
}

/// 只描述区域执行机械信息，不携带任何产品成功率或算法指标。
public struct TextureRegionDiagnostics: Codable, Equatable, Sendable {
    public let logicalExtent: TextureDiagnosticRect?
    public let readRegion: TextureDiagnosticRect?
    public let writeRegion: TextureDiagnosticRect?
    public let footprint: String
    public let haloRadius: Int?
    public let inputSize: C7Size
    public let outputSize: C7Size
    public let inputPixelFormat: UInt64
    public let outputPixelFormat: UInt64
    public let allocatedTextureCount: Int
    public let estimatedByteCount: Int
    public let passCount: Int
    public let durationMilliseconds: Double?
    public let readbackOccurred: Bool
    public let status: TextureRegionExecutionStatus
    public let failedStage: Int?

    public init(logicalExtent: CGRect?,
                readRegion: CGRect?,
                writeRegion: CGRect?,
                footprint: SamplingFootprint,
                inputSize: C7Size,
                outputSize: C7Size,
                inputPixelFormat: UInt64,
                outputPixelFormat: UInt64,
                allocatedTextureCount: Int,
                estimatedByteCount: Int,
                passCount: Int,
                durationMilliseconds: Double?,
                readbackOccurred: Bool,
                status: TextureRegionExecutionStatus,
                failedStage: Int? = nil) {
        self.logicalExtent = logicalExtent.map(TextureDiagnosticRect.init)
        self.readRegion = readRegion.map(TextureDiagnosticRect.init)
        self.writeRegion = writeRegion.map(TextureDiagnosticRect.init)
        self.footprint = footprint.diagnosticName
        self.haloRadius = footprint.haloRadius
        self.inputSize = inputSize
        self.outputSize = outputSize
        self.inputPixelFormat = inputPixelFormat
        self.outputPixelFormat = outputPixelFormat
        self.allocatedTextureCount = max(allocatedTextureCount, 0)
        self.estimatedByteCount = max(estimatedByteCount, 0)
        self.passCount = max(passCount, 0)
        self.durationMilliseconds = durationMilliseconds
        self.readbackOccurred = readbackOccurred
        self.status = status
        self.failedStage = failedStage
    }
}

private extension SamplingFootprint {
    var diagnosticName: String {
        switch self {
        case .point:
            return "point"
        case .neighborhood(let radius):
            return "neighborhood(\(radius))"
        case .dynamic:
            return "dynamic"
        case .global:
            return "global"
        }
    }
}
