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
        
        public init(enabled: Bool = true, logLevel: LogLevel = .info, maxStoredMetrics: Int = 100, autoCleanupInterval: TimeInterval = 300) {
            self.enabled = enabled
            self.logLevel = logLevel
            self.maxStoredMetrics = maxStoredMetrics
            self.autoCleanupInterval = autoCleanupInterval
        }
    }
    
    public enum LogLevel: Int, Comparable {
        case error = 0
        case warning = 1
        case info = 2
        case debug = 3
        
        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    private var metricsCache: [String: PerformanceMetrics] = [:]
    private let cacheLock = NSLock()
    private let cleanupTimer: DispatchSourceTimer
    private var configuration = Configuration()
    
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
    
    @discardableResult
    public func beginMonitoring(_ identifier: String) -> PerformanceMetrics {
        guard configuration.enabled else {
            return PerformanceMetrics()
        }
        let startTime = CACurrentMediaTime()
        let metrics = PerformanceMetrics(startTime: startTime)
        cacheLock.lock()
        metricsCache[identifier] = metrics
        cacheLock.unlock()
        
        return metrics
    }
    
    @discardableResult
    public func endMonitoring(_ identifier: String) -> PerformanceMetrics? {
        guard configuration.enabled else {
            return nil
        }
        cacheLock.lock()
        var currentMetrics = metricsCache[identifier]
        currentMetrics?.endTime = CACurrentMediaTime()
        if let metrics = currentMetrics {
            metricsCache[identifier] = metrics
            logMetrics(metrics, for: identifier)
        }
        cacheLock.unlock()
        
        return currentMetrics
    }
    
    /// Record texture creation or reuse
    public func recordTextureCreation(_ identifier: String, created: Bool = true) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        if metricsCache[identifier] == nil {
            metricsCache[identifier] = PerformanceMetrics()
        }
        if created {
            metricsCache[identifier]?.textureCreations += 1
        } else {
            metricsCache[identifier]?.textureReuses += 1
        }
        cacheLock.unlock()
    }
    
    /// Record command buffer creation or reuse
    public func recordCommandBufferCreation(_ identifier: String, created: Bool = true) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        if metricsCache[identifier] == nil {
            metricsCache[identifier] = PerformanceMetrics()
        }
        if created {
            metricsCache[identifier]?.commandBuffersCreated += 1
        } else {
            metricsCache[identifier]?.commandBuffersReused += 1
        }
        cacheLock.unlock()
    }
    
    /// Record filter processing time
    public func recordFilterProcessing(_ identifier: String, filterName: String, duration: TimeInterval) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        if metricsCache[identifier] == nil {
            metricsCache[identifier] = PerformanceMetrics()
        }
        metricsCache[identifier]?.filterProcessingTimes[filterName] = duration
        cacheLock.unlock()
    }
    
    /// Record memory allocation
    public func recordMemoryAllocation(_ identifier: String, bytes: Int, source: String) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        if metricsCache[identifier] == nil {
            metricsCache[identifier] = PerformanceMetrics()
        }
        metricsCache[identifier]?.memoryAllocations.append(.init(timestamp: CACurrentMediaTime(), bytes: bytes, source: source))
        cacheLock.unlock()
    }
    
    public func recordError(_ identifier: String, error: Error) {
        guard configuration.enabled else { return }
        cacheLock.lock()
        if metricsCache[identifier] == nil {
            metricsCache[identifier] = PerformanceMetrics()
        }
        metricsCache[identifier]?.errors.append(error.localizedDescription)
        if configuration.logLevel >= .error {
            print("[PerformanceMonitor Error] \(identifier): \(error.localizedDescription)")
        }
        cacheLock.unlock()
    }
    
    /// Get performance metrics for an identifier
    public func getMetrics(_ identifier: String) -> PerformanceMetrics? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return metricsCache[identifier]
    }
    
    /// Clean up old metrics
    public func cleanupOldMetrics(maxAge: TimeInterval = 300) {
        guard configuration.enabled else { return }
        let now = CACurrentMediaTime()
        cacheLock.lock()
        metricsCache = metricsCache.filter { identifier, metrics in
            let endTime = metrics.endTime > 0 ? metrics.endTime : metrics.startTime
            return now - endTime < maxAge
        }
        // Also limit the total number of stored metrics
        if metricsCache.count > configuration.maxStoredMetrics {
            let sorted = metricsCache.sorted { $0.value.startTime < $1.value.startTime }
            let toRemove = sorted.prefix(metricsCache.count - configuration.maxStoredMetrics)
            for (key, _) in toRemove {
                metricsCache.removeValue(forKey: key)
            }
        }
        cacheLock.unlock()
    }
    
    @discardableResult
    public func measure<T>(_ identifier: String, _ operation: String, _ block: () throws -> T) rethrows -> T {
        guard configuration.enabled else {
            return try block()
        }
        let startTime = CACurrentMediaTime()
        do {
            let result = try block()
            let duration = CACurrentMediaTime() - startTime
            recordFilterProcessing(identifier, filterName: operation, duration: duration)
            if configuration.logLevel >= .debug {
                print("[PerformanceMonitor Debug] \(identifier) - \(operation): \(duration)s")
            }
            return result
        } catch {
            let duration = CACurrentMediaTime() - startTime
            recordFilterProcessing(identifier, filterName: operation, duration: duration)
            recordError(identifier, error: error)
            throw error
        }
    }
    
    /// Clear all metrics
    public func clearAllMetrics() {
        cacheLock.lock()
        metricsCache.removeAll()
        cacheLock.unlock()
    }
    
    /// Get summary statistics for all metrics
    public func getSummary() -> PerformanceSummary {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        var summary = PerformanceSummary()
        summary.totalOperations = metricsCache.count
        for (_, metrics) in metricsCache {
            summary.totalProcessingTime += metrics.totalProcessingTime
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
        
        let totalOperations = Double(metricsCache.count)
        if totalOperations > 0 {
            summary.averageProcessingTime = summary.totalProcessingTime / totalOperations
        }
        return summary
    }
    
    private func logMetrics(_ metrics: PerformanceMetrics, for identifier: String) {
        guard configuration.logLevel >= .info else { return }
        let textureCacheHitRate = metrics.textureCacheHitRate
        let bufferCacheHitRate = metrics.bufferCacheHitRate
        print("""
        [PerformanceMonitor Info] \(identifier):
        Total time: \(String(format: "%.3f", metrics.totalProcessingTime))s
        Texture cache hit rate: \(String(format: "%.1f", textureCacheHitRate * 100))%
        Buffer cache hit rate: \(String(format: "%.1f", bufferCacheHitRate * 100))%
        Errors: \(metrics.errors.count)
        """)
    }
}

