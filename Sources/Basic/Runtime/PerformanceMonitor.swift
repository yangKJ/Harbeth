//
//  PerformanceMonitor.swift
//  Harbeth
//
//  Created by Condy on 2024/3/20.
//

import Foundation
import Metal

public final class PerformanceMonitor {
    public struct Configuration {
        public var enabled: Bool = false
        public var logLevel: LogLevel = .warning
        public var maxStoredMetrics: Int = 100
        public var autoCleanupInterval: TimeInterval = 300
        public var gpuTimeWarningThreshold: TimeInterval = 0.016
        public var cpuTimeWarningThreshold: TimeInterval = 0.033
        public var enablePerformanceCounters: Bool = true
        public var enableDetailedMemoryTracking: Bool = true
    }
    
    public enum LogLevel: Int, Comparable {
        case error = 0
        case warning = 1
        case info = 2
        case debug = 3
        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    private var metricsCache: [String: Metrics] = [:]
    private let cacheLock = NSLock()
    private let cleanupTimer: DispatchSourceTimer
    private var configuration = Configuration()
    private var pendingGPUOperations: [String: Int] = [:]
    
    public init(enabled: Bool) {
        self.configuration = Configuration(enabled: enabled)
        cleanupTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        cleanupTimer.schedule(deadline: .now(), repeating: configuration.autoCleanupInterval)
        cleanupTimer.setEventHandler { [weak self] in
            self?.cleanupOldMetrics(maxAge: self?.configuration.autoCleanupInterval ?? 300)
        }
        cleanupTimer.resume()
    }
    
    deinit { cleanupTimer.cancel() }
    
    public func configure(_ config: Configuration) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        self.configuration = config
    }
    
    func setupEnablePerformanceMonitor(_ enable: Bool) {
        cacheLock.lock()
        var config = self.configuration
        config.enabled = enable
        self.configuration = config
        cacheLock.unlock()
    }
    
    @discardableResult
    func beginMonitoring(_ identifier: String) -> Metrics {
        guard configuration.enabled else { return Metrics() }
        let metrics = Metrics(startTime: CACurrentMediaTime())
        cacheLock.lock()
        metricsCache[identifier] = metrics
        pendingGPUOperations[identifier] = 0
        cacheLock.unlock()
        return metrics
    }
    
    @discardableResult
    func endMonitoring(_ identifier: String) -> Metrics? {
        guard configuration.enabled else { return nil }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        guard var metrics = metricsCache[identifier] else { return nil }
        metrics.endTime = CACurrentMediaTime()
        metricsCache[identifier] = metrics
        if pendingGPUOperations[identifier] == 0 { logMetrics(metrics, for: identifier, isFinal: true) }
        return metrics
    }
    
