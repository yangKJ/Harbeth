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

extension Device {
    private static var externalLibraryProviders: [ExternalMTLLibraryProvider] = []

    @discardableResult
    public static func registerExternalLibraryProvider(_ provider: ExternalMTLLibraryProvider) -> Bool {
        let identifier = provider.providerIdentifier
        guard externalLibraryProviders.contains(where: { $0.providerIdentifier == identifier }) == false else {
            return false
        }
        externalLibraryProviders.append(provider)
        return true
    }

    public static func externalLibraryProviderIdentifiers() -> [String] {
        externalLibraryProviders.map(\.providerIdentifier)
    }

    public static func externalLibraryRegistryDebugDescription(on device: MTLDevice? = nil) -> String {
        let activeDevice = device ?? (Shared.shared.hasDevice ? Shared.shared.device?.device : nil)
        let snapshots = externalLibraryRegistrySnapshot(on: activeDevice)
        if snapshots.isEmpty {
            return "External Library Registry: empty"
        }
        let lines = snapshots.map { "- \($0.identifier): \($0.libraryCount) libraries" }
        return (["External Library Registry:"] + lines).joined(separator: "\n")
    }

    public static func externalLibraryRegistrySnapshot(on device: MTLDevice? = nil) -> [ExternalLibraryProviderSnapshot] {
        guard let activeDevice = device else {
            return externalLibraryProviders.map { ExternalLibraryProviderSnapshot(identifier: $0.providerIdentifier, libraryCount: 0) }
        }
        return externalLibraryProviders.map {
            let libraries = $0.provideLibrary(for: activeDevice).map { _ in 1 } ?? 0
            return ExternalLibraryProviderSnapshot(identifier: $0.providerIdentifier, libraryCount: libraries)
        }
    }

    func externalLibraries() -> [MTLLibrary] {
        Device.externalLibraryProviders.compactMap { $0.provideLibrary(for: device) }
    }
}
