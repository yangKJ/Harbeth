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
extension C7Image: C7FilterOutput {
    
    public func make<T>(filter: C7FilterProtocol) throws -> T where T : C7FilterOutput {
        guard let inTexture = mt.toTexture() else {
            throw C7CustomError.source2Texture
        }
        do {
            let outTexture = try Processed.generateOutTexture(inTexture: inTexture, filter: filter)
            guard let outImage = outTexture.toImage() else {
                throw C7CustomError.texture2Image
            }
            return outImage as! T
        } catch {
            throw error
        }
    }
    
    public func makeGroup<T>(filters: [C7FilterProtocol]) throws -> T where T : C7FilterOutput {
        guard let inTexture = mt.toTexture() else {
            throw C7CustomError.source2Texture
        }
        do {
            var outTexture: MTLTexture = inTexture
            for filter in filters {
                outTexture = try Processed.generateOutTexture(inTexture: outTexture, filter: filter)
            }
            return (outTexture.toImage() ?? self) as! T
        } catch {
            throw error
        }
    }
}
