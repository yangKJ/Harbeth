//
//  RenderResourceGovernance.swift
//  Harbeth
//
//  Created by Condy on 2026/7/28.
//

import Foundation
@preconcurrency import Metal

/// 单次渲染请求允许消耗的资源上限。nil 表示该维度不设上限。
public struct RenderResourceBudget: Sendable, Codable, Equatable, Hashable {
    public let maximumTransientBytes: Int?
    public let maximumPersistentBytes: Int?
    public let maximumTotalBytes: Int?
    public let maximumTextureCount: Int?
    public let maximumStageCount: Int?

    public init(maximumTransientBytes: Int? = nil,
                maximumPersistentBytes: Int? = nil,
                maximumTotalBytes: Int? = nil,
                maximumTextureCount: Int? = nil,
                maximumStageCount: Int? = nil) {
        self.maximumTransientBytes = maximumTransientBytes.map { max($0, 0) }
        self.maximumPersistentBytes = maximumPersistentBytes.map { max($0, 0) }
        self.maximumTotalBytes = maximumTotalBytes.map { max($0, 0) }
        self.maximumTextureCount = maximumTextureCount.map { max($0, 0) }
        self.maximumStageCount = maximumStageCount.map { max($0, 0) }
    }

    public static let unbounded = RenderResourceBudget()

    public var fingerprint: String {
        [
            "transient=\(maximumTransientBytes.map(String.init) ?? "unbounded")",
            "persistent=\(maximumPersistentBytes.map(String.init) ?? "unbounded")",
            "total=\(maximumTotalBytes.map(String.init) ?? "unbounded")",
            "textures=\(maximumTextureCount.map(String.init) ?? "unbounded")",
            "stages=\(maximumStageCount.map(String.init) ?? "unbounded")"
        ].joined(separator: "|")
    }
}

/// 编译阶段即可获得的请求级资源估算，不触发纹理分配。
public struct RenderResourceEstimate: Sendable, Codable, Equatable, Hashable {
    public let transientBytes: Int
    public let persistentBytes: Int
    public let totalBytes: Int
    public let textureCount: Int
    public let stageCount: Int

    public init(transientBytes: Int, persistentBytes: Int, textureCount: Int, stageCount: Int) {
        self.transientBytes = max(transientBytes, 0)
        self.persistentBytes = max(persistentBytes, 0)
        self.totalBytes = self.transientBytes + self.persistentBytes
        self.textureCount = max(textureCount, 0)
        self.stageCount = max(stageCount, 0)
    }

    public var fingerprint: String {
        "transient=\(transientBytes)|persistent=\(persistentBytes)|total=\(totalBytes)|textures=\(textureCount)|stages=\(stageCount)"
    }
}

public enum RenderResourceLimit: String, Sendable, Codable, Equatable, Hashable {
    case transientBytes
    case persistentBytes
    case totalBytes
    case textureCount
    case stageCount
}

public struct RenderResourceViolation: Sendable, Codable, Equatable, Hashable {
    public let limit: RenderResourceLimit
    public let estimated: Int
    public let maximum: Int

    public init(limit: RenderResourceLimit, estimated: Int, maximum: Int) {
        self.limit = limit
        self.estimated = estimated
        self.maximum = maximum
    }
}

public struct RenderResourceAdmission: Sendable, Codable, Equatable, Hashable {
    public let estimate: RenderResourceEstimate
    public let budget: RenderResourceBudget?
    public let violations: [RenderResourceViolation]

    public var isAccepted: Bool {
        violations.isEmpty
    }
}

public struct RenderResourceBudgetError: Error, Sendable, Equatable, LocalizedError, HarbethDiagnosticError {
    public let admission: RenderResourceAdmission

    public var errorDescription: String? {
        let summary = admission.violations.map { violation in
            "\(violation.limit.rawValue)=\(violation.estimated)>\(violation.maximum)"
        }.joined(separator: ", ")
        return "Render request exceeds its resource budget: \(summary)."
    }

    public var harbethDiagnosticCode: String {
        "harbeth.render.resource_budget_exceeded"
    }

    public var harbethDiagnosticMetadata: [String: String] {
        [
            "estimate": admission.estimate.fingerprint,
            "budget": admission.budget?.fingerprint ?? "none",
            "violations": admission.violations.map(\.limit.rawValue).joined(separator: ",")
        ]
    }
}

/// 实际执行时由 Harbeth allocator 观察到的纹理请求与分配量。
public struct RenderResourceObservation: Sendable, Codable, Equatable, Hashable {
    public let textureRequestCount: Int
    public let allocationCount: Int
    public let reuseCount: Int
    public let heapBackedAllocationCount: Int
    public let allocatedBytes: Int
    public let reusedBytes: Int
}

public struct RenderResourceReport: Sendable, Codable, Equatable, Hashable {
    public let admission: RenderResourceAdmission
    public let observation: RenderResourceObservation
}

public struct RenderResourceResult<Output> {
    public let output: Output
    public let report: RenderResourceReport

