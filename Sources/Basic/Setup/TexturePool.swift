//
//  TexturePool.swift
//  Harbeth
//
//  Created by Condy on 2025/5/5.
//

import Foundation
import Metal
import Darwin

#if os(iOS)
import UIKit
#endif

/// Enhanced texture pool with LRU, precise memory tracking, and cross-platform memory pressure handling.
public final class TexturePool {
    private struct TextureKey: Hashable {
        let width: Int, height: Int, pixelFormat: MTLPixelFormat
        func hash(into hasher: inout Hasher) {
            hasher.combine(width)
            hasher.combine(height)
            hasher.combine(pixelFormat.rawValue)
        }
    }
    
    /// Max memory usage: Dynamic based on device memory, capped at 512 MB.
    private var maxMemoryUsage: Int
    /// Allow reuse of textures within ±8 pixels to improve hit rate (e.g., 1920x1080 can reuse 1928x1080).
    private let sizeTolerance: Int = 8
    
    /// Cache key → list of available textures (stack: LIFO for better locality)
    private var cache: [TextureKey: [MTLTexture]] = [:]
    /// Tracks access order for LRU eviction (FIFO queue)
    private var accessQueue: [TextureKey] = []
    /// Reverse lookup: which key a texture belongs to (for safe re-enqueue check)
    private var textureToKey: [ObjectIdentifier: TextureKey] = [:]
    /// Current estimated GPU memory usage in bytes.
    private var currentMemoryUsage: Int = 0
    
    /// Dynamic memory management
    private var memoryPressureLevel: Int = 0 // 0: normal, 1: warning, 2: critical
    private let memoryMonitoringInterval: TimeInterval = 5.0
    private var memoryMonitorTimer: Timer?
    
    private let queue = DispatchQueue(label: "com.harbeth.texturepool.concurrent", attributes: .concurrent)
    
    public struct Statistics {
        public var totalTexturesCreated: Int = 0
        public var totalTexturesReused: Int = 0
        public var totalMemorySaved: Int = 0
        public var hitRate: Double {
            totalTexturesReused > 0 ? Double(totalTexturesReused) / Double(totalTexturesCreated + totalTexturesReused) : 0
        }
        public var currentTextureCount: Int = 0
        public var currentMemoryUsage: Int = 0
        public var maxMemoryUsage: Int = 0
        public var peakMemoryUsage: Int = 0
        public var averageMemoryUsage: Double = 0
        public var memoryUsageSamples: [Int] = []
    }
    
    public private(set) var statistics = Statistics()
    
    /// Commonly used resolution cache to improve matching efficiency
    private var commonResolutions: Set<TextureKey> = []
    
    #if os(macOS)
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    #endif
    
