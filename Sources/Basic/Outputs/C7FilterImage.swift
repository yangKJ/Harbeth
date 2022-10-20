//
//  C7FilterImage.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation

/// 以下模式均只支持基于并行计算编码器`compute(kernel: String)`
/// The following modes support only the encoder based on parallel computing
///
extension C7Image: Outputable {
    
    public func make<T>(filter: C7FilterProtocol) throws -> T where T : Outputable {
        guard let inTexture = mt.toTexture() else {
            throw C7CustomError.source2Texture
        }
        do {
            let outTexture = try Processed.IO(inTexture: inTexture, filter: filter)
            return try fixImageOrientation(texture: outTexture) as! T
        } catch {
            throw error
        }
    }
    
    public func makeGroup<T>(filters: [C7FilterProtocol]) throws -> T where T : Outputable {
        guard let inTexture = mt.toTexture() else {
            throw C7CustomError.source2Texture
        }
        do {
            var outTexture: MTLTexture = inTexture
            for filter in filters {
                outTexture = try Processed.IO(inTexture: outTexture, filter: filter)
            }
            return try fixImageOrientation(texture: outTexture) as! T
        } catch {
            throw error
        }
    }
    
    private func fixImageOrientation(texture: MTLTexture) throws -> C7Image {
        guard let cgImage = texture.toCGImage() else {
            throw C7CustomError.texture2Image
        }
        // Fixed an issue with HEIC flipping after adding filter.
        return C7Image(cgImage: cgImage, scale: self.scale, orientation: self.imageOrientation)
    }
}