    public init(output: Output, report: RenderResourceReport) {
        self.output = output
        self.report = report
    }
}

public extension RenderRequest {
    var resourceEstimate: RenderResourceEstimate {
        let plan = diagnostics.optimizationPlan
        return RenderResourceEstimate(
            transientBytes: plan.estimatedTransientByteCount,
            persistentBytes: plan.estimatedPersistentByteCount,
            textureCount: plan.intermediateTextureCount + plan.persistentOutputCount,
            stageCount: diagnostics.stageCount
        )
    }

    var resourceAdmission: RenderResourceAdmission {
        let estimate = resourceEstimate
        guard let resourceBudget else {
            return RenderResourceAdmission(estimate: estimate, budget: nil, violations: [])
        }
        var violations: [RenderResourceViolation] = []
        appendViolation(.transientBytes, estimated: estimate.transientBytes, maximum: resourceBudget.maximumTransientBytes, to: &violations)
        appendViolation(.persistentBytes, estimated: estimate.persistentBytes, maximum: resourceBudget.maximumPersistentBytes, to: &violations)
        appendViolation(.totalBytes, estimated: estimate.totalBytes, maximum: resourceBudget.maximumTotalBytes, to: &violations)
        appendViolation(.textureCount, estimated: estimate.textureCount, maximum: resourceBudget.maximumTextureCount, to: &violations)
        appendViolation(.stageCount, estimated: estimate.stageCount, maximum: resourceBudget.maximumStageCount, to: &violations)
        return RenderResourceAdmission(estimate: estimate, budget: resourceBudget, violations: violations)
    }

    func renderTextureWithResourceReport() throws -> RenderResourceResult<MTLTexture> {
        try validateResourceAdmission()
        let ledger = RenderResourceLedger()
        let output = try RenderResourceObservationScope.withLedger(ledger) {
            try renderTexture()
        }
        return RenderResourceResult(
            output: output,
            report: RenderResourceReport(admission: resourceAdmission, observation: ledger.snapshot())
        )
    }

    func renderFrameWithResourceReport(metadata: [String: String] = [:]) throws -> RenderResourceResult<RenderedFrame> {
        try validateResourceAdmission()
        let ledger = RenderResourceLedger()
        let output = try RenderResourceObservationScope.withLedger(ledger) {
            try renderFrame(metadata: metadata)
        }
        return RenderResourceResult(
            output: output,
            report: RenderResourceReport(admission: resourceAdmission, observation: ledger.snapshot())
        )
    }

    internal func validateResourceAdmission() throws {
        let admission = resourceAdmission
        guard admission.isAccepted else {
            throw RenderResourceBudgetError(admission: admission)
        }
    }

    private func appendViolation(_ limit: RenderResourceLimit,
                                 estimated: Int,
                                 maximum: Int?,
                                 to violations: inout [RenderResourceViolation]) {
        guard let maximum, estimated > maximum else { return }
        violations.append(RenderResourceViolation(limit: limit, estimated: estimated, maximum: maximum))
    }
}

final class RenderResourceLedger: @unchecked Sendable {
    private let lock = NSLock()
    private var textureRequestCount = 0
    private var allocationCount = 0
    private var reuseCount = 0
    private var heapBackedAllocationCount = 0
    private var allocatedBytes = 0
    private var reusedBytes = 0

    func recordRequest() {
        lock.withLock { textureRequestCount += 1 }
    }

    func recordAllocation(texture: MTLTexture, heapBacked: Bool) {
        lock.withLock {
            allocationCount += 1
            heapBackedAllocationCount += heapBacked ? 1 : 0
            allocatedBytes += max(texture.allocatedSize, 0)
        }
    }

    func recordReuse(texture: MTLTexture) {
        lock.withLock {
            reuseCount += 1
            reusedBytes += max(texture.allocatedSize, 0)
        }
    }

    func snapshot() -> RenderResourceObservation {
        lock.withLock {
            RenderResourceObservation(
                textureRequestCount: textureRequestCount,
                allocationCount: allocationCount,
                reuseCount: reuseCount,
                heapBackedAllocationCount: heapBackedAllocationCount,
                allocatedBytes: allocatedBytes,
                reusedBytes: reusedBytes
            )
        }
    }
}

enum RenderResourceObservationScope {
    private static let key = "Harbeth.RenderResourceLedger"

    static var current: RenderResourceLedger? {
        Thread.current.threadDictionary[key] as? RenderResourceLedger
    }

    static func withLedger<Result>(_ ledger: RenderResourceLedger, operation: () throws -> Result) rethrows -> Result {
        let dictionary = Thread.current.threadDictionary
        let previous = dictionary[key]
        dictionary[key] = ledger
        defer { dictionary[key] = previous }
        return try operation()
    }
}

private extension NSLock {
    func withLock<Result>(_ operation: () -> Result) -> Result {
        lock()
        defer { unlock() }
        return operation()
    }
}
