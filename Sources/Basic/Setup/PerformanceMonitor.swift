//
//  PerformanceMonitor.swift
//  Harbeth
//
//  Created by Condy on 2024/3/20.
//

import Foundation
import Metal

public final class PerformanceMonitor {
    public static let shared = PerformanceMonitor()
    
    public struct Configuration {
        public var enabled: Bool = true
        public var logLevel: LogLevel = .info
        public var maxStoredMetrics: Int = 100
        public var autoCleanupInterval: TimeInterval = 300
        public var gpuTimeWarningThreshold: TimeInterval = 0.016
        public var enablePerformanceCounters: Bool = false
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
    
    private init() {
        cleanupTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        cleanupTimer.schedule(deadline: .now(), repeating: configuration.autoCleanupInterval)
        cleanupTimer.setEventHandler { [weak self] in
            self?.cleanupOldMetrics(maxAge: self?.configuration.autoCleanupInterval ?? 300)
        }
        cleanupTimer.resume()
    }
    
    deinit {
        cleanupTimer.cancel()
    }
    
    public func configure(_ config: Configuration) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        self.configuration = config
    }
    
    public func beginMonitoring(_ identifier: String) -> Metrics {
        guard configuration.enabled else { return Metrics() }
        let metrics = Metrics(startTime: CACurrentMediaTime())
        cacheLock.lock()
        metricsCache[identifier] = metrics
        pendingGPUOperations[identifier] = 0
        cacheLock.unlock()
        return metrics
    }
    
    public func endMonitoring(_ identifier: String) -> Metrics? {
        guard configuration.enabled else { return nil }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        guard var metrics = metricsCache[identifier] else { return nil }
        metrics.endTime = CACurrentMediaTime()
        metricsCache[identifier] = metrics
        if pendingGPUOperations[identifier] == 0 {
            logMetrics(metrics, for: identifier, isFinal: true)
        }
        return metrics
    }
    
    public func recordTextureCreation(_ identifier: String, created: Bool = true) {
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
    
    public func recordCommandBufferCreation(_ identifier: String, created: Bool = true) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        if created {
            metricsCache[identifier]?.commandBuffersCreated += 1
        } else {
            metricsCache[identifier]?.commandBuffersReused += 1
        }
    }
    
