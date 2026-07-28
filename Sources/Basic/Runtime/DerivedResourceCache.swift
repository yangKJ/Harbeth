//
//  DerivedResourceCache.swift
//  Harbeth
//
//  Created by Condy on 2026/7/28.
//

import Foundation
@preconcurrency import Metal

/// Harbeth 内可重建 GPU 派生资源的稳定分类。
public enum DerivedResourceDomain: String, CaseIterable, Sendable, Codable, Equatable, Hashable {
    case outputContract
    case mask
    case lookupTable
}

/// 进程内派生资源缓存身份。generation 由 HarbethContext 签发，用于阻止失效前启动的任务回写陈旧结果。
public struct DerivedResourceIdentity: Sendable, Equatable, Hashable {
    public let domain: DerivedResourceDomain
    public let namespace: String
    public let fingerprint: String
    public let generation: UInt64

    fileprivate var cacheKey: String {
        "\(domain.rawValue)||\(namespace)||\(generation)||\(fingerprint)"
    }
}

public struct DerivedResourceCacheConfiguration: Sendable, Codable, Equatable, Hashable {
    public let byteLimit: Int
    public let countLimit: Int

    public init(byteLimit: Int, countLimit: Int = 192) {
        self.byteLimit = max(byteLimit, 1)
        self.countLimit = max(countLimit, 1)
    }
}

public struct DerivedResourceCacheSnapshot: Sendable, Codable, Equatable {
    public let namespace: String
    public let entryCount: Int
    public let byteCount: Int
    public let byteLimit: Int
    public let countLimit: Int
    public let hitCount: Int
    public let missCount: Int
    public let evictionCount: Int
    public let rejectedInsertionCount: Int
    public let entriesByDomain: [String: Int]

    public var hitRate: Double {
        let total = hitCount + missCount
        return total == 0 ? 0 : Double(hitCount) / Double(total)
    }
}

final class DerivedResourceStore: @unchecked Sendable {
    private struct Scope: Hashable {
        let domain: DerivedResourceDomain
        let namespace: String
    }

    private struct Entry {
        let identity: DerivedResourceIdentity
        let value: AnyObject
        let byteCost: Int
    }

    private let lock = NSLock()
    private var configuration: DerivedResourceCacheConfiguration
    private var namespace = "default"
    private var entries: [String: Entry] = [:]
    private var lru: [String] = []
    private var byteCount = 0
    private var scopeGenerations: [Scope: UInt64] = [:]
    private var nextGeneration: UInt64 = 1
    private var hitCount = 0
    private var missCount = 0
    private var evictionCount = 0
    private var rejectedInsertionCount = 0

    init(configuration: DerivedResourceCacheConfiguration) {
        self.configuration = configuration
    }

    func configure(_ configuration: DerivedResourceCacheConfiguration) {
        lock.lock()
        self.configuration = configuration
        evictIfNeeded()
        lock.unlock()
    }

    func makeIdentity(domain: DerivedResourceDomain, namespace explicitNamespace: String? = nil, fingerprint: String) -> DerivedResourceIdentity {
        lock.lock()
        let namespace = explicitNamespace ?? namespace
        let scope = Scope(domain: domain, namespace: namespace)
        let generation = generation(for: scope)
        lock.unlock()
        return DerivedResourceIdentity(
            domain: domain,
            namespace: namespace,
            fingerprint: fingerprint,
            generation: generation
        )
    }

    func value(for identity: DerivedResourceIdentity) -> AnyObject? {
        lock.lock()
        let scope = Scope(domain: identity.domain, namespace: identity.namespace)
        guard generation(for: scope) == identity.generation,
              let entry = entries[identity.cacheKey] else {
            missCount += 1
            lock.unlock()
            return nil
        }
        lru.removeAll { $0 == identity.cacheKey }
        lru.append(identity.cacheKey)
        hitCount += 1
        lock.unlock()
        return entry.value
    }

    @discardableResult
    func insert(_ value: AnyObject, byteCost: Int, for identity: DerivedResourceIdentity) -> Bool {
        lock.lock()
        let scope = Scope(domain: identity.domain, namespace: identity.namespace)
        guard generation(for: scope) == identity.generation else {
            rejectedInsertionCount += 1
            lock.unlock()
            return false
        }
        let byteCost = max(byteCost, 1)
        guard byteCost <= configuration.byteLimit else {
            rejectedInsertionCount += 1
            lock.unlock()
            return false
        }
        removeEntry(for: identity.cacheKey, eviction: false)
        entries[identity.cacheKey] = Entry(identity: identity, value: value, byteCost: byteCost)
        lru.append(identity.cacheKey)
        byteCount += byteCost
        evictIfNeeded()
        let retained = entries[identity.cacheKey] != nil
        lock.unlock()
        return retained
    }

