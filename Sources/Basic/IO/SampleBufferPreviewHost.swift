//
//  SampleBufferPreviewHost.swift
//  Harbeth
//
//  Created by Condy on 2026/6/24.
//

import Foundation

#if canImport(AVFoundation) && !os(watchOS)
import AVFoundation
import QuartzCore
import CoreGraphics

enum PreviewHostSuspensionReason: String, Sendable, Equatable, Hashable {
    case hostHidden
    case applicationInactive
}

enum PreviewHostFailureReason: String, Sendable, Equatable, Hashable {
    case missingSampleBufferPayload
    case sampleBufferHostUnsupported
    case sampleBufferEnqueueFailed
    case requiresFlushToResume
    case rematerializationFailed
    case lifecycleSuspended
    case visibilitySuspended
    case fallbackToMetal
}

enum PreviewHostBackingKind: String, Sendable, Codable, Equatable, Hashable {
    case metalTextureHost
    case sampleBufferDisplayLayer
}

enum PreviewHostPayloadMode: String, Sendable, Codable, Equatable, Hashable {
    case none
    case passthrough
    case rematerialized
}

enum PreviewHostExecutionState: String, Sendable, Codable, Equatable, Hashable {
    case inactive
    case metalActive
    case sampleBufferActive
    case suspended
    case recovering
    case fallbackMetal
}

struct PreviewHostExecutionReport: Sendable, Codable, Equatable, Hashable {
    let predictedStrategy: String
    let actualBackingKind: String
    let actualResolvedHostStrategy: String
    let payloadMode: String
    let state: String
    let currentSuspensionReason: String?
    let lastFailureReason: String?
    let recoveredByFlush: Bool
    let fellBackToMetal: Bool
    let enqueueCount: Int
    let lifecyclePauseCount: Int
    let lifecycleResumeCount: Int
    let visibilityPauseCount: Int
    let visibilityResumeCount: Int
    let strategySwitchCount: Int
    let activationCount: Int
    let deactivationCount: Int
    let recoveryCount: Int
    let fallbackCount: Int
    let failureCountsByReason: [String: Int]

    init(predictedStrategy: PreviewHostStrategy,
         actualBackingKind: PreviewHostBackingKind = .metalTextureHost,
         actualResolvedHostStrategy: PreviewHostStrategy = .metalTextureHost,
         payloadMode: PreviewHostPayloadMode = .none,
         state: PreviewHostExecutionState = .inactive,
         currentSuspensionReason: PreviewHostSuspensionReason? = nil,
         lastFailureReason: PreviewHostFailureReason? = nil,
         recoveredByFlush: Bool = false,
         fellBackToMetal: Bool = false,
         enqueueCount: Int = 0,
         lifecyclePauseCount: Int = 0,
         lifecycleResumeCount: Int = 0,
         visibilityPauseCount: Int = 0,
         visibilityResumeCount: Int = 0,
         strategySwitchCount: Int = 0,
         activationCount: Int = 0,
         deactivationCount: Int = 0,
         recoveryCount: Int = 0,
         fallbackCount: Int = 0,
         failureCountsByReason: [String: Int] = [:]) {
        self.predictedStrategy = predictedStrategy.rawValue
        self.actualBackingKind = actualBackingKind.rawValue
        self.actualResolvedHostStrategy = actualResolvedHostStrategy.rawValue
        self.payloadMode = payloadMode.rawValue
        self.state = state.rawValue
        self.currentSuspensionReason = currentSuspensionReason?.rawValue
        self.lastFailureReason = lastFailureReason?.rawValue
        self.recoveredByFlush = recoveredByFlush
        self.fellBackToMetal = fellBackToMetal
        self.enqueueCount = enqueueCount
        self.lifecyclePauseCount = lifecyclePauseCount
        self.lifecycleResumeCount = lifecycleResumeCount
        self.visibilityPauseCount = visibilityPauseCount
        self.visibilityResumeCount = visibilityResumeCount
        self.strategySwitchCount = strategySwitchCount
        self.activationCount = activationCount
        self.deactivationCount = deactivationCount
        self.recoveryCount = recoveryCount
        self.fallbackCount = fallbackCount
        self.failureCountsByReason = failureCountsByReason
    }

