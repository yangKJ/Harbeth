//
//  ContextTransientResourceStore.swift
//  Harbeth
//
//  Created by Condy on 2026/8/25.
//

import Foundation

protocol ContextTransientResource: AnyObject {
    func purge()
}

/// Holds lazily-created, feature-specific runtime resources without exposing a service locator.
final class ContextTransientResourceStore: @unchecked Sendable {
    private let lock = NSLock()
    private var resources: [ObjectIdentifier: AnyObject] = [:]

    func resource<T: ContextTransientResource>(_ type: T.Type, make: () -> T) -> T {
        lock.lock()
        let key = ObjectIdentifier(type)
        if let existing = resources[key] as? T {
            lock.unlock()
            return existing
        }
        lock.unlock()

        let created = make()
        lock.lock()
        if let existing = resources[key] as? T {
            lock.unlock()
            return existing
        }
        resources[key] = created
        lock.unlock()
        return created
    }

    func purgeAll() {
        lock.lock()
        let resources = self.resources.values.compactMap { $0 as? ContextTransientResource }
        lock.unlock()
        resources.forEach { $0.purge() }
    }
}
