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

private final class ExternalLibraryProviderRegistry: @unchecked Sendable {
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
    private static let externalLibraryRegistry = ExternalLibraryProviderRegistry()

    @discardableResult
    static func registerExternalLibraryProvider(_ provider: ExternalMTLLibraryProvider) -> Bool {
        externalLibraryRegistry.register(provider)
    }

    static func externalLibraryProviderIdentifiers() -> [String] {
        externalLibraryRegistry.snapshot().map(\.providerIdentifier)
    }

    static func externalLibraryRegistryDebugDescription(on device: MTLDevice? = nil) -> String {
        let activeDevice = device
        let snapshots = externalLibraryRegistrySnapshot(on: activeDevice)
        if snapshots.isEmpty {
            return "External Library Registry: empty"
        }
        let lines = snapshots.map { "- \($0.identifier): \($0.libraryCount) libraries" }
        return (["External Library Registry:"] + lines).joined(separator: "\n")
    }

    static func externalLibraryRegistrySnapshot(on device: MTLDevice? = nil) -> [ExternalLibraryProviderSnapshot] {
        let providers = externalLibraryRegistry.snapshot()
        guard let activeDevice = device else {
            return providers.map {
                ExternalLibraryProviderSnapshot(identifier: $0.providerIdentifier, libraryCount: 0)
            }
        }
        return providers.map {
            let libraries = $0.provideLibrary(for: activeDevice).map { _ in 1 } ?? 0
            return ExternalLibraryProviderSnapshot(identifier: $0.providerIdentifier, libraryCount: libraries)
        }
    }

    func externalLibraries(matching identifier: String? = nil) -> [MTLLibrary] {
        Device.externalLibraryRegistry.snapshot().compactMap { provider in
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