    static func inactive(predictedStrategy: PreviewHostStrategy) -> PreviewHostExecutionReport {
        PreviewHostExecutionReport(predictedStrategy: predictedStrategy)
    }
}

struct PreviewHostFleetSnapshot: Sendable, Codable, Equatable, Hashable {
    let activeHostCount: Int
    let activeSampleBufferHostCount: Int
    let activeMetalHostCount: Int
    let suspendedHostCount: Int
    let recoveringHostCount: Int
    let fallbackHostCount: Int
    let maxConcurrentSampleBufferHosts: Int
    let totalStrategySwitchCount: Int
    let totalActivationCount: Int
    let totalDeactivationCount: Int
    let totalRecoveryCount: Int
    let totalFallbackCount: Int
    let totalLifecycleSuspensionCount: Int
    let totalVisibilitySuspensionCount: Int
    let failureCountsByReason: [String: Int]
}

enum PreviewHostFleetRegistry {
    private struct State {
        var reports: [String: PreviewHostExecutionReport] = [:]
        var maxConcurrentSampleBufferHosts: Int = 0
        var totalStrategySwitchCount: Int = 0
        var totalActivationCount: Int = 0
        var totalDeactivationCount: Int = 0
        var totalRecoveryCount: Int = 0
        var totalFallbackCount: Int = 0
        var totalLifecycleSuspensionCount: Int = 0
        var totalVisibilitySuspensionCount: Int = 0
        var failureCountsByReason: [String: Int] = [:]
    }

    private static let lock = NSLock()
    private static var state = State()

    static func update(instanceID: String, report: PreviewHostExecutionReport) -> PreviewHostFleetSnapshot {
        lock.lock()
        let previous = state.reports[instanceID]
        state.reports[instanceID] = report
        accumulate(from: previous, to: report)
        let snapshot = makeSnapshotLocked()
        lock.unlock()
        return snapshot
    }

    static func unregister(instanceID: String) -> PreviewHostFleetSnapshot {
        lock.lock()
        state.reports.removeValue(forKey: instanceID)
        let snapshot = makeSnapshotLocked()
        lock.unlock()
        return snapshot
    }

    static func snapshot() -> PreviewHostFleetSnapshot {
        lock.lock()
        let snapshot = makeSnapshotLocked()
        lock.unlock()
        return snapshot
    }

    static func resetForTesting() {
        lock.lock()
        state = State()
        lock.unlock()
        PreviewHostRuntimeSummaryCache.resetForTesting()
    }

    private static func accumulate(from previous: PreviewHostExecutionReport?, to current: PreviewHostExecutionReport) {
        let previousStrategySwitchCount = previous?.strategySwitchCount ?? 0
        let previousActivationCount = previous?.activationCount ?? 0
        let previousDeactivationCount = previous?.deactivationCount ?? 0
        let previousRecoveryCount = previous?.recoveryCount ?? 0
        let previousFallbackCount = previous?.fallbackCount ?? 0
        let previousLifecyclePauseCount = previous?.lifecyclePauseCount ?? 0
        let previousVisibilityPauseCount = previous?.visibilityPauseCount ?? 0
        state.totalStrategySwitchCount += max(current.strategySwitchCount - previousStrategySwitchCount, 0)
        state.totalActivationCount += max(current.activationCount - previousActivationCount, 0)
        state.totalDeactivationCount += max(current.deactivationCount - previousDeactivationCount, 0)
        state.totalRecoveryCount += max(current.recoveryCount - previousRecoveryCount, 0)
        state.totalFallbackCount += max(current.fallbackCount - previousFallbackCount, 0)
        state.totalLifecycleSuspensionCount += max(current.lifecyclePauseCount - previousLifecyclePauseCount, 0)
        state.totalVisibilitySuspensionCount += max(current.visibilityPauseCount - previousVisibilityPauseCount, 0)

        let previousFailureCounts = previous?.failureCountsByReason ?? [:]
        for (reason, count) in current.failureCountsByReason {
            let delta = max(count - (previousFailureCounts[reason] ?? 0), 0)
            if delta > 0 {
                state.failureCountsByReason[reason, default: 0] += delta
            }
        }
    }

