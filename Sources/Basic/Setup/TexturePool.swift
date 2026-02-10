//
//  TexturePool.swift
//  Harbeth
//
//  Created by Condy on 2025/5/5.
//

import Foundation
import Metal

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
    
    /// Max memory usage: 10% of physical RAM, capped at 512 MB.
    private let maxMemoryUsage: Int
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
    
    #if os(macOS)
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    #endif
    
    #if canImport(os)
    private var lock = os_unfair_lock_s()
    private func withLock<T>(_ work: () -> T) -> T {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return work()
    }
    #else
    private let lock = NSLock()
    private func withLock<T>(_ work: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return work()
    }
    #endif
    
    init() {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let limitMB = min(physicalMemory / 1024 / 1024 / 10, 512)
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
            }
        }
        source.resume()
        self.memoryPressureSource = source
        #endif
    }
    
    deinit {
        #if os(iOS)
        NotificationCenter.default.removeObserver(self)
        #elseif os(macOS)
        memoryPressureSource?.cancel()
        memoryPressureSource = nil
        #endif
        print("TexturePool is deinit.")
    }
    
    /// Attempts to dequeue a reusable texture matching the given specs.
    /// Uses size tolerance to improve hit rate.
    public func dequeueTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat) -> MTLTexture? {
        let exactKey = TextureKey(width: width, height: height, pixelFormat: pixelFormat)
        return withLock {
            // 1. Try exact match
            if let texture = popFromCache(forKey: exactKey) {
                return texture
            }
            // 2. Try tolerant match (within ±sizeTolerance)
            for (key, textures) in cache where key.pixelFormat == pixelFormat && !textures.isEmpty {
                if abs(key.width - width) <= sizeTolerance && abs(key.height - height) <= sizeTolerance {
                    if let texture = popFromCache(forKey: key) {
                        return texture
                    }
                }
            }
            return nil
        }
    }
    
    /// Returns a texture to the pool for reuse.
    /// Silently ignores invalid or already-pooled textures.
    public func enqueueTexture(_ texture: MTLTexture) {
        let key = TextureKey(width: texture.width, height: texture.height, pixelFormat: texture.pixelFormat)
        let oid = ObjectIdentifier(texture)
        withLock {
            if textureToKey[oid] != nil {
                return
            }
            let textureSize = estimatedByteSize(of: texture)
            let newTotal = currentMemoryUsage + textureSize
            // Evict until under memory limit
            while newTotal > maxMemoryUsage && !accessQueue.isEmpty {
                let oldestKey = accessQueue.removeFirst()
                if var oldList = cache[oldestKey], !oldList.isEmpty {
                    let oldTexture = oldList.removeLast()
                    cache[oldestKey] = oldList.isEmpty ? nil : oldList
                    let oldOid = ObjectIdentifier(oldTexture)
                    textureToKey[oldOid] = nil
                    currentMemoryUsage -= estimatedByteSize(of: oldTexture)
                }
            }
            // Only enqueue if still under limit
            if currentMemoryUsage + textureSize <= maxMemoryUsage {
                cache[key, default: []].append(texture)
                textureToKey[oid] = key
                if !accessQueue.contains(key) {
                    accessQueue.append(key)
                }
                currentMemoryUsage += textureSize
            }
        }
    }
    
    private func popFromCache(forKey key: TextureKey) -> MTLTexture? {
        guard var list = cache[key], !list.isEmpty else { return nil }
        let texture = list.removeLast()
        cache[key] = list.isEmpty ? nil : list
        if let index = accessQueue.firstIndex(of: key) {
            accessQueue.remove(at: index)
            accessQueue.append(key)
        }
        let oid = ObjectIdentifier(texture)
        textureToKey[oid] = nil
        currentMemoryUsage -= estimatedByteSize(of: texture)
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
        withLock {
            cache.removeAll()
            accessQueue.removeAll()
            textureToKey.removeAll()
            currentMemoryUsage = 0
        }
        PerformanceMonitor.shared.recordTextureCreation("texture_pool_purged", created: false)
    }
}