extension PerformanceMonitor {
    public struct PerformanceSummary {
        public var totalOperations: Int = 0
        public var totalProcessingTime: TimeInterval = 0
        public var averageProcessingTime: TimeInterval = 0
        public var longestOperationTime: TimeInterval = 0
        public var shortestOperationTime: TimeInterval = 0
        public var totalTextureCreations: Int = 0
        public var totalTextureReuses: Int = 0
        public var totalCommandBuffersCreated: Int = 0
        public var totalCommandBuffersReused: Int = 0
        public var totalErrors: Int = 0
        
        public var textureCacheHitRate: Double {
            let total = totalTextureCreations + totalTextureReuses
            guard total > 0 else { return 0 }
            return Double(totalTextureReuses) / Double(total)
        }
        
        public var commandBufferCacheHitRate: Double {
            let total = totalCommandBuffersCreated + totalCommandBuffersReused
            guard total > 0 else { return 0 }
            return Double(totalCommandBuffersReused) / Double(total)
        }
    }
}

extension PerformanceMonitor {
    public struct PerformanceMetrics {
        public var startTime: TimeInterval = 0
        public var endTime: TimeInterval = 0
        public var totalProcessingTime: TimeInterval {
            guard endTime > 0 else { return 0 }
            return endTime - startTime
        }
        
        public var textureCreations: Int = 0
        public var textureReuses: Int = 0
        public var textureCacheHitRate: Double {
            let total = textureCreations + textureReuses
            guard total > 0 else { return 0 }
            return Double(textureReuses) / Double(total)
        }
        
        public var commandBuffersCreated: Int = 0
        public var commandBuffersReused: Int = 0
        public var bufferCacheHitRate: Double {
            let total = commandBuffersCreated + commandBuffersReused
            guard total > 0 else { return 0 }
            return Double(commandBuffersReused) / Double(total)
        }
        
        public var filterProcessingTimes: [String: TimeInterval] = [:]
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
            textureCreations = 0
            textureReuses = 0
            commandBuffersCreated = 0
            commandBuffersReused = 0
            filterProcessingTimes.removeAll()
            memoryAllocations.removeAll()
            errors.removeAll()
        }
        
        /// Get the slowest filter in the processing chain
        public var slowestFilter: (name: String, time: TimeInterval)? {
            var slowest: (String, TimeInterval)? = nil
            for (name, time) in filterProcessingTimes {
                if let current = slowest {
                    if time > current.1 {
                        slowest = (name, time)
                    }
                } else {
                    slowest = (name, time)
                }
            }
            return slowest
        }
        
        /// Get total memory allocated during operation
        public var totalMemoryAllocated: Int {
            return memoryAllocations.reduce(0) { $0 + $1.bytes }
        }
    }
}