    func recordTextureCreation(_ identifier: String, created: Bool = true) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        if created {
            metricsCache[identifier]?.textureCreations += 1
        } else {
            metricsCache[identifier]?.textureReuses += 1
        }
    }

    func recordTextureReuse(_ identifier: String, source: String) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.resourceEvents.append("reuse:\(source)")
    }

    public func recordResourceEvent(_ identifier: String, event: String) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.resourceEvents.append(event)
    }

    func recordPipelineCacheLookup(_ identifier: String, hit: Bool) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        if hit {
            metricsCache[identifier]?.pipelineCacheHits += 1
        } else {
            metricsCache[identifier]?.pipelineCacheMisses += 1
        }
    }

    func recordImageResolutionCacheLookup(_ identifier: String, hit: Bool) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        if hit {
            metricsCache[identifier]?.imageResolutionCacheHits += 1
        } else {
            metricsCache[identifier]?.imageResolutionCacheMisses += 1
        }
    }

    func recordRenderStageCount(_ identifier: String, stageCount: Int) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.stageCount = stageCount
    }

    func recordReadbackBoundary(_ identifier: String) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.readbackBoundaryCount += 1
    }

    func recordPixelFormatConversion(_ identifier: String, from: MTLPixelFormat, to: MTLPixelFormat) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.pixelFormatConversions += 1
        metricsCache[identifier]?.resourceEvents.append("pixelFormat:\(from.rawValue)->\(to.rawValue)")
    }

    func recordAlphaConversion(_ identifier: String, contract: ImageAlphaContract) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.alphaConversions += 1
        metricsCache[identifier]?.resourceEvents.append("alpha:\(contract)")
    }

    func recordColorConversion(_ identifier: String, contract: ImageColorSpaceContract) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.colorConversions += 1
        metricsCache[identifier]?.resourceEvents.append("color:\(contract.name)")
    }

    func recordRenderTargetCreation(_ identifier: String) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.renderTargetCreations += 1
    }

    func recordRenderOptimizationPlan(_ identifier: String, plan: RenderOptimizationPlan) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.optimizerDecisionCount += plan.decisions.count
        metricsCache[identifier]?.textureLifecycleDecisionCount += plan.lifecycleDecisions.count
        metricsCache[identifier]?.resourceEvents.append(contentsOf: plan.decisions.map { "optimizer:\($0)" })
    }

    func recordPreviewHostStrategy(_ identifier: String, strategy: PreviewHostStrategy) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        switch strategy {
        case .metalTextureHost:
            metricsCache[identifier]?.previewHostMetalStrategyCount += 1
        case .sampleBufferPassthroughHost:
            metricsCache[identifier]?.previewHostPassthroughStrategyCount += 1
        case .sampleBufferRematerializedHost:
            metricsCache[identifier]?.previewHostRematerializedStrategyCount += 1
        }
        metricsCache[identifier]?.resourceEvents.append("previewHostExecution:strategy:\(strategy.rawValue)")
    }

    func recordPreviewHostEnqueue(_ identifier: String) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.previewHostEnqueueCount += 1
    }

    func recordPreviewHostRecovery(_ identifier: String) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.previewHostRecoveryCount += 1
        metricsCache[identifier]?.resourceEvents.append("previewHostExecution:recovery:flush")
    }

    func recordPreviewHostFallbackToMetal(_ identifier: String) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.previewHostFallbackCount += 1
        metricsCache[identifier]?.resourceEvents.append("previewHostExecution:fallback:metal")
    }

    func recordPreviewHostPredictionDrift(_ identifier: String, predicted: PreviewHostStrategy, actual: PreviewHostStrategy) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.previewHostPredictionDriftCount += 1
        metricsCache[identifier]?.resourceEvents.append("previewHostExecution:drift:\(predicted.rawValue)->\(actual.rawValue)")
    }

    func recordPreviewHostVisibilityPause(_ identifier: String) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.previewHostVisibilityPauseCount += 1
        metricsCache[identifier]?.resourceEvents.append("previewHostLifecycle:visibilityPause")
    }

    func recordPreviewHostVisibilityResume(_ identifier: String) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.previewHostVisibilityResumeCount += 1
        metricsCache[identifier]?.resourceEvents.append("previewHostLifecycle:visibilityResume")
    }

    func recordPreviewHostLifecyclePause(_ identifier: String, reason: PreviewHostSuspensionReason) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.previewHostLifecyclePauseCount += 1
        metricsCache[identifier]?.previewHostSuspensionReasons[reason.rawValue, default: 0] += 1
        metricsCache[identifier]?.resourceEvents.append("previewHostLifecycle:pause:\(reason.rawValue)")
    }

    func recordPreviewHostLifecycleResume(_ identifier: String) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.previewHostLifecycleResumeCount += 1
        metricsCache[identifier]?.resourceEvents.append("previewHostLifecycle:resume")
    }

    func recordPreviewHostFailure(_ identifier: String, reason: PreviewHostFailureReason) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.previewHostFailureCount += 1
        metricsCache[identifier]?.previewHostFailureReasons[reason.rawValue, default: 0] += 1
        metricsCache[identifier]?.resourceEvents.append("previewHostFailure:\(reason.rawValue)")
    }

    func recordPreviewHostExecution(_ identifier: String, report: PreviewHostExecutionReport) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.previewHostStrategySwitchCount = report.strategySwitchCount
        metricsCache[identifier]?.previewHostActivationCount = report.activationCount
        metricsCache[identifier]?.previewHostDeactivationCount = report.deactivationCount
        metricsCache[identifier]?.previewHostRecoveryCount = report.recoveryCount
        metricsCache[identifier]?.previewHostFallbackCount = report.fallbackCount
        metricsCache[identifier]?.previewHostLifecyclePauseCount = report.lifecyclePauseCount
        metricsCache[identifier]?.previewHostLifecycleResumeCount = report.lifecycleResumeCount
        metricsCache[identifier]?.previewHostVisibilityPauseCount = report.visibilityPauseCount
        metricsCache[identifier]?.previewHostVisibilityResumeCount = report.visibilityResumeCount
        metricsCache[identifier]?.previewHostEnqueueCount = report.enqueueCount
        metricsCache[identifier]?.previewHostFailureCount = report.failureCountsByReason.values.reduce(0, +)
        metricsCache[identifier]?.previewHostFailureReasons = report.failureCountsByReason
        metricsCache[identifier]?.previewHostExecutionState = report.state
        metricsCache[identifier]?.resourceEvents.append(
            "previewHostExecution:state=\(report.state):actual=\(report.actualResolvedHostStrategy):backing=\(report.actualBackingKind):payload=\(report.payloadMode)"
        )
    }

    func recordPreviewHostFleetSnapshot(_ identifier: String, snapshot: PreviewHostFleetSnapshot) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.previewHostConcurrentSampleBufferHostCount = snapshot.activeSampleBufferHostCount
        metricsCache[identifier]?.previewHostSuspendedHostCount = snapshot.suspendedHostCount
        metricsCache[identifier]?.previewHostMaxConcurrentSampleBufferHostCount = snapshot.maxConcurrentSampleBufferHosts
        metricsCache[identifier]?.previewHostFleetStrategySwitchCount = snapshot.totalStrategySwitchCount
        metricsCache[identifier]?.previewHostFleetActivationCount = snapshot.totalActivationCount
        metricsCache[identifier]?.previewHostFleetDeactivationCount = snapshot.totalDeactivationCount
        metricsCache[identifier]?.previewHostFleetRecoveryCount = snapshot.totalRecoveryCount
        metricsCache[identifier]?.previewHostFleetFallbackCount = snapshot.totalFallbackCount
        metricsCache[identifier]?.previewHostFleetFailureReasons = snapshot.failureCountsByReason
        metricsCache[identifier]?.resourceEvents.append(
            "previewHostFleet:active=\(snapshot.activeHostCount):sampleBuffer=\(snapshot.activeSampleBufferHostCount):suspended=\(snapshot.suspendedHostCount):fallback=\(snapshot.fallbackHostCount)"
        )
    }

    func recordPreviewHostPoolSnapshot(_ identifier: String, snapshot: SampleBufferPreviewHostPoolSnapshot) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.previewHostActiveLeaseCount = snapshot.activeLeaseCount
        metricsCache[identifier]?.previewHostPooledLayerCount = snapshot.pooledLayerCount
        metricsCache[identifier]?.previewHostPoolReuseCount = snapshot.totalReuseCount
        metricsCache[identifier]?.resourceEvents.append(
            "previewHostPool:active=\(snapshot.activeLeaseCount):pooled=\(snapshot.pooledLayerCount):reuse=\(snapshot.totalReuseCount)"
        )
    }
    
    func recordFilterProcessing(_ identifier: String, filterName: String, duration: TimeInterval) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.filterProcessingTimes[filterName] = duration
    }
    
    func recordMemoryAllocation(_ identifier: String, bytes: Int, source: String) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        let alloc = Metrics.MemoryAllocation(timestamp: CACurrentMediaTime(), bytes: bytes, source: source)
        metricsCache[identifier]?.memoryAllocations.append(alloc)
    }
    
    func recordError(_ identifier: String, error: Error) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.errors.append(error.localizedDescription)
        if configuration.logLevel >= .error {
            HarbethLogger.log(
                .error,
                category: "performance",
                code: error.harbethDiagnosticCode,
                outcome: .failed,
                metadata: error.harbethDiagnosticMetadata.merging(["operation": identifier]) { current, _ in current },
                correlationID: identifier,
                message: error.localizedDescription
            )
        }
    }
    
    func recordGPUTime(_ identifier: String, nanoseconds: UInt64) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.gpuTotalTimeNanoseconds += nanoseconds
    }
    
    public func recordPerformanceCounter(_ identifier: String, name: String, value: Double) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.performanceCounters[name] = value
    }
    
    public func getMetrics(_ identifier: String) -> Metrics? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return metricsCache[identifier]
    }
    
    func cleanupOldMetrics(maxAge: TimeInterval = 300) {
        guard configuration.enabled else { return }
        let now = CACurrentMediaTime()
        cacheLock.lock()
        defer { cacheLock.unlock() }
        metricsCache = metricsCache.filter { _, metrics in
            let endTime = metrics.endTime > 0 ? metrics.endTime : metrics.startTime
            return (now - endTime) < maxAge
        }
        pendingGPUOperations = pendingGPUOperations.filter { metricsCache.keys.contains($0.key) }
        if metricsCache.count > configuration.maxStoredMetrics {
            let sorted = metricsCache.sorted { $0.value.startTime < $1.value.startTime }
            let keysToRemove = sorted.prefix(metricsCache.count - configuration.maxStoredMetrics).map { $0.key }
            for key in keysToRemove {
                metricsCache.removeValue(forKey: key)
                pendingGPUOperations.removeValue(forKey: key)
            }
        }
    }
    
    @discardableResult
    func measure<T>(_ identifier: String, _ operation: String, _ block: () throws -> T) rethrows -> T {
        guard configuration.enabled else { return try block() }
        let startTime = CACurrentMediaTime()
        do {
            let result = try block()
            let duration = CACurrentMediaTime() - startTime
            recordFilterProcessing(identifier, filterName: operation, duration: duration)
            if configuration.logLevel >= .debug {
                HarbethLogger.log(
                    .debug,
                    category: "performance",
                    code: "harbeth.performance.operation_duration",
                    outcome: .observed,
                    metadata: ["operation": operation, "durationSeconds": String(duration)],
                    correlationID: identifier,
                    message: "\(identifier) - \(operation): \(String(format: "%.4f", duration))s"
                )
            }
            return result
        } catch {
            let duration = CACurrentMediaTime() - startTime
            recordFilterProcessing(identifier, filterName: operation, duration: duration)
            recordError(identifier, error: error)
            throw error
        }
    }
    
    public func clearAllMetrics() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        metricsCache.removeAll()
        pendingGPUOperations.removeAll()
    }
    
    public func getSummary() -> Summary {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        var summary = Summary()
        summary.totalOperations = metricsCache.count
        for (_, metrics) in metricsCache {
            summary.totalProcessingTime += metrics.totalProcessingTime
            summary.totalCPUTime += metrics.cpuTime
            summary.totalGPUTime += metrics.gpuTotalTime
            summary.averageGPUUtilization += metrics.gpuUtilization
            summary.totalTextureCreations += metrics.textureCreations
            summary.totalTextureReuses += metrics.textureReuses
            summary.totalPipelineCacheHits += metrics.pipelineCacheHits
            summary.totalPipelineCacheMisses += metrics.pipelineCacheMisses
            summary.totalImageResolutionCacheHits += metrics.imageResolutionCacheHits
            summary.totalImageResolutionCacheMisses += metrics.imageResolutionCacheMisses
            summary.totalStages += metrics.stageCount
            summary.totalReadbackBoundaries += metrics.readbackBoundaryCount
            summary.totalPixelFormatConversions += metrics.pixelFormatConversions
            summary.totalAlphaConversions += metrics.alphaConversions
            summary.totalColorConversions += metrics.colorConversions
            summary.totalRenderTargetCreations += metrics.renderTargetCreations
            summary.totalOptimizerDecisions += metrics.optimizerDecisionCount
            summary.totalTextureLifecycleDecisions += metrics.textureLifecycleDecisionCount
            summary.totalPreviewHostMetalStrategyDecisions += metrics.previewHostMetalStrategyCount
            summary.totalPreviewHostPassthroughStrategyDecisions += metrics.previewHostPassthroughStrategyCount
            summary.totalPreviewHostRematerializedStrategyDecisions += metrics.previewHostRematerializedStrategyCount
            summary.totalPreviewHostEnqueues += metrics.previewHostEnqueueCount
            summary.totalPreviewHostRecoveries += metrics.previewHostRecoveryCount
            summary.totalPreviewHostFallbacks += metrics.previewHostFallbackCount
            summary.totalPreviewHostPredictionDrifts += metrics.previewHostPredictionDriftCount
            summary.totalPreviewHostVisibilityPauses += metrics.previewHostVisibilityPauseCount
            summary.totalPreviewHostVisibilityResumes += metrics.previewHostVisibilityResumeCount
            summary.totalPreviewHostLifecyclePauses += metrics.previewHostLifecyclePauseCount
            summary.totalPreviewHostLifecycleResumes += metrics.previewHostLifecycleResumeCount
            summary.totalPreviewHostFailures += metrics.previewHostFailureCount
            summary.totalPreviewHostStrategySwitches += metrics.previewHostStrategySwitchCount
            summary.totalPreviewHostActivations += metrics.previewHostActivationCount
            summary.totalPreviewHostDeactivations += metrics.previewHostDeactivationCount
            summary.maxPreviewHostConcurrentSampleBufferHosts = max(summary.maxPreviewHostConcurrentSampleBufferHosts, metrics.previewHostMaxConcurrentSampleBufferHostCount)
            summary.maxPreviewHostSuspendedHostCount = max(summary.maxPreviewHostSuspendedHostCount, metrics.previewHostSuspendedHostCount)
            summary.maxPreviewHostActiveLeaseCount = max(summary.maxPreviewHostActiveLeaseCount, metrics.previewHostActiveLeaseCount)
            summary.maxPreviewHostPooledLayerCount = max(summary.maxPreviewHostPooledLayerCount, metrics.previewHostPooledLayerCount)
            summary.totalPreviewHostPoolReuses += metrics.previewHostPoolReuseCount
            summary.totalFilters += metrics.filterProcessingTimes.count
            summary.totalMemoryAllocated += metrics.totalMemoryAllocated
            summary.peakMemoryAllocation = max(summary.peakMemoryAllocation, metrics.peakMemoryAllocation)
            summary.totalErrors += metrics.errors.count
            if metrics.totalProcessingTime > summary.longestOperationTime {
                summary.longestOperationTime = metrics.totalProcessingTime
            }
            if summary.shortestOperationTime == 0 || metrics.totalProcessingTime < summary.shortestOperationTime {
                summary.shortestOperationTime = metrics.totalProcessingTime
            }
        }
        let totalOps = Double(metricsCache.count)
        if totalOps > 0 {
            summary.averageProcessingTime = summary.totalProcessingTime / totalOps
            summary.averageCPUTime = summary.totalCPUTime / totalOps
            summary.averageGPUTime = summary.totalGPUTime / totalOps
            summary.averageGPUUtilization = summary.averageGPUUtilization / totalOps
            if summary.totalProcessingTime > 0 {
                summary.gpuCpuRatio = summary.totalGPUTime / summary.totalProcessingTime
            }
        }
        return summary
    }
    
    private func initializeMetricsIfNeeded(_ identifier: String) {
        if metricsCache[identifier] == nil {
            metricsCache[identifier] = Metrics(startTime: CACurrentMediaTime())
            pendingGPUOperations[identifier] = 0
        }
    }
    
    private func logMetrics(_ metrics: Metrics, for identifier: String, isFinal: Bool = false) {
        guard configuration.logLevel >= .info else { return }
        let totalTimeStr = String(format: "%.3f", metrics.totalProcessingTime * 1000)
        let cpuTimeStr = String(format: "%.3f", metrics.cpuTime * 1000)
        let gpuTime = metrics.gpuTotalTime
        let gpuTimeStr = gpuTime > 0 ? String(format: "%.3f", gpuTime * 1000) : "0.000"
        let gpuUtilizationStr = String(format: "%.1f", metrics.gpuUtilization * 100)
        let texHit = String(format: "%.1f", metrics.textureCacheHitRate * 100)
        let pipelineHit = String(format: "%.1f", metrics.pipelineCacheHitRate * 100)
        let memAlloc = String(format: "%.1f", Double(metrics.totalMemoryAllocated) / 1_000_000)
        let peakMem = String(format: "%.1f", Double(metrics.peakMemoryAllocation) / 1_000_000)
        var counterStr = ""
        if !metrics.performanceCounters.isEmpty {
            let counters = metrics.performanceCounters.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            counterStr = "\nPerformance Counters: \(counters)"
        }
        var filterStr = ""
        if !metrics.filterProcessingTimes.isEmpty {
            if let slowest = metrics.slowestFilter {
                filterStr += "\nSlowest Filter: \(slowest.name) (\(String(format: "%.2f", slowest.time * 1000))ms)"
            }
            if let fastest = metrics.fastestFilter {
                filterStr += "\nFastest Filter: \(fastest.name) (\(String(format: "%.2f", fastest.time * 1000))ms)"
            }
            let avgFilterTime = String(format: "%.2f", metrics.averageFilterTime * 1000)
            filterStr += "\nAverage Filter Time: \(avgFilterTime)ms"
            filterStr += "\nTotal Filters: \(metrics.filterProcessingTimes.count)"
        }
        HarbethLogger.log(
            .info,
            category: "performance",
            code: "harbeth.performance.summary",
            outcome: .observed,
            correlationID: identifier,
            message: """
                \(identifier):
                Total Time: \(totalTimeStr)ms | CPU Time: \(cpuTimeStr)ms | GPU Time: \(gpuTimeStr)ms
                GPU Utilization: \(gpuUtilizationStr)% | Texture Hit Rate: \(texHit)% | Pipeline Hit Rate: \(pipelineHit)%
                Memory Allocated: \(memAlloc) MB | Peak Memory: \(peakMem) MB | Errors: \(metrics.errors.count)\(filterStr)\(counterStr)
                """
        )
        if isFinal && configuration.logLevel >= .warning {
            if gpuTime > configuration.gpuTimeWarningThreshold {
                HarbethLogger.log(
                    .warning,
                    category: "performance",
                    code: "harbeth.performance.gpu_budget_exceeded",
                    outcome: .degraded,
                    metadata: [
                        "actualMilliseconds": gpuTimeStr,
                        "thresholdMilliseconds": String(Int(configuration.gpuTimeWarningThreshold * 1000))
                    ],
                    correlationID: identifier,
                    message: "GPU time \(gpuTimeStr)ms exceeded \(Int(configuration.gpuTimeWarningThreshold * 1000))ms"
                )
            }
            if metrics.cpuTime > configuration.cpuTimeWarningThreshold {
                HarbethLogger.log(
                    .warning,
                    category: "performance",
                    code: "harbeth.performance.cpu_budget_exceeded",
                    outcome: .degraded,
                    metadata: [
                        "actualMilliseconds": cpuTimeStr,
                        "thresholdMilliseconds": String(Int(configuration.cpuTimeWarningThreshold * 1000))
                    ],
                    correlationID: identifier,
                    message: "CPU time \(cpuTimeStr)ms exceeded \(Int(configuration.cpuTimeWarningThreshold * 1000))ms"
                )
            }
        }
    }
}

