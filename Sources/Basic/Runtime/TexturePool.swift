//
//  TexturePool.swift
//  Harbeth
//
//  Created by Condy on 2025/5/5.
//

import Foundation
@preconcurrency import Metal

#if os(iOS) || os(tvOS)
import UIKit
#endif

/// Read-only snapshot of Harbeth's internal texture-pool activity.
public struct TexturePoolStatistics: Sendable {
    public internal(set) var totalTexturesCreated: Int = 0
    public internal(set) var totalTexturesReused: Int = 0
    public internal(set) var totalMemorySaved: Int = 0
    public internal(set) var currentTextureCount: Int = 0
    public internal(set) var currentMemoryUsage: Int = 0
    public internal(set) var maxMemoryUsage: Int = 0
    public internal(set) var peakMemoryUsage: Int = 0
    public internal(set) var averageMemoryUsage: Double = 0
    public internal(set) var memoryUsageSamples: [Int] = []
    public internal(set) var heapCount: Int = 0
    public internal(set) var heapReservedMemory: Int = 0
    public internal(set) var heapUsedMemory: Int = 0
    public internal(set) var heapTextureAllocationCount: Int = 0
    public internal(set) var heapAllocationFallbackCount: Int = 0

    public var hitRate: Double {
        let requestCount = totalTexturesCreated + totalTexturesReused
        return requestCount > 0 ? Double(totalTexturesReused) / Double(requestCount) : 0
    }
}

/// 带完整纹理契约、LRU、统一显存预算与真实 MTLHeap 的内部纹理资源池。
final class TexturePool: @unchecked Sendable {
    struct PrewarmRequest: Sendable, Equatable, Hashable {
        let width: Int
        let height: Int
        let pixelFormat: MTLPixelFormat
        let count: Int

        init(width: Int, height: Int, pixelFormat: MTLPixelFormat, count: Int) {
            self.width = width
            self.height = height
            self.pixelFormat = pixelFormat
            self.count = count
        }
    }

    private struct HeapKey: Hashable {
        let storageModeRawValue: UInt
        let cpuCacheModeRawValue: UInt
        let hazardTrackingModeRawValue: UInt

        init(descriptor: MTLTextureDescriptor) {
            storageModeRawValue = descriptor.storageMode.rawValue
            cpuCacheModeRawValue = descriptor.cpuCacheMode.rawValue
            hazardTrackingModeRawValue = descriptor.hazardTrackingMode.rawValue
        }
    }

    private struct SizeBucket: Hashable {
        let format: MTLPixelFormat
        let x: Int
        let y: Int
    }

    private final class CacheEntry: Hashable {
        let key: TextureDescriptorContract
        var textures: [MTLTexture] = []
        weak var previous: CacheEntry?
        var next: CacheEntry?

        init(key: TextureDescriptorContract) { self.key = key }
        static func == (lhs: CacheEntry, rhs: CacheEntry) -> Bool { lhs === rhs }
        func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
    }

    private let maxMemoryUsage: Int
    private let device: MTLDevice
    private let sizeTolerance = 8
    private let queue = DispatchQueue(label: "com.harbeth.texturepool.concurrent", attributes: .concurrent)
    private var cache: [TextureDescriptorContract: CacheEntry] = [:]
    private var oldestEntry: CacheEntry?
    private var newestEntry: CacheEntry?
    private var sizeBuckets: [SizeBucket: Set<CacheEntry>]?
    private var textureToKey: [ObjectIdentifier: TextureDescriptorContract] = [:]
    private var directCachedMemoryUsage = 0
    private var heaps: [HeapKey: [MTLHeap]] = [:]
    private var knownHeapIdentifiers: Set<ObjectIdentifier> = []
    private var statisticsStorage = TexturePoolStatistics()

    var byteLimit: Int { maxMemoryUsage }

    #if os(macOS)
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    #endif