    private static func makeSnapshotLocked() -> PreviewHostFleetSnapshot {
        let reports = Array(state.reports.values)
        let activeSampleBufferHostCount = reports.filter {
            ($0.state == PreviewHostExecutionState.sampleBufferActive.rawValue
            || $0.state == PreviewHostExecutionState.recovering.rawValue)
            && $0.actualBackingKind == PreviewHostBackingKind.sampleBufferDisplayLayer.rawValue
        }.count
        let activeMetalHostCount = reports.filter {
            ($0.state == PreviewHostExecutionState.metalActive.rawValue
            || $0.state == PreviewHostExecutionState.fallbackMetal.rawValue)
            && $0.actualBackingKind == PreviewHostBackingKind.metalTextureHost.rawValue
        }.count
        let suspendedHostCount = reports.filter { $0.state == PreviewHostExecutionState.suspended.rawValue }.count
        let recoveringHostCount = reports.filter { $0.state == PreviewHostExecutionState.recovering.rawValue }.count
        let fallbackHostCount = reports.filter { $0.state == PreviewHostExecutionState.fallbackMetal.rawValue }.count
        let activeHostCount = activeSampleBufferHostCount + activeMetalHostCount
        state.maxConcurrentSampleBufferHosts = max(state.maxConcurrentSampleBufferHosts, activeSampleBufferHostCount)
        return PreviewHostFleetSnapshot(
            activeHostCount: activeHostCount,
            activeSampleBufferHostCount: activeSampleBufferHostCount,
            activeMetalHostCount: activeMetalHostCount,
            suspendedHostCount: suspendedHostCount,
            recoveringHostCount: recoveringHostCount,
            fallbackHostCount: fallbackHostCount,
            maxConcurrentSampleBufferHosts: state.maxConcurrentSampleBufferHosts,
            totalStrategySwitchCount: state.totalStrategySwitchCount,
            totalActivationCount: state.totalActivationCount,
            totalDeactivationCount: state.totalDeactivationCount,
            totalRecoveryCount: state.totalRecoveryCount,
            totalFallbackCount: state.totalFallbackCount,
            totalLifecycleSuspensionCount: state.totalLifecycleSuspensionCount,
            totalVisibilitySuspensionCount: state.totalVisibilitySuspensionCount,
            failureCountsByReason: state.failureCountsByReason
        )
    }
}

enum PreviewHostRuntimeSummaryCache {
    private struct Entry {
        let instanceID: String
        let summary: RenderGraphDebugSnapshot.Diagnostics.RuntimePreviewHostSummary
    }

    private static let lock = NSLock()
    private static var entries: [String: Entry] = [:]

    static func store(cacheIdentityFingerprint: String, instanceID: String, summary: RenderGraphDebugSnapshot.Diagnostics.RuntimePreviewHostSummary) {
        lock.lock()
        entries[cacheIdentityFingerprint] = Entry(instanceID: instanceID, summary: summary)
        lock.unlock()
    }

    static func store(cacheIdentityFingerprint: String, instanceID: String, report: PreviewHostExecutionReport, fleet: PreviewHostFleetSnapshot) {
        store(
            cacheIdentityFingerprint: cacheIdentityFingerprint,
            instanceID: instanceID,
            summary: RenderGraphDebugSnapshot.Diagnostics.RuntimePreviewHostSummary(report: report, fleet: fleet)
        )
    }

    static func lookup(cacheIdentityFingerprint: String) -> RenderGraphDebugSnapshot.Diagnostics.RuntimePreviewHostSummary? {
        lock.lock()
        defer { lock.unlock() }
        return entries[cacheIdentityFingerprint]?.summary
    }