extension PerformanceMonitor {
    public struct Summary {
        public var totalOperations: Int = 0
        public var totalProcessingTime: TimeInterval = 0
        public var averageProcessingTime: TimeInterval = 0
        public var longestOperationTime: TimeInterval = 0
        public var shortestOperationTime: TimeInterval = 0
        public var totalCPUTime: TimeInterval = 0
        public var averageCPUTime: TimeInterval = 0
        public var totalGPUTime: TimeInterval = 0
        public var averageGPUTime: TimeInterval = 0
        public var averageGPUUtilization: Double = 0
        public var gpuCpuRatio: Double = 0
        public var totalTextureCreations: Int = 0
        public var totalTextureReuses: Int = 0
        public var totalPipelineCacheHits: Int = 0
        public var totalPipelineCacheMisses: Int = 0
        public var totalImageResolutionCacheHits: Int = 0
        public var totalImageResolutionCacheMisses: Int = 0
        public var totalStages: Int = 0
        public var totalReadbackBoundaries: Int = 0
        public var totalPixelFormatConversions: Int = 0
        public var totalAlphaConversions: Int = 0
        public var totalColorConversions: Int = 0
        public var totalRenderTargetCreations: Int = 0
        public var totalOptimizerDecisions: Int = 0
        public var totalTextureLifecycleDecisions: Int = 0
        public var totalPreviewHostMetalStrategyDecisions: Int = 0
        public var totalPreviewHostPassthroughStrategyDecisions: Int = 0
        public var totalPreviewHostRematerializedStrategyDecisions: Int = 0
        public var totalPreviewHostEnqueues: Int = 0
        public var totalPreviewHostRecoveries: Int = 0
        public var totalPreviewHostFallbacks: Int = 0
        public var totalPreviewHostPredictionDrifts: Int = 0
        public var totalPreviewHostVisibilityPauses: Int = 0
        public var totalPreviewHostVisibilityResumes: Int = 0
        public var totalPreviewHostLifecyclePauses: Int = 0
        public var totalPreviewHostLifecycleResumes: Int = 0
        public var totalPreviewHostFailures: Int = 0
        public var totalPreviewHostStrategySwitches: Int = 0
        public var totalPreviewHostActivations: Int = 0
        public var totalPreviewHostDeactivations: Int = 0
        public var maxPreviewHostConcurrentSampleBufferHosts: Int = 0
        public var maxPreviewHostSuspendedHostCount: Int = 0
        public var maxPreviewHostActiveLeaseCount: Int = 0
        public var maxPreviewHostPooledLayerCount: Int = 0
        public var totalPreviewHostPoolReuses: Int = 0
        public var totalFilters: Int = 0
        public var totalMemoryAllocated: Int = 0
        public var peakMemoryAllocation: Int = 0
        public var totalErrors: Int = 0
        