    var statistics: TexturePoolStatistics {
        queue.sync { statisticsStorage }
    }

    init(device: MTLDevice? = nil, maxMemoryUsage: Int? = nil) {
        guard let resolvedDevice = device ?? MTLCreateSystemDefaultDevice() else {
            fatalError("Could not create Metal Device")
        }
        self.device = resolvedDevice
        let physicalMemoryMB = ProcessInfo.processInfo.physicalMemory / 1024 / 1024
        let memoryPercentage: Double
        if physicalMemoryMB < 2048 {
            memoryPercentage = 0.05
        } else if physicalMemoryMB < 4096 {
            memoryPercentage = 0.07
        } else {
            memoryPercentage = 0.10
        }
        let limitMB = min(Int(Double(physicalMemoryMB) * memoryPercentage), 512)
        self.maxMemoryUsage = max(maxMemoryUsage ?? Int(limitMB * 1024 * 1024), 1)

        #if os(iOS) || os(tvOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        #elseif os(macOS)
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.critical, .warning])
        source.setEventHandler { [weak self] in
            guard let self else { return }
            if source.mask.contains(.critical) {
                self.purgeAllTextures()
            } else if source.mask.contains(.warning) {
                self.purgeLeastUsedTextures()
            }
        }
        source.resume()
        memoryPressureSource = source
        #endif
    }

    deinit {
        for entry in cache.values { entry.previous = nil; entry.next = nil }
        #if os(iOS) || os(tvOS)
        NotificationCenter.default.removeObserver(self)
        #elseif os(macOS)
        memoryPressureSource?.cancel()
        #endif
    }

    /// 兼容旧接口：只按尺寸和像素格式查找。Harbeth 运行时内部使用完整 descriptor 接口。
    func dequeueTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat) -> MTLTexture? {
        dequeueLegacyTexture(width: width, height: height, pixelFormat: pixelFormat, allowsSizeTolerance: true)
    }

    /// 兼容旧接口：只按精确尺寸和像素格式查找。Harbeth 运行时内部使用完整 descriptor 接口。
    func dequeueExactTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat) -> MTLTexture? {
        dequeueLegacyTexture(width: width, height: height, pixelFormat: pixelFormat, allowsSizeTolerance: false)
    }

    func dequeueTexture(matching descriptor: MTLTextureDescriptor, allowsSizeTolerance: Bool) -> MTLTexture? {
        let requestedKey = TextureDescriptorContract(descriptor: descriptor)
        return queue.sync(flags: .barrier) {
            if let texture = popFromCacheLocked(for: requestedKey) {
                recordReuseLocked(texture)
                return texture
            }
            guard allowsSizeTolerance else {
                statisticsStorage.totalTexturesCreated += 1
                return nil
            }
            for entry in candidateEntriesLocked(width: descriptor.width, height: descriptor.height,
                                            pixelFormat: descriptor.pixelFormat, tolerance: sizeTolerance)
                where entry.key.isCompatible(with: requestedKey, sizeTolerance: sizeTolerance) {
                if let texture = popEntryLocked(entry) {
                    recordReuseLocked(texture)
                    return texture
                }
            }
            statisticsStorage.totalTexturesCreated += 1
            return nil
        }
    }

    func enqueueTexture(_ texture: MTLTexture) {
        queue.async(flags: .barrier) { self.enqueueTextureLocked(texture) }
    }

    func enqueueTextureSync(_ texture: MTLTexture) {
        queue.sync(flags: .barrier) { enqueueTextureLocked(texture) }
    }

    func enqueueTexturesSync(_ textures: [MTLTexture]) {
        guard !textures.isEmpty else { return }
        queue.sync(flags: .barrier) {
            for texture in textures {
                enqueueTextureLocked(texture)
            }
        }
    }

    func makeLease(for texture: MTLTexture, logicalExtent: C7Size? = nil) -> TextureLease {
        TextureLease(texture: texture, logicalExtent: logicalExtent) { [weak self] in
            self?.enqueueTextureSync(texture)
        }
    }

    func dequeueTextureLease(width: Int,
                                    height: Int,
                                    pixelFormat: MTLPixelFormat,
                                    allowsSizeTolerance: Bool = false,
                                    logicalExtent: C7Size? = nil) -> TextureLease? {
        let texture = dequeueLegacyTexture(
            width: width,
            height: height,
            pixelFormat: pixelFormat,
            allowsSizeTolerance: allowsSizeTolerance
        )
        guard let texture else { return nil }
        return makeLease(for: texture, logicalExtent: logicalExtent ?? C7Size(width: width, height: height))
    }

    func dequeueTextureLease(matching descriptor: MTLTextureDescriptor,
                             allowsSizeTolerance: Bool,
                             logicalExtent: C7Size? = nil) -> TextureLease? {
        guard let texture = dequeueTexture(matching: descriptor, allowsSizeTolerance: allowsSizeTolerance) else {
            return nil
        }
        return makeLease(
            for: texture,
            logicalExtent: logicalExtent ?? C7Size(width: descriptor.width, height: descriptor.height)
        )
    }

    /// 从真实 MTLHeap 分配纹理。返回 nil 时调用方应降级为 device.makeTexture。
    func makeHeapTexture(descriptor: MTLTextureDescriptor, device: MTLDevice) -> MTLTexture? {
        // Heap 的 default hazard mode 在部分设备上会解析为 untracked；显式 tracked
        // 才能让首次分配与后续 descriptor-safe 复用保持同一合同。
        if descriptor.hazardTrackingMode == .default {
            descriptor.hazardTrackingMode = .tracked
        }
        guard descriptor.storageMode != .memoryless else {
            recordHeapFallback(reason: "memorylessTextureIsNotHeapEligible")
            return nil
        }
        let sizeAndAlign = device.heapTextureSizeAndAlign(descriptor: descriptor)
        guard sizeAndAlign.size > 0 else {
            recordHeapFallback(reason: "invalidHeapTextureSize")
            return nil
        }
        let key = HeapKey(descriptor: descriptor)
        return queue.sync(flags: .barrier) {
            if let existingHeaps = heaps[key] {
                for heap in existingHeaps where heap.maxAvailableSize(alignment: sizeAndAlign.align) >= sizeAndAlign.size {
                    if let texture = heap.makeTexture(descriptor: descriptor) {
                        statisticsStorage.heapTextureAllocationCount += 1
                        updateStatisticsLocked()
                        return texture
                    }
                }
            }

            removeEmptyHeapsLocked()
            let chunkSize = resolvedHeapChunkSize(required: sizeAndAlign.size, alignment: sizeAndAlign.align)
            guard chunkSize > 0, reserveBudgetLocked(additionalBytes: chunkSize) else {
                statisticsStorage.heapAllocationFallbackCount += 1
                updateStatisticsLocked()
                return nil
            }

            let heapDescriptor = MTLHeapDescriptor()
            heapDescriptor.size = chunkSize
            heapDescriptor.storageMode = descriptor.storageMode
            heapDescriptor.cpuCacheMode = descriptor.cpuCacheMode
            heapDescriptor.hazardTrackingMode = descriptor.hazardTrackingMode
            guard let heap = device.makeHeap(descriptor: heapDescriptor) else {
                statisticsStorage.heapAllocationFallbackCount += 1
                updateStatisticsLocked()
                return nil
            }
            heap.label = "Harbeth.TextureHeap.\(heaps.values.reduce(0) { $0 + $1.count } + 1)"
            heaps[key, default: []].append(heap)
            knownHeapIdentifiers.insert(ObjectIdentifier(heap))
            guard let texture = heap.makeTexture(descriptor: descriptor) else {
                heaps[key]?.removeAll { $0 === heap }
                knownHeapIdentifiers.remove(ObjectIdentifier(heap))
                statisticsStorage.heapAllocationFallbackCount += 1
                updateStatisticsLocked()
                return nil
            }
            statisticsStorage.heapTextureAllocationCount += 1
            updateStatisticsLocked()
            return texture
        }
    }

    func recordHeapFallback(reason: String) {
        queue.async(flags: .barrier) {
            self.statisticsStorage.heapAllocationFallbackCount += 1
            self.updateStatisticsLocked()
            HarbethLogger.log(
                .debug,
                category: "texturePool",
                code: "harbeth.texture_heap.fallback",
                outcome: .fallback,
                message: reason
            )
        }
    }

    func prewarm(resolutions: [(width: Int, height: Int, pixelFormat: MTLPixelFormat)], count: Int = 2) {
        prewarm(requests: resolutions.map {
            PrewarmRequest(width: $0.width, height: $0.height, pixelFormat: $0.pixelFormat, count: count)
        })
    }

    func prewarm(requests: [PrewarmRequest]) {
        prewarm(requests: requests, synchronously: false)
    }

    func prewarmSync(requests: [PrewarmRequest]) {
        prewarm(requests: requests, synchronously: true)
    }

    func resetStatistics() {
        queue.async(flags: .barrier) { self.resetStatisticsLocked() }
    }

    func resetStatisticsSync() {
        queue.sync(flags: .barrier) { resetStatisticsLocked() }
    }

    func dumpStatistics() {
        queue.sync {
            let stats = statisticsStorage
            HarbethLogger.log(
                .info,
                category: "texturePool",
                code: "harbeth.texture_pool.statistics",
                outcome: .observed,
                message: """
                    created=\(stats.totalTexturesCreated) reused=\(stats.totalTexturesReused) hitRate=\(String(format: "%.2f%%", stats.hitRate * 100))
                    current=\(stats.currentMemoryUsage / 1024 / 1024)MB peak=\(stats.peakMemoryUsage / 1024 / 1024)MB average=\(String(format: "%.2f", stats.averageMemoryUsage / 1024 / 1024))MB
                    textures=\(stats.currentTextureCount) heaps=\(stats.heapCount) heapReserved=\(stats.heapReservedMemory / 1024 / 1024)MB heapUsed=\(stats.heapUsedMemory / 1024 / 1024)MB budget=\(maxMemoryUsage / 1024 / 1024)MB
                    """
            )
        }
    }

    func purgeAllTexturesSync() {
        queue.sync(flags: .barrier) { purgeAllTexturesLocked() }
    }

    private func dequeueLegacyTexture(width: Int,
                                      height: Int,
                                      pixelFormat: MTLPixelFormat,
                                      allowsSizeTolerance: Bool) -> MTLTexture? {
        queue.sync(flags: .barrier) {
            let tolerance = allowsSizeTolerance ? sizeTolerance : 0
            let candidates = candidateEntriesLocked(width: width, height: height, pixelFormat: pixelFormat, tolerance: tolerance)
                .filter { abs($0.key.width - width) <= tolerance && abs($0.key.height - height) <= tolerance }
            for entry in candidates {
                if let texture = popEntryLocked(entry) {
                    recordReuseLocked(texture)
                    return texture
                }
            }
            statisticsStorage.totalTexturesCreated += 1
            return nil
        }
    }

    private func prewarm(requests: [PrewarmRequest], synchronously: Bool) {
        let filteredRequests = requests.filter { $0.count > 0 }
        guard !filteredRequests.isEmpty else { return }
        let work: @Sendable () -> Void = {
            for request in filteredRequests {
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: request.pixelFormat,
                    width: request.width,
                    height: request.height,
                    mipmapped: false
                )
                descriptor.usage = [.shaderRead, .shaderWrite]
                descriptor.storageMode = .shared
                let key = TextureDescriptorContract(descriptor: descriptor)
                let neededCount = max(request.count - (self.cache[key]?.textures.count ?? 0), 0)
                for _ in 0..<neededCount {
                    guard let texture = self.device.makeTexture(descriptor: descriptor) else { continue }
                    self.enqueueTextureLocked(texture)
                }
            }
        }
        if synchronously {
            queue.sync(flags: .barrier, execute: work)
        } else {
            queue.async(flags: .barrier, execute: work)
        }
    }

    private func enqueueTextureLocked(_ texture: MTLTexture) {
        let oid = ObjectIdentifier(texture)
        guard textureToKey[oid] == nil else { return }
        if let heap = texture.heap, !knownHeapIdentifiers.contains(ObjectIdentifier(heap)) {
            return
        }

        let key = TextureDescriptorContract(texture: texture)
        let additionalBytes = texture.heap == nil ? allocatedByteSize(of: texture) : 0
        guard reserveBudgetLocked(additionalBytes: additionalBytes) else { return }
        // 预算回收可能移除同一个键，因此在回收后判断是否需要追加访问记录。
        let entry: CacheEntry
        if let existing = cache[key] {
            entry = existing
        } else {
            entry = CacheEntry(key: key)
            cache[key] = entry
            appendAccessLocked(entry)
            sizeBuckets?[bucket(for: key), default: []].insert(entry)
        }
        entry.textures.append(texture)
        textureToKey[oid] = key
        directCachedMemoryUsage += additionalBytes
        statisticsStorage.currentTextureCount += 1
        updateStatisticsLocked()
    }

    private func popFromCacheLocked(for key: TextureDescriptorContract) -> MTLTexture? {
        guard let entry = cache[key] else { return nil }
        return popEntryLocked(entry)
    }

    private func popEntryLocked(_ entry: CacheEntry) -> MTLTexture? {
        guard let texture = entry.textures.popLast() else {
            removeEntryLocked(entry)
            return nil
        }
        if entry.textures.isEmpty {
            removeEntryLocked(entry)
        } else if newestEntry !== entry {
            removeAccessLocked(entry)
            appendAccessLocked(entry)
        }
        textureToKey.removeValue(forKey: ObjectIdentifier(texture))
        if texture.heap == nil {
            directCachedMemoryUsage = max(directCachedMemoryUsage - allocatedByteSize(of: texture), 0)
        }
        statisticsStorage.currentTextureCount = max(statisticsStorage.currentTextureCount - 1, 0)
        updateStatisticsLocked()
        return texture
    }

    // 尺寸桶只缩小候选集合；descriptor 路径仍逐一校验完整合同。
    private func bucket(for key: TextureDescriptorContract) -> SizeBucket {
        SizeBucket(format: key.pixelFormat, x: key.width / (sizeTolerance + 1), y: key.height / (sizeTolerance + 1))
    }

    private func candidateEntriesLocked(width: Int, height: Int, pixelFormat: MTLPixelFormat, tolerance: Int) -> [CacheEntry] {
        guard width > 0, height > 0 else { return [] }
        let side = sizeTolerance + 1
        let maxX = (width > Int.max - tolerance ? Int.max : width + tolerance) / side
        let maxY = (height > Int.max - tolerance ? Int.max : height + tolerance) / side
        // 精确合同命中无需尺寸索引；首次尺寸查询才构建，避免常规帧额外记账。
        if sizeBuckets == nil {
            var index: [SizeBucket: Set<CacheEntry>] = [:]
            for entry in cache.values { index[bucket(for: entry.key), default: []].insert(entry) }
            sizeBuckets = index
        }
        var entries: [CacheEntry] = []
        for x in max(width - tolerance, 0) / side...maxX {
            for y in max(height - tolerance, 0) / side...maxY {
                if let candidates = sizeBuckets?[SizeBucket(format: pixelFormat, x: x, y: y)] {
                    entries.append(contentsOf: candidates)
                }
            }
        }
        return entries
    }

    private func appendAccessLocked(_ entry: CacheEntry) {
        entry.previous = newestEntry
        newestEntry?.next = entry
        if oldestEntry == nil { oldestEntry = entry }
        newestEntry = entry
    }

    private func removeAccessLocked(_ entry: CacheEntry) {
        if let previous = entry.previous { previous.next = entry.next } else { oldestEntry = entry.next }
        if let next = entry.next { next.previous = entry.previous } else { newestEntry = entry.previous }
        entry.previous = nil
        entry.next = nil
    }

    private func removeEntryLocked(_ entry: CacheEntry) {
        cache[entry.key] = nil
        removeAccessLocked(entry)
        if sizeBuckets != nil {
            let index = bucket(for: entry.key)
            sizeBuckets?[index]?.remove(entry)
            if sizeBuckets?[index]?.isEmpty == true { sizeBuckets?[index] = nil }
            if cache.isEmpty { sizeBuckets = nil }
        }
    }

    private func recordReuseLocked(_ texture: MTLTexture) {
        statisticsStorage.totalTexturesReused += 1
        statisticsStorage.totalMemorySaved += allocatedByteSize(of: texture)
    }

    private func reserveBudgetLocked(additionalBytes: Int) -> Bool {
        guard additionalBytes <= maxMemoryUsage else { return false }
        while totalReservedMemoryLocked + additionalBytes > maxMemoryUsage {
            guard evictOldestTextureLocked() else { break }
            removeEmptyHeapsLocked()
        }
        return totalReservedMemoryLocked + additionalBytes <= maxMemoryUsage
    }

    private func evictOldestTextureLocked() -> Bool {
        guard let entry = oldestEntry, let texture = entry.textures.popLast() else { return false }
        textureToKey.removeValue(forKey: ObjectIdentifier(texture))
        if texture.heap == nil {
            directCachedMemoryUsage = max(directCachedMemoryUsage - allocatedByteSize(of: texture), 0)
        }
        statisticsStorage.currentTextureCount = max(statisticsStorage.currentTextureCount - 1, 0)
        if entry.textures.isEmpty {
            removeEntryLocked(entry)
        } else {
            removeAccessLocked(entry)
            appendAccessLocked(entry)
        }
        return true
    }

    private func resolvedHeapChunkSize(required: Int, alignment: Int) -> Int {
        let preferred = min(max(maxMemoryUsage / 4, 8 * 1024 * 1024), 64 * 1024 * 1024)
        let rawSize = max(required, preferred)
        let safeAlignment = max(alignment, 1)
        let remainder = rawSize % safeAlignment
        let alignedSize = remainder == 0 ? rawSize : rawSize + safeAlignment - remainder
        return alignedSize <= maxMemoryUsage ? alignedSize : 0
    }

    private var totalReservedMemoryLocked: Int {
        directCachedMemoryUsage + heaps.values.reduce(0) { total, group in
            group.reduce(total) { $0 + $1.size }
        }
    }

    private func removeEmptyHeapsLocked() {
        for key in Array(heaps.keys) {
            let retained = (heaps[key] ?? []).filter { heap in
                if heap.currentAllocatedSize == 0 {
                    knownHeapIdentifiers.remove(ObjectIdentifier(heap))
                    return false
                }
                return true
            }
            heaps[key] = retained.isEmpty ? nil : retained
        }
    }

    private func purgeLeastUsedTextures() {
        queue.async(flags: .barrier) {
            let releaseCount = min(max(self.cache.count / 2, 1), self.cache.count)
            for _ in 0..<releaseCount {
                _ = self.evictOldestTextureLocked()
            }
            self.removeEmptyHeapsLocked()
            self.updateStatisticsLocked()
        }
    }

    private func purgeAllTextures() {
        queue.async(flags: .barrier) { self.purgeAllTexturesLocked() }
    }

    private func purgeAllTexturesLocked() {
        // 清空时主动断链，避免大量键集中释放时递归销毁整条链。
        for entry in cache.values { entry.previous = nil; entry.next = nil }
        cache.removeAll()
        oldestEntry = nil
        newestEntry = nil
        sizeBuckets = nil
        textureToKey.removeAll()
        directCachedMemoryUsage = 0
        removeEmptyHeapsLocked()
        statisticsStorage.currentTextureCount = 0
        updateStatisticsLocked()
    }

    private func resetStatisticsLocked() {
        statisticsStorage = TexturePoolStatistics()
        statisticsStorage.currentTextureCount = cache.values.reduce(0) { $0 + $1.textures.count }
        updateStatisticsLocked()
    }

    private func updateStatisticsLocked() {
        var heapCount = 0
        var heapReservedMemory = 0
        var heapUsedMemory = 0
        for group in heaps.values {
            heapCount += group.count
            for heap in group {
                heapReservedMemory += heap.size
                heapUsedMemory += heap.currentAllocatedSize
            }
        }
        let currentMemoryUsage = directCachedMemoryUsage + heapReservedMemory
        statisticsStorage.currentMemoryUsage = currentMemoryUsage
        statisticsStorage.maxMemoryUsage = maxMemoryUsage
        statisticsStorage.peakMemoryUsage = max(statisticsStorage.peakMemoryUsage, currentMemoryUsage)
        statisticsStorage.heapCount = heapCount
        statisticsStorage.heapReservedMemory = heapReservedMemory
        statisticsStorage.heapUsedMemory = heapUsedMemory
        statisticsStorage.memoryUsageSamples.append(currentMemoryUsage)
        if statisticsStorage.memoryUsageSamples.count > 100 {
            statisticsStorage.memoryUsageSamples.removeFirst()
        }
        let total = statisticsStorage.memoryUsageSamples.reduce(0, +)
        statisticsStorage.averageMemoryUsage = statisticsStorage.memoryUsageSamples.isEmpty
            ? 0
            : Double(total) / Double(statisticsStorage.memoryUsageSamples.count)
    }

    private func allocatedByteSize(of texture: MTLTexture) -> Int {
        let bytesPerPixel: Int
        switch texture.pixelFormat {
        case .r8Unorm, .r8Snorm, .r8Uint, .r8Sint:
            bytesPerPixel = 1
        case .rg8Unorm, .rg8Snorm, .rg8Uint, .rg8Sint, .r16Unorm, .r16Snorm, .r16Uint, .r16Sint, .r16Float:
            bytesPerPixel = 2
        case .rgba8Unorm, .rgba8Unorm_srgb, .rgba8Snorm, .rgba8Uint, .rgba8Sint,
             .bgra8Unorm, .bgra8Unorm_srgb, .rg16Unorm, .rg16Snorm, .rg16Uint,
             .rg16Sint, .rg16Float, .r32Uint, .r32Sint, .r32Float:
            bytesPerPixel = 4
        case .rgba16Unorm, .rgba16Snorm, .rgba16Uint, .rgba16Sint, .rgba16Float,
             .rg32Uint, .rg32Sint, .rg32Float:
            bytesPerPixel = 8
        case .rgba32Uint, .rgba32Sint, .rgba32Float:
            bytesPerPixel = 16
        default:
            bytesPerPixel = 4
        }
        var texelCount = 0
        for level in 0..<texture.mipmapLevelCount {
            let width = max(texture.width >> level, 1)
            let height = max(texture.height >> level, 1)
            let depth = max(texture.depth >> level, 1)
            texelCount += width * height * depth
        }
        return max(texelCount * max(texture.arrayLength, 1) * max(texture.sampleCount, 1) * bytesPerPixel, 1)
    }

    @objc private func didReceiveMemoryWarning() {
        purgeAllTextures()
    }
}