    static func remove(cacheIdentityFingerprint: String, instanceID: String) {
        lock.lock()
        if entries[cacheIdentityFingerprint]?.instanceID == instanceID {
            entries.removeValue(forKey: cacheIdentityFingerprint)
        }
        lock.unlock()
    }

    static func resetForTesting() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }
}

struct SampleBufferPreviewHostPoolSnapshot: Sendable, Equatable, Hashable {
    let activeLeaseCount: Int
    let pooledLayerCount: Int
    let totalTakeCount: Int
    let totalReuseCount: Int
    let totalReturnCount: Int
    let totalFlushCount: Int
    let totalFlushAndRemoveImageCount: Int
    let totalRecoveryCount: Int
    let totalFallbackToMetalCount: Int
    let totalVisibilityPauseCount: Int
    let totalVisibilityResumeCount: Int
    let totalLifecyclePauseCount: Int
    let totalLifecycleResumeCount: Int
}

private enum SampleBufferPreviewHostCoordinator {
    private struct State {
        var activeLeaseCount: Int = 0
        var pooledLayerCount: Int = 0
        var totalTakeCount: Int = 0
        var totalReuseCount: Int = 0
        var totalReturnCount: Int = 0
        var totalFlushCount: Int = 0
        var totalFlushAndRemoveImageCount: Int = 0
        var totalRecoveryCount: Int = 0
        var totalFallbackToMetalCount: Int = 0
        var totalVisibilityPauseCount: Int = 0
        var totalVisibilityResumeCount: Int = 0
        var totalLifecyclePauseCount: Int = 0
        var totalLifecycleResumeCount: Int = 0
    }

    private static let lock = NSLock()
    private static var state = State()

    static func recordTake(reused: Bool, pooledLayerCount: Int) {
        lock.lock()
        state.activeLeaseCount += 1
        state.totalTakeCount += 1
        if reused {
            state.totalReuseCount += 1
        }
        state.pooledLayerCount = pooledLayerCount
        lock.unlock()
    }

    static func recordReturn(pooledLayerCount: Int) {
        lock.lock()
        state.activeLeaseCount = max(state.activeLeaseCount - 1, 0)
        state.totalReturnCount += 1
        state.pooledLayerCount = pooledLayerCount
        lock.unlock()
    }

    static func recordFlush() {
        lock.lock()
        state.totalFlushCount += 1
        lock.unlock()
    }

    static func recordFlushAndRemoveImage() {
        lock.lock()
        state.totalFlushAndRemoveImageCount += 1
        lock.unlock()
    }

    static func recordRecovery() {
        lock.lock()
        state.totalRecoveryCount += 1
        lock.unlock()
    }

    static func recordFallbackToMetal() {
        lock.lock()
        state.totalFallbackToMetalCount += 1
        lock.unlock()
    }

    static func recordVisibilityPause() {
        lock.lock()
        state.totalVisibilityPauseCount += 1
        lock.unlock()
    }

    static func recordVisibilityResume() {
        lock.lock()
        state.totalVisibilityResumeCount += 1
        lock.unlock()
    }

    static func recordLifecyclePause() {
        lock.lock()
        state.totalLifecyclePauseCount += 1
        lock.unlock()
    }

    static func recordLifecycleResume() {
        lock.lock()
        state.totalLifecycleResumeCount += 1
        lock.unlock()
    }

    static func snapshot() -> SampleBufferPreviewHostPoolSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return SampleBufferPreviewHostPoolSnapshot(
            activeLeaseCount: state.activeLeaseCount,
            pooledLayerCount: state.pooledLayerCount,
            totalTakeCount: state.totalTakeCount,
            totalReuseCount: state.totalReuseCount,
            totalReturnCount: state.totalReturnCount,
            totalFlushCount: state.totalFlushCount,
            totalFlushAndRemoveImageCount: state.totalFlushAndRemoveImageCount,
            totalRecoveryCount: state.totalRecoveryCount,
            totalFallbackToMetalCount: state.totalFallbackToMetalCount,
            totalVisibilityPauseCount: state.totalVisibilityPauseCount,
            totalVisibilityResumeCount: state.totalVisibilityResumeCount,
            totalLifecyclePauseCount: state.totalLifecyclePauseCount,
            totalLifecycleResumeCount: state.totalLifecycleResumeCount
        )
    }

    static func reset() {
        lock.lock()
        state = State()
        lock.unlock()
    }
}

