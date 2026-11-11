//
//  LookupTextureResource.swift
//  Harbeth
//
//  Created by Condy on 2026/11/11.
//

import CryptoKit
import Foundation
import ImageIO
import Metal

/// Loads versioned lookup images without owning a style catalog or private image assets.
public enum LookupTextureResource {
    /// A resource version identifies immutable file contents. Change it when replacing the image.
    /// Conversion preserves the existing CGImage lookup path and the active context color space.
    public static func load(url: URL, version: String, pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MTLTexture {
        guard url.isFileURL, !version.isEmpty, pixelFormat == .rgba8Unorm || pixelFormat == .bgra8Unorm else {
            throw HarbethError.configurationInvalid("Lookup images require a versioned file and an RGBA8 format.")
        }
        let context = HarbethContext.shared
        let profile = context.colorSpace.copyICCData().map { $0 as Data } ?? Data()
        let profileKey = SHA256.hash(data: profile).map { String(format: "%02x", $0) }.joined()
        let key = "\(url.standardizedFileURL.path)|\(version)|\(pixelFormat.rawValue)|\(profileKey)|space=\(CFHash(context.colorSpace))"
        let identity = context.makeDerivedResourceIdentity(
            domain: .lookupTable,
            namespace: "\(context.currentDerivedResourceNamespace)/LookupTextureResource",
            fingerprint: key
        )
        return try context.makeDerivedTexture(for: identity) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
                  let texture = image.c7.toTexture(pixelFormat: pixelFormat) else {
                throw HarbethError.source2Texture
            }
            return texture
        }
    }
}