        public var textureCacheHitRate: Double {
            let total = totalTextureCreations + totalTextureReuses
            return total > 0 ? Double(totalTextureReuses) / Double(total) : 0
        }

        public var pipelineCacheHitRate: Double {
            let total = totalPipelineCacheHits + totalPipelineCacheMisses
            return total > 0 ? Double(totalPipelineCacheHits) / Double(total) : 0
        }

        public var imageResolutionCacheHitRate: Double {
            let total = totalImageResolutionCacheHits + totalImageResolutionCacheMisses
            return total > 0 ? Double(totalImageResolutionCacheHits) / Double(total) : 0
        }
    }
    
    public struct Metrics {
        public var startTime: TimeInterval = 0
        public var endTime: TimeInterval = 0
        public var gpuTotalTimeNanoseconds: UInt64 = 0
        public var totalProcessingTime: TimeInterval {
            guard endTime > 0 else { return 0 }
            return endTime - startTime
        }
        public var gpuTotalTime: TimeInterval {
            TimeInterval(gpuTotalTimeNanoseconds) / 1_000_000_000.0
        }
        public var cpuTime: TimeInterval {
            totalProcessingTime - gpuTotalTime
        }
        public var gpuUtilization: Double {
            totalProcessingTime > 0 ? gpuTotalTime / totalProcessingTime : 0
        }
        public var textureCreations: Int = 0
        public var textureReuses: Int = 0
        public var pipelineCacheHits: Int = 0
        public var pipelineCacheMisses: Int = 0
        public var imageResolutionCacheHits: Int = 0
        public var imageResolutionCacheMisses: Int = 0
        public var stageCount: Int = 0
        public var readbackBoundaryCount: Int = 0
        public var pixelFormatConversions: Int = 0
        public var alphaConversions: Int = 0
        public var colorConversions: Int = 0
        public var renderTargetCreations: Int = 0
        public var optimizerDecisionCount: Int = 0
        public var textureLifecycleDecisionCount: Int = 0
        public var previewHostMetalStrategyCount: Int = 0
        public var previewHostPassthroughStrategyCount: Int = 0
        public var previewHostRematerializedStrategyCount: Int = 0
        public var previewHostEnqueueCount: Int = 0
        public var previewHostRecoveryCount: Int = 0
        public var previewHostFallbackCount: Int = 0
        public var previewHostPredictionDriftCount: Int = 0
        public var previewHostVisibilityPauseCount: Int = 0
        public var previewHostVisibilityResumeCount: Int = 0
        public var previewHostLifecyclePauseCount: Int = 0
        public var previewHostLifecycleResumeCount: Int = 0
        public var previewHostFailureCount: Int = 0
        public var previewHostStrategySwitchCount: Int = 0
        public var previewHostActivationCount: Int = 0
        public var previewHostDeactivationCount: Int = 0
        public var previewHostActiveLeaseCount: Int = 0
        public var previewHostPooledLayerCount: Int = 0
        public var previewHostPoolReuseCount: Int = 0
        public var previewHostConcurrentSampleBufferHostCount: Int = 0
        public var previewHostMaxConcurrentSampleBufferHostCount: Int = 0
        public var previewHostSuspendedHostCount: Int = 0
        public var previewHostSuspensionReasons: [String: Int] = [:]
        public var previewHostFailureReasons: [String: Int] = [:]
        public var previewHostFleetFailureReasons: [String: Int] = [:]
        public var previewHostFleetStrategySwitchCount: Int = 0
        public var previewHostFleetActivationCount: Int = 0
        public var previewHostFleetDeactivationCount: Int = 0
        public var previewHostFleetRecoveryCount: Int = 0
        public var previewHostFleetFallbackCount: Int = 0
        public var previewHostExecutionState: String?
        public var textureCacheHitRate: Double {
            let total = textureCreations + textureReuses
            return total > 0 ? Double(textureReuses) / Double(total) : 0
        }

