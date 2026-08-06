//
//  FilterDestinationTextureContract.swift
//  Harbeth
//
//  Created by Condy on 2026/8/6.
//

import Metal

/// Filter requirements for input and output texture alias.
public enum DestinationTextureAliasingPolicy: String, Sendable, Codable, Equatable, Hashable {
    case requiredDistinct
    case inPlaceAllowed
}

/// Destination texture allocation contract shared by all filters.
public struct FilterDestinationTextureContract: Equatable {
    public let usage: MTLTextureUsage
    public let storageMode: MTLStorageMode?
    public let aliasingPolicy: DestinationTextureAliasingPolicy

    public init(
        usage: MTLTextureUsage = [.shaderRead, .shaderWrite],
        storageMode: MTLStorageMode? = nil,
        aliasingPolicy: DestinationTextureAliasingPolicy = .requiredDistinct
    ) {
        self.usage = usage
        self.storageMode = storageMode
        self.aliasingPolicy = aliasingPolicy
    }

    var fingerprint: String {
        [
            "usage=\(usage.rawValue)",
            "storage=\(storageMode.map { String($0.rawValue) } ?? "default")",
            "aliasing=\(aliasingPolicy.rawValue)"
        ].joined(separator: "|")
    }
}
