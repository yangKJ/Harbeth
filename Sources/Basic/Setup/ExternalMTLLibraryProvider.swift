//
//  ExternalMTLLibraryProvider.swift
//  Harbeth
//
//  Created by Condy on 2026/2/12.
//

import Foundation
import Metal

/// External MTLLibrary Provider Agreement
public protocol ExternalMTLLibraryProvider {
    var providerIdentifier: String { get }
    func provideLibrary(for device: MTLDevice) -> MTLLibrary?
}

public extension ExternalMTLLibraryProvider {
    var providerIdentifier: String {
        String(describing: type(of: self))
    }
}

public struct ExternalLibraryProviderSnapshot: Sendable, Equatable {
    public let identifier: String
    public let libraryCount: Int

    public init(identifier: String, libraryCount: Int) {
        self.identifier = identifier
        self.libraryCount = libraryCount
    }
}

final class ExternalLibraryProviderRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var providers: [ExternalMTLLibraryProvider] = []

    func register(_ provider: ExternalMTLLibraryProvider) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let identifier = provider.providerIdentifier
        guard providers.contains(where: { $0.providerIdentifier == identifier }) == false else {
            return false
        }
        providers.append(provider)
        return true
    }

    func snapshot() -> [ExternalMTLLibraryProvider] {
        lock.lock()
        defer { lock.unlock() }
        return providers
    }
}

extension Device {
    @discardableResult
    func registerExternalLibraryProvider(_ provider: ExternalMTLLibraryProvider) -> Bool {
        externalLibraryRegistry.register(provider)
    }

    func externalLibraryProviderIdentifiers() -> [String] {
        externalLibraryRegistry.snapshot().map(\.providerIdentifier)
    }

    func externalLibraryRegistryDebugDescription() -> String {
        let snapshots = externalLibraryRegistrySnapshot()
        if snapshots.isEmpty {
            return "External Library Registry: empty"
        }
        let lines = snapshots.map { "- \($0.identifier): \($0.libraryCount) libraries" }
        return (["External Library Registry:"] + lines).joined(separator: "\n")
    }

    func externalLibraryRegistrySnapshot() -> [ExternalLibraryProviderSnapshot] {
        let providers = externalLibraryRegistry.snapshot()
        return providers.map {
            let libraries = $0.provideLibrary(for: device).map { _ in 1 } ?? 0
            return ExternalLibraryProviderSnapshot(identifier: $0.providerIdentifier, libraryCount: libraries)
        }
    }

    @discardableResult
    static func registerExternalLibraryProvider(_ provider: ExternalMTLLibraryProvider) -> Bool {
        HarbethContext.shared.runtimeDevice.registerExternalLibraryProvider(provider)
    }

    static func externalLibraryProviderIdentifiers() -> [String] {
        HarbethContext.shared.runtimeDevice.externalLibraryProviderIdentifiers()
    }

    static func externalLibraryRegistryDebugDescription(on device: MTLDevice? = nil) -> String {
        let runtimeDevice = HarbethContext.shared.runtimeDevice
        let snapshots = externalLibraryRegistrySnapshot(on: device ?? runtimeDevice.device)
        if snapshots.isEmpty {
            return "External Library Registry: empty"
        }
        let lines = snapshots.map { "- \($0.identifier): \($0.libraryCount) libraries" }
        return (["External Library Registry:"] + lines).joined(separator: "\n")
    }

    static func externalLibraryRegistrySnapshot(on device: MTLDevice? = nil) -> [ExternalLibraryProviderSnapshot] {
        let runtimeDevice = HarbethContext.shared.runtimeDevice
        let activeDevice = device ?? runtimeDevice.device
        return runtimeDevice.externalLibraryRegistry.snapshot().map {
            let libraries = $0.provideLibrary(for: activeDevice).map { _ in 1 } ?? 0
            return ExternalLibraryProviderSnapshot(identifier: $0.providerIdentifier, libraryCount: libraries)
        }
    }

    func externalLibraries(matching identifier: String? = nil) -> [MTLLibrary] {
        externalLibraryRegistry.snapshot().compactMap { provider in
            if let identifier, provider.providerIdentifier != identifier {
                return nil
            }
            return provider.provideLibrary(for: device)
        }
    }

    func externalLibraries() -> [MTLLibrary] {
        externalLibraries(matching: nil)
    }
}