    init() {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let physicalMemoryMB = physicalMemory / 1024 / 1024
        // Dynamic memory limit based on device memory
        var memoryPercentage: Double
        if physicalMemoryMB < 2048 { // < 2GB
            memoryPercentage = 0.05 // 5%
        } else if physicalMemoryMB < 4096 { // < 4GB
            memoryPercentage = 0.07 // 7%
        } else { // >= 4GB
            memoryPercentage = 0.10 // 10%
        }
        let limitMB = min(Int(Double(physicalMemoryMB) * memoryPercentage), 512)
        self.maxMemoryUsage = Int(limitMB * 1024 * 1024)
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        #elseif os(macOS)
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.critical, .warning])
        source.setEventHandler { [weak self] in
            let currentPressure = source.mask
            if currentPressure.contains(.critical) {
                self?.purgeAllTextures()
            } else if currentPressure.contains(.warning) {
                self?.purgeLeastUsedTextures()
            }
        }
        source.resume()
        self.memoryPressureSource = source
        #endif
        
        startMemoryMonitoring()
    }
    
    deinit {
        #if os(iOS)
        NotificationCenter.default.removeObserver(self)
        #elseif os(macOS)
        memoryPressureSource?.cancel()
        memoryPressureSource = nil
        #endif
        memoryMonitorTimer?.invalidate()
        print("TexturePool is deinit.")
    }
    
    private func startMemoryMonitoring() {
        #if os(iOS)
        memoryMonitorTimer = Timer.scheduledTimer(
            timeInterval: memoryMonitoringInterval,
            target: self,
            selector: #selector(checkMemoryPressure),
            userInfo: nil,
            repeats: true
        )
        #endif
    }
    
    @objc private func checkMemoryPressure() {
        #if os(iOS)
        let currentUsage = Double(currentMemoryUsage)
        let maxUsage = Double(maxMemoryUsage)
        let memoryPressure = currentUsage / maxUsage
        if memoryPressure > 0.9 {
            memoryPressureLevel = 2
            purgeAllTextures()
        } else if memoryPressure > 0.7 {
            memoryPressureLevel = 1
            purgeLeastUsedTextures()
        } else {
            memoryPressureLevel = 0
        }
        #endif
    }
    
    private func purgeLeastUsedTextures() {
        queue.async(flags: .barrier) {
            let releaseCount = min(self.accessQueue.count, 3)
            for _ in 0..<releaseCount {
                if !self.accessQueue.isEmpty {
                    let oldestKey = self.accessQueue.removeFirst()
                    if let textures = self.cache[oldestKey] {
                        for texture in textures {
                            let oid = ObjectIdentifier(texture)
                            self.textureToKey[oid] = nil
                            self.currentMemoryUsage -= self.estimatedByteSize(of: texture)
                        }
                        self.cache[oldestKey] = nil
                        self.commonResolutions.remove(oldestKey)
                    }
                }
            }
            self.statistics.currentTextureCount = self.cache.values.reduce(0) { $0 + $1.count }
            self.updateMemoryUsageStatistics()
        }
    }
    
    /// Attempts to dequeue a reusable texture matching the given specs.
    /// Uses size tolerance to improve hit rate.
    public func dequeueTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat) -> MTLTexture? {
        let exactKey = TextureKey(width: width, height: height, pixelFormat: pixelFormat)
        var result: MTLTexture? = nil
        
        queue.sync(flags: .barrier) {
            // 1. Try exact match
            if let texture = popFromCache(forKey: exactKey) {
                statistics.totalTexturesReused += 1
                statistics.totalMemorySaved += estimatedByteSize(of: texture)
                result = texture
                return
            }
            
            // 2. Try common resolutions first (optimized path)
            for key in commonResolutions where key.pixelFormat == pixelFormat {
                if abs(key.width - width) <= sizeTolerance && abs(key.height - height) <= sizeTolerance {
                    if let texture = popFromCache(forKey: key) {
                        statistics.totalTexturesReused += 1
                        statistics.totalMemorySaved += estimatedByteSize(of: texture)
                        result = texture
                        return
                    }
                }
            }
            
            // 3. Try tolerant match for all textures
            for (key, textures) in cache where key.pixelFormat == pixelFormat && !textures.isEmpty {
                if abs(key.width - width) <= sizeTolerance && abs(key.height - height) <= sizeTolerance {
                    if let texture = popFromCache(forKey: key) {
                        statistics.totalTexturesReused += 1
                        statistics.totalMemorySaved += estimatedByteSize(of: texture)
                        // Add to common resolutions
                        commonResolutions.insert(key)
                        result = texture
                        return
                    }
                }
            }
            
            statistics.totalTexturesCreated += 1
        }
        
        return result
    }
    
    /// Returns a texture to the pool for reuse.
    /// Silently ignores invalid or already-pooled textures.
    public func enqueueTexture(_ texture: MTLTexture) {
        let key = TextureKey(width: texture.width, height: texture.height, pixelFormat: texture.pixelFormat)
        let oid = ObjectIdentifier(texture)
        
        queue.async(flags: .barrier) {
            if self.textureToKey[oid] != nil {
                return
            }
            let textureSize = self.estimatedByteSize(of: texture)
            let newTotal = self.currentMemoryUsage + textureSize
            // Evict until under memory limit
            while newTotal > self.maxMemoryUsage && !self.accessQueue.isEmpty {
                let oldestKey = self.accessQueue.removeFirst()
                if var oldList = self.cache[oldestKey], !oldList.isEmpty {
                    let oldTexture = oldList.removeLast()
                    self.cache[oldestKey] = oldList.isEmpty ? nil : oldList
                    let oldOid = ObjectIdentifier(oldTexture)
                    self.textureToKey[oldOid] = nil
                    self.currentMemoryUsage -= self.estimatedByteSize(of: oldTexture)
                    self.statistics.currentTextureCount -= 1
                }
            }
            // Only enqueue if still under limit
            if self.currentMemoryUsage + textureSize <= self.maxMemoryUsage {
                self.cache[key, default: []].append(texture)
                self.textureToKey[oid] = key
                if !self.accessQueue.contains(key) {
                    self.accessQueue.append(key)
                }
                self.currentMemoryUsage += textureSize
                self.statistics.currentTextureCount += 1
                self.updateMemoryUsageStatistics()
            }
        }
    }
    

    
    public func prewarm(resolutions: [(width: Int, height: Int, pixelFormat: MTLPixelFormat)], count: Int = 2) {
        guard count > 0 else { return }
        
        let device = Device.device()
        queue.async(flags: .barrier) {
            for (width, height, pixelFormat) in resolutions {
                let key = TextureKey(width: width, height: height, pixelFormat: pixelFormat)
                let existingCount = self.cache[key]?.count ?? 0
                if existingCount >= count {
                    continue
                }
                let neededCount = count - existingCount
                for _ in 0..<neededCount {
                    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                        pixelFormat: pixelFormat,
                        width: width,
                        height: height,
                        mipmapped: false
                    )
                    descriptor.usage = [.shaderRead, .shaderWrite]
                    descriptor.storageMode = .shared
                    if let texture = device.makeTexture(descriptor: descriptor) {
                        let textureSize = self.estimatedByteSize(of: texture)
                        let newTotal = self.currentMemoryUsage + textureSize
                        if newTotal <= self.maxMemoryUsage {
                            self.cache[key, default: []].append(texture)
                            self.textureToKey[ObjectIdentifier(texture)] = key
                            if !self.accessQueue.contains(key) {
                                self.accessQueue.append(key)
                            }
                            self.currentMemoryUsage += textureSize
                            self.statistics.currentTextureCount += 1
                            self.statistics.currentMemoryUsage = self.currentMemoryUsage
                            self.statistics.maxMemoryUsage = max(self.statistics.maxMemoryUsage, self.currentMemoryUsage)
                            self.commonResolutions.insert(key)
                        }
                    }
                }
            }
        }
    }
    
    public func resetStatistics() {
        queue.async(flags: .barrier) {
            self.statistics = Statistics()
            self.statistics.currentTextureCount = self.cache.values.reduce(0) { $0 + $1.count }
            self.statistics.currentMemoryUsage = self.currentMemoryUsage
            self.statistics.maxMemoryUsage = max(self.statistics.maxMemoryUsage, self.currentMemoryUsage)
        }
    }
    
    private func updateMemoryUsageStatistics() {
        queue.async(flags: .barrier) {
            self.statistics.currentMemoryUsage = self.currentMemoryUsage
            self.statistics.peakMemoryUsage = max(self.statistics.peakMemoryUsage, self.currentMemoryUsage)
            
            // Update memory usage samples (keep last 100 samples)
            self.statistics.memoryUsageSamples.append(self.currentMemoryUsage)
            if self.statistics.memoryUsageSamples.count > 100 {
                self.statistics.memoryUsageSamples.removeFirst()
            }
            
            // Calculate average memory usage
            if !self.statistics.memoryUsageSamples.isEmpty {
                let total = self.statistics.memoryUsageSamples.reduce(0, +)
                self.statistics.averageMemoryUsage = Double(total) / Double(self.statistics.memoryUsageSamples.count)
            }
        }
    }
    
    /// Dumps current texture pool statistics for debugging
    public func dumpStatistics() {
        queue.sync {
            let stats = self.statistics
            print("=== TexturePool Statistics ===")
            print("Total textures created: \(stats.totalTexturesCreated)")
            print("Total textures reused: \(stats.totalTexturesReused)")
            print("Hit rate: \(String(format: "%.2f%%", stats.hitRate * 100))")
            print("Total memory saved: \(stats.totalMemorySaved / 1024 / 1024) MB")
            print("Current texture count: \(stats.currentTextureCount)")
            print("Current memory usage: \(stats.currentMemoryUsage / 1024 / 1024) MB")
            print("Peak memory usage: \(stats.peakMemoryUsage / 1024 / 1024) MB")
            print("Average memory usage: \(String(format: "%.2f", stats.averageMemoryUsage / 1024 / 1024)) MB")
            print("Max memory limit: \(self.maxMemoryUsage / 1024 / 1024) MB")
            print("Cache entries: \(self.cache.count)")
            print("Common resolutions: \(self.commonResolutions.count)")
            print("==============================")
        }
    }
    
    private func popFromCache(forKey key: TextureKey) -> MTLTexture? {
        guard let list = self.cache[key], !list.isEmpty else {
            return nil
        }
        var mutableList = list
        let texture = mutableList.removeLast()
        
        self.cache[key] = mutableList.isEmpty ? nil : mutableList
        
        if let index = self.accessQueue.firstIndex(of: key) {
            self.accessQueue.remove(at: index)
            self.accessQueue.append(key)
        }
        let oid = ObjectIdentifier(texture)
        self.textureToKey[oid] = nil
        self.currentMemoryUsage -= self.estimatedByteSize(of: texture)
        self.statistics.currentTextureCount -= 1
        self.updateMemoryUsageStatistics()
        
        return texture
    }
    
    /// Precise byte size estimation for common pixel formats.
    private func estimatedByteSize(of texture: MTLTexture) -> Int {
        let w = texture.width
        let h = texture.height
        switch texture.pixelFormat {
        case .rgba8Unorm, .bgra8Unorm, .rgba8Snorm:
            return w * h * 4
        case .rgba16Float:
            return w * h * 8
        case .r8Unorm, .r8Snorm:
            return w * h * 1
        case .rg8Unorm, .rg8Snorm:
            return w * h * 2
        case .r16Float, .rg16Float:
            return w * h * (texture.pixelFormat == .r16Float ? 2 : 4)
        case .rgba32Float:
            return w * h * 16
        default:
            return w * h * 4
        }
    }
    
    @objc private func didReceiveMemoryWarning() {
        purgeAllTextures()
    }
    
    @objc private func handleMemoryPressure() {
        purgeAllTextures()
    }
    
    private func purgeAllTextures() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
            self.accessQueue.removeAll()
            self.textureToKey.removeAll()
            self.commonResolutions.removeAll()
            self.currentMemoryUsage = 0
            self.statistics.currentTextureCount = 0
            self.updateMemoryUsageStatistics()
        }
        PerformanceMonitor.shared.recordTextureCreation("texture_pool_purged", created: false)
    }
}