    public func recordFilterProcessing(_ identifier: String, filterName: String, duration: TimeInterval) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.filterProcessingTimes[filterName] = duration
    }
    
    public func recordMemoryAllocation(_ identifier: String, bytes: Int, source: String) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        let alloc = Metrics.MemoryAllocation(timestamp: CACurrentMediaTime(), bytes: bytes, source: source)
        metricsCache[identifier]?.memoryAllocations.append(alloc)
    }
    
    public func recordError(_ identifier: String, error: Error) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        initializeMetricsIfNeeded(identifier)
        metricsCache[identifier]?.errors.append(error.localizedDescription)
        if configuration.logLevel >= .error {
            print("[PerformanceMonitor Error] \(identifier): \(error.localizedDescription)")
        }
    }
    
    public func getMetrics(_ identifier: String) -> Metrics? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return metricsCache[identifier]
    }
    
    public func cleanupOldMetrics(maxAge: TimeInterval = 300) {
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
    public func measure<T>(_ identifier: String, _ operation: String, _ block: () throws -> T) rethrows -> T {
        guard configuration.enabled else { return try block() }
        let startTime = CACurrentMediaTime()
        do {
            let result = try block()
            let duration = CACurrentMediaTime() - startTime
            recordFilterProcessing(identifier, filterName: operation, duration: duration)
            if configuration.logLevel >= .debug {
                print("[PerformanceMonitor Debug] \(identifier) - \(operation): \(String(format: "%.4f", duration))s")
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
            summary.totalGPUTime += metrics.gpuTotalTime
            summary.totalTextureCreations += metrics.textureCreations
            summary.totalTextureReuses += metrics.textureReuses
            summary.totalCommandBuffersCreated += metrics.commandBuffersCreated
            summary.totalCommandBuffersReused += metrics.commandBuffersReused
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
            summary.averageGPUTime = summary.totalGPUTime / totalOps
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
        let cpuTimeStr = String(format: "%.3f", metrics.totalProcessingTime * 1000)
        let gpuTime = metrics.gpuTotalTime
        let gpuStatus = (metrics.commandBuffersCreated > 0 && gpuTime == 0 && !isFinal) ? "(pending)" : (isFinal ? "(complete)" : "(partial)")
        let gpuTimeStr = gpuTime > 0 ? String(format: "%.3f", gpuTime * 1000) : "0.000"
        let texHit = String(format: "%.1f", metrics.textureCacheHitRate * 100)
        let bufHit = String(format: "%.1f", metrics.bufferCacheHitRate * 100)
        let memAlloc = String(format: "%.1f", Double(metrics.totalMemoryAllocated) / 1_000_000)
        
        var counterStr = ""
        if !metrics.performanceCounters.isEmpty {
            let counters = metrics.performanceCounters.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            counterStr = "\nPerformance Counters: \(counters)"
        }
        
        var slowestStr = ""
        if let slowest = metrics.slowestFilter {
            slowestStr = "\nSlowest Filter: \(slowest.name) (\(String(format: "%.2f", slowest.time * 1000))ms)"
        }
        
        print("""
        [PerformanceMonitor Info] \(identifier):
        CPU Time: \(cpuTimeStr)ms | GPU Time: \(gpuTimeStr)ms \(gpuStatus)
        Texture Hit Rate: \(texHit)% | Buffer Hit Rate: \(bufHit)%
        Memory Allocated: \(memAlloc) MB | Errors: \(metrics.errors.count)\(slowestStr)\(counterStr)
        """)
        
        if isFinal && configuration.logLevel >= .warning && gpuTime > configuration.gpuTimeWarningThreshold {
            print("⚠️ [PERF ALERT] \(identifier) exceeded GPU threshold: \(gpuTimeStr)ms > \(Int(configuration.gpuTimeWarningThreshold * 1000))ms")
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
        public var totalGPUTime: TimeInterval = 0
        public var averageGPUTime: TimeInterval = 0
        public var gpuCpuRatio: Double = 0
        public var totalTextureCreations: Int = 0
        public var totalTextureReuses: Int = 0
        public var totalCommandBuffersCreated: Int = 0
        public var totalCommandBuffersReused: Int = 0
        public var totalErrors: Int = 0
        
        public var textureCacheHitRate: Double {
            let total = totalTextureCreations + totalTextureReuses
            return total > 0 ? Double(totalTextureReuses) / Double(total) : 0
        }
        
        public var commandBufferCacheHitRate: Double {
            let total = totalCommandBuffersCreated + totalCommandBuffersReused
            return total > 0 ? Double(totalCommandBuffersReused) / Double(total) : 0
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
        
        public var textureCreations: Int = 0
        public var textureReuses: Int = 0
        public var textureCacheHitRate: Double {
            let total = textureCreations + textureReuses
            return total > 0 ? Double(textureReuses) / Double(total) : 0
        }
        
        public var commandBuffersCreated: Int = 0
        public var commandBuffersReused: Int = 0
        public var bufferCacheHitRate: Double {
            let total = commandBuffersCreated + commandBuffersReused
            return total > 0 ? Double(commandBuffersReused) / Double(total) : 0
        }
        
        public var filterProcessingTimes: [String: TimeInterval] = [:]
        public var performanceCounters: [String: Double] = [:]
        public var memoryAllocations: [MemoryAllocation] = []
        public var errors: [String] = []
        
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
            commandBuffersCreated = 0
            commandBuffersReused = 0
            filterProcessingTimes.removeAll()
            performanceCounters.removeAll()
            memoryAllocations.removeAll()
            errors.removeAll()
        }
        
        public var slowestFilter: (name: String, time: TimeInterval)? {
            filterProcessingTimes.max(by: { $0.value < $1.value })
                .map { (name: $0.key, time: $0.value) }
        }
        
        public var totalMemoryAllocated: Int {
            memoryAllocations.reduce(0) { $0 + $1.bytes }
        }
    }
}
