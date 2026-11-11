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
    case coordinateField
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
    private var textureCreations: [DerivedResourceIdentity: DerivedTextureCreation] = [:]
    private var nextGeneration: UInt64 = 1
    private var hitCount = 0
    private var missCount = 0
    private var evictionCount = 0
    private var rejectedInsertionCount = 0

    init(configuration: DerivedResourceCacheConfiguration) {
        self.configuration = configuration
    }

    func texture(for identity: DerivedResourceIdentity, create: () throws -> MTLTexture) throws -> MTLTexture {
        let key = identity.cacheKey
        lock.lock()
        let scope = Scope(domain: identity.domain, namespace: identity.namespace)
        if generation(for: scope) == identity.generation, let texture = entries[key]?.value as? MTLTexture {
            hitCount += 1
            if lru.last != key {
                lru.removeAll { $0 == key }
                lru.append(key)
            }
            lock.unlock()
            return texture
        }
        missCount += 1
        if let pending = textureCreations[identity] {
            lock.unlock()
            return try pending.wait()
        }
        let pending = DerivedTextureCreation()
        textureCreations[identity] = pending
        lock.unlock()
        let result = Result { try create() }
        if case .success(let texture) = result {
            insert(texture as AnyObject, byteCost: max(texture.allocatedSize, 1), for: identity)
        }
        pending.complete(result)
        lock.lock()
        textureCreations.removeValue(forKey: identity)
        lock.unlock()
        return try result.get()
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
        let key = identity.cacheKey
        lock.lock()
        let scope = Scope(domain: identity.domain, namespace: identity.namespace)
        guard generation(for: scope) == identity.generation, let entry = entries[key] else {
            missCount += 1
            lock.unlock()
            return nil
        }
        if lru.last != key {
            lru.removeAll { $0 == key }
            lru.append(key)
        }
        hitCount += 1
        lock.unlock()
        return entry.value
    }

    @discardableResult
    func insert(_ value: AnyObject, byteCost: Int, for identity: DerivedResourceIdentity) -> Bool {
        let key = identity.cacheKey
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
        if entries[key] != nil {
            removeEntry(for: key)
        }
        entries[key] = Entry(identity: identity, value: value, byteCost: byteCost)
        lru.append(key)
        byteCount += byteCost
        evictIfNeeded()
        let retained = entries[key] != nil
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
        if keys.isEmpty == false {
            // 一次移除匹配的访问记录，保留其他条目的 LRU 相对顺序。
            let removedKeys = Set(keys)
            lru.removeAll { removedKeys.contains($0) }
            for key in keys {
                guard let entry = entries.removeValue(forKey: key) else { continue }
                byteCount = max(byteCount - entry.byteCost, 0)
            }
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
        var removedCount = 0
        for key in lru {
            guard entries.count > configuration.countLimit || byteCount > configuration.byteLimit else { break }
            if let entry = entries.removeValue(forKey: key) {
                byteCount = max(byteCount - entry.byteCost, 0)
                evictionCount += 1
            }
            removedCount += 1
        }
        // 淘汰仍按旧到新进行，最后一次性删除已淘汰的 LRU 前缀。
        if removedCount > 0 {
            lru.removeFirst(removedCount)
        }
    }

    private func removeEntry(for key: String) {
        lru.removeAll { $0 == key }
        guard let entry = entries.removeValue(forKey: key) else { return }
        byteCount = max(byteCount - entry.byteCost, 0)
    }
}

private final class DerivedTextureCreation: @unchecked Sendable {
    private let condition = NSCondition()
    private let owner = Thread.current
    private var result: Result<MTLTexture, Error>?

    func complete(_ result: Result<MTLTexture, Error>) {
        condition.lock()
        self.result = result
        condition.broadcast()
        condition.unlock()
    }

    func wait() throws -> MTLTexture {
        guard Thread.current !== owner else {
            throw HarbethError.configurationInvalid("A derived texture cannot recursively await its own creation.")
        }
        condition.lock()
        while result == nil { condition.wait() }
        let result = result!
        condition.unlock()
        return try result.get()
    }
}

extension HarbethContext {
    /// Coalesces concurrent creation and rejects stale cache insertion after invalidation.
    public func makeDerivedTexture(for identity: DerivedResourceIdentity, create: () throws -> MTLTexture) throws -> MTLTexture {
        try derivedResourceStore.texture(for: identity) {
            let texture = try create()
            guard texture.device === device else {
                throw HarbethError.configurationInvalid("Derived textures must belong to the active context device.")
            }
            return texture
        }
    }

    public func configureDerivedResourceCache(_ configuration: DerivedResourceCacheConfiguration) {
        derivedResourceStore.configure(configuration)
    }

    public func makeDerivedResourceIdentity(domain: DerivedResourceDomain, namespace: String? = nil, fingerprint: String) -> DerivedResourceIdentity {
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