    func invalidate(domain: DerivedResourceDomain? = nil, namespace: String? = nil) {
        lock.lock()
        let matchingScopes = scopeGenerations.keys.filter { scope in
            (domain == nil || scope.domain == domain) && (namespace == nil || scope.namespace == namespace)
        }
        for scope in matchingScopes {
            scopeGenerations[scope] = takeGeneration()
        }
        let keys = entries.compactMap { key, entry in
            let matchesDomain = domain == nil || entry.identity.domain == domain
            let matchesNamespace = namespace == nil || entry.identity.namespace == namespace
            return matchesDomain && matchesNamespace ? key : nil
        }
        for key in keys {
            removeEntry(for: key, eviction: false)
        }
        lock.unlock()
    }

    func setNamespace(_ namespace: String) {
        lock.lock()
        self.namespace = namespace.isEmpty ? "default" : namespace
        lock.unlock()
    }

    func currentNamespace() -> String {
        lock.lock()
        let namespace = namespace
        lock.unlock()
        return namespace
    }

    func snapshot() -> DerivedResourceCacheSnapshot {
        lock.lock()
        var entriesByDomain: [String: Int] = [:]
        for entry in entries.values {
            entriesByDomain[entry.identity.domain.rawValue, default: 0] += 1
        }
        let snapshot = DerivedResourceCacheSnapshot(
            namespace: namespace,
            entryCount: entries.count,
            byteCount: byteCount,
            byteLimit: configuration.byteLimit,
            countLimit: configuration.countLimit,
            hitCount: hitCount,
            missCount: missCount,
            evictionCount: evictionCount,
            rejectedInsertionCount: rejectedInsertionCount,
            entriesByDomain: entriesByDomain
        )
        lock.unlock()
        return snapshot
    }

    private func generation(for scope: Scope) -> UInt64 {
        if let generation = scopeGenerations[scope] {
            return generation
        }
        let generation = takeGeneration()
        scopeGenerations[scope] = generation
        return generation
    }

    private func takeGeneration() -> UInt64 {
        let generation = nextGeneration
        nextGeneration &+= 1
        if nextGeneration == 0 { nextGeneration = 1 }
        return generation
    }

    private func evictIfNeeded() {
        while (entries.count > configuration.countLimit || byteCount > configuration.byteLimit),
              let oldest = lru.first {
            removeEntry(for: oldest, eviction: true)
        }
    }

    private func removeEntry(for key: String, eviction: Bool) {
        lru.removeAll { $0 == key }
        guard let entry = entries.removeValue(forKey: key) else { return }
        byteCount = max(byteCount - entry.byteCost, 0)
        if eviction { evictionCount += 1 }
    }
}

extension HarbethContext {
    public func configureDerivedResourceCache(_ configuration: DerivedResourceCacheConfiguration) {
        derivedResourceStore.configure(configuration)
    }

    public func makeDerivedResourceIdentity(
        domain: DerivedResourceDomain,
        namespace: String? = nil,
        fingerprint: String
    ) -> DerivedResourceIdentity {
        derivedResourceStore.makeIdentity(domain: domain, namespace: namespace, fingerprint: fingerprint)
    }

    public func cachedDerivedTexture(for identity: DerivedResourceIdentity) -> MTLTexture? {
        derivedResourceStore.value(for: identity) as? MTLTexture
    }

    @discardableResult
    public func storeDerivedTexture(_ texture: MTLTexture, for identity: DerivedResourceIdentity) -> Bool {
        derivedResourceStore.insert(texture as AnyObject, byteCost: max(texture.allocatedSize, 1), for: identity)
    }

    public func invalidateDerivedResources(domain: DerivedResourceDomain? = nil, namespace: String? = nil) {
        derivedResourceStore.invalidate(domain: domain, namespace: namespace)
    }

    public func setDerivedResourceNamespace(_ namespace: String) {
        derivedResourceStore.setNamespace(namespace)
    }

    public var currentDerivedResourceNamespace: String {
        derivedResourceStore.currentNamespace()
    }

    public func bumpDerivedResourceNamespace() {
        derivedResourceStore.setNamespace(UUID().uuidString)
    }

    public var derivedResourceCacheSnapshot: DerivedResourceCacheSnapshot {
        derivedResourceStore.snapshot()
    }

    func cachedDerivedObject(for identity: DerivedResourceIdentity) -> AnyObject? {
        derivedResourceStore.value(for: identity)
    }

    @discardableResult
    func storeDerivedObject(_ object: AnyObject, byteCost: Int, for identity: DerivedResourceIdentity) -> Bool {
        derivedResourceStore.insert(object, byteCost: byteCost, for: identity)
    }
}
