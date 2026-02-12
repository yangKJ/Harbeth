//
//  ExternalMTLLibraryProvider.swift
//  Harbeth
//
//  Created by Condy on 2026/2/12.
//

import Foundation

/// External MTLLibrary Provider Agreement
public protocol ExternalMTLLibraryProvider {
    
    func provideLibrary(for device: MTLDevice) -> MTLLibrary?
}

extension Device {
    
    private static var externalLibraryProviders: [ExternalMTLLibraryProvider] = []
    
    public static func registerExternalLibraryProvider(_ provider: ExternalMTLLibraryProvider) {
        externalLibraryProviders.append(provider)
    }
    
    func externalLibraries() -> [MTLLibrary] {
        return Device.externalLibraryProviders.compactMap { $0.provideLibrary(for: device) }
    }
}