private final class SampleBufferPreviewLayerNullAction: NSObject, CAAction {
    @objc func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable : Any]?) {}
}

private final class SampleBufferPreviewLayerImpl: AVSampleBufferDisplayLayer {
    override func action(forKey event: String) -> CAAction? {
        SampleBufferPreviewLayerNullAction()
    }
}

final class SampleBufferPreviewLayerLease {
    let layer: AVSampleBufferDisplayLayer

    init(layer: AVSampleBufferDisplayLayer) {
        self.layer = layer
    }

    func prepare(frame: CGRect, contentsScale: CGFloat) {
        layer.frame = frame
        layer.contentsScale = max(contentsScale, 1)
        layer.videoGravity = .resizeAspect
        layer.isHidden = false
    }

    func resetForReuse() {
        SampleBufferPreviewHostCoordinator.recordFlushAndRemoveImage()
        layer.flushAndRemoveImage()
        layer.removeAllAnimations()
        layer.setAffineTransform(.identity)
        layer.videoGravity = .resizeAspect
        layer.isHidden = true
        layer.removeFromSuperlayer()
    }
}

enum SampleBufferPreviewLayerPool {
    private static let lock = NSLock()
    private static var layers: [AVSampleBufferDisplayLayer] = []

    static func take() -> SampleBufferPreviewLayerLease {
        lock.lock()
        let reused = layers.isEmpty == false
        let layer = layers.popLast() ?? SampleBufferPreviewLayerImpl()
        let pooledLayerCount = layers.count
        lock.unlock()
        SampleBufferPreviewHostCoordinator.recordTake(reused: reused, pooledLayerCount: pooledLayerCount)
        return SampleBufferPreviewLayerLease(layer: layer)
    }

    static func `return`(_ lease: SampleBufferPreviewLayerLease?) {
        guard let lease else { return }
        lease.resetForReuse()
        lock.lock()
        layers.append(lease.layer)
        let pooledLayerCount = layers.count
        lock.unlock()
        SampleBufferPreviewHostCoordinator.recordReturn(pooledLayerCount: pooledLayerCount)
    }

    static func recordFlush() {
        SampleBufferPreviewHostCoordinator.recordFlush()
    }

    static func recordRecovery() {
        SampleBufferPreviewHostCoordinator.recordRecovery()
    }

    static func recordFallbackToMetal() {
        SampleBufferPreviewHostCoordinator.recordFallbackToMetal()
    }

    static func recordFlushAndRemoveImage() {
        SampleBufferPreviewHostCoordinator.recordFlushAndRemoveImage()
    }

    static func recordVisibilityPause() {
        SampleBufferPreviewHostCoordinator.recordVisibilityPause()
    }

    static func recordVisibilityResume() {
        SampleBufferPreviewHostCoordinator.recordVisibilityResume()
    }

    static func recordLifecyclePause() {
        SampleBufferPreviewHostCoordinator.recordLifecyclePause()
    }

    static func recordLifecycleResume() {
        SampleBufferPreviewHostCoordinator.recordLifecycleResume()
    }

    static func snapshot() -> SampleBufferPreviewHostPoolSnapshot {
        SampleBufferPreviewHostCoordinator.snapshot()
    }

    static func resetForTesting() {
        lock.lock()
        let drainedLayers = layers
        layers.removeAll()
        lock.unlock()
        for layer in drainedLayers {
            layer.flushAndRemoveImage()
            layer.removeAllAnimations()
            layer.setAffineTransform(.identity)
            layer.removeFromSuperlayer()
        }
        SampleBufferPreviewHostCoordinator.reset()
    }
}
#endif
