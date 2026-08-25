//
//  RealtimePixelBufferPoolRegistry.swift
//  Harbeth
//
//  Created by Condy on 2026/8/25.
//

import CoreVideo
import Foundation

final class RealtimePixelBufferPoolRegistry: @unchecked Sendable {
    struct Acquisition {
        let buffer: CVPixelBuffer
        let poolUsed: Bool
        let fallbackReason: RealtimePixelBufferPoolFallbackReason?
    }

    private let queue: DispatchQueue
    private let maxEntryCount: Int
    private var store: [String: CVPixelBufferPool] = [:]
    private var lru: [String: UInt64] = [:]
    private var accessSequence: UInt64 = 0
    private var hitCount = 0
    private var missCount = 0
    private var allocationFallbackCount = 0

    init(label: String = "harbeth.realtime.pixelbufferpool", maxEntryCount: Int = 4) {
        self.queue = DispatchQueue(label: label)
        self.maxEntryCount = max(maxEntryCount, 1)
    }

    func acquire(key: String,
                 makePool: () throws -> CVPixelBufferPool,
                 makeBuffer: (CVPixelBufferPool) throws -> CVPixelBuffer) throws -> Acquisition {
        try queue.sync {
            if let pool = store[key] {
                hitCount += 1
                lru[key] = nextAccessSequence()
                do {
                    return Acquisition(buffer: try makeBuffer(pool), poolUsed: true, fallbackReason: nil)
                } catch {
                    allocationFallbackCount += 1
                    return Acquisition(buffer: try makeBuffer(pool), poolUsed: false, fallbackReason: .allocatorBusy)
                }
            }

            missCount += 1
            let pool = try makePool()
            let buffer = try makeBuffer(pool)
            var reason: RealtimePixelBufferPoolFallbackReason?
            if store.count >= maxEntryCount,
               let evicted = lru.min(by: { $0.value < $1.value }) {
                reason = .lruEvicted
                store.removeValue(forKey: evicted.key)
                lru.removeValue(forKey: evicted.key)
            }
            store[key] = pool
            lru[key] = nextAccessSequence()
            return Acquisition(buffer: buffer, poolUsed: true, fallbackReason: reason)
        }
    }

    func recordAllocationFallback() {
        queue.sync { allocationFallbackCount += 1 }
    }

    func metrics() -> (hitCount: Int, missCount: Int, allocationFallbackCount: Int) {
        queue.sync { (hitCount, missCount, allocationFallbackCount) }
    }

    func resetMetrics() {
        queue.sync {
            hitCount = 0
            missCount = 0
            allocationFallbackCount = 0
        }
    }

    /// Removes registry references only. Existing CVPixelBuffer values remain valid for their owners.
    func purge() {
        queue.sync {
            store.removeAll(keepingCapacity: false)
            lru.removeAll(keepingCapacity: false)
        }
    }

    private func nextAccessSequence() -> UInt64 {
        accessSequence &+= 1
        if accessSequence == 0 {
            accessSequence = 1
            store.removeAll(keepingCapacity: false)
            lru.removeAll(keepingCapacity: false)
        }
        return accessSequence
    }
}