        public var pipelineCacheHitRate: Double {
            let total = pipelineCacheHits + pipelineCacheMisses
            return total > 0 ? Double(pipelineCacheHits) / Double(total) : 0
        }

        public var imageResolutionCacheHitRate: Double {
            let total = imageResolutionCacheHits + imageResolutionCacheMisses
            return total > 0 ? Double(imageResolutionCacheHits) / Double(total) : 0
        }
        public var filterProcessingTimes: [String: TimeInterval] = [:]
        public var performanceCounters: [String: Double] = [:]
        public var memoryAllocations: [MemoryAllocation] = []
        public var errors: [String] = []
        public var resourceEvents: [String] = []
        public struct MemoryAllocation {
            public let timestamp: TimeInterval
            public let bytes: Int
            public let source: String
        }
        
        public init(startTime: TimeInterval = CACurrentMediaTime()) {
            self.startTime = startTime
        }
        
        public mutating func reset() {
            startTime = CACurrentMediaTime()
            endTime = 0
            gpuTotalTimeNanoseconds = 0
            textureCreations = 0
            textureReuses = 0
            pipelineCacheHits = 0
            pipelineCacheMisses = 0
            imageResolutionCacheHits = 0
            imageResolutionCacheMisses = 0
            stageCount = 0
            readbackBoundaryCount = 0
            pixelFormatConversions = 0
            alphaConversions = 0
            colorConversions = 0
            renderTargetCreations = 0
            optimizerDecisionCount = 0
            textureLifecycleDecisionCount = 0
            previewHostMetalStrategyCount = 0
            previewHostPassthroughStrategyCount = 0
            previewHostRematerializedStrategyCount = 0
            previewHostEnqueueCount = 0
            previewHostRecoveryCount = 0
            previewHostFallbackCount = 0
            previewHostPredictionDriftCount = 0
            previewHostVisibilityPauseCount = 0
            previewHostVisibilityResumeCount = 0
            previewHostLifecyclePauseCount = 0
            previewHostLifecycleResumeCount = 0
            previewHostFailureCount = 0
            previewHostStrategySwitchCount = 0
            previewHostActivationCount = 0
            previewHostDeactivationCount = 0
            previewHostActiveLeaseCount = 0
            previewHostPooledLayerCount = 0
            previewHostPoolReuseCount = 0
            previewHostConcurrentSampleBufferHostCount = 0
            previewHostMaxConcurrentSampleBufferHostCount = 0
            previewHostSuspendedHostCount = 0
            previewHostSuspensionReasons.removeAll()
            previewHostFailureReasons.removeAll()
            previewHostFleetFailureReasons.removeAll()
            previewHostFleetStrategySwitchCount = 0
            previewHostFleetActivationCount = 0
            previewHostFleetDeactivationCount = 0
            previewHostFleetRecoveryCount = 0
            previewHostFleetFallbackCount = 0
            previewHostExecutionState = nil
            filterProcessingTimes.removeAll()
            performanceCounters.removeAll()
            memoryAllocations.removeAll()
            errors.removeAll()
            resourceEvents.removeAll()
        }
        
        public var slowestFilter: (name: String, time: TimeInterval)? {
            filterProcessingTimes.max(by: { $0.value < $1.value }).map { (name: $0.key, time: $0.value) }
        }
        
        public var fastestFilter: (name: String, time: TimeInterval)? {
            filterProcessingTimes.min(by: { $0.value < $1.value }).map { (name: $0.key, time: $0.value) }
        }
        
        public var averageFilterTime: TimeInterval {
            guard !filterProcessingTimes.isEmpty else { return 0 }
            let totalTime = filterProcessingTimes.values.reduce(0, +)
            return totalTime / Double(filterProcessingTimes.count)
        }
        
        public var totalMemoryAllocated: Int {
            memoryAllocations.reduce(0) { $0 + $1.bytes }
        }
        
        public var peakMemoryAllocation: Int {
            guard !memoryAllocations.isEmpty else { return 0 }
            var currentPeak = 0
            var currentTotal = 0
            for allocation in memoryAllocations {
                currentTotal += allocation.bytes
                if currentTotal > currentPeak {
                    currentPeak = currentTotal
                }
            }
            return currentPeak
        }
    }
}
