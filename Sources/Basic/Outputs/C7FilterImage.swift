//
//  C7FilterImage.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import MetalKit

extension C7Image: C7Compatible { }

/// 以下模式均只支持基于并行计算编码器`compute(kernel: String)`
/// The following modes support only the encoder based on parallel computing
///
extension C7Image: C7FilterDestProtocol {
    
    public func make<T>(filter: C7FilterProtocol) throws -> T where T : C7FilterDestProtocol {
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
    
    public func makeGroup<T>(filters: [C7FilterProtocol]) throws -> T where T : C7FilterDestProtocol {
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

extension Queen where Base == C7Image {
    
    /// Image to texture
    ///
    /// Texture loader can not load image data to create texture
    /// Draw image and create texture
    /// - Returns: MTLTexture
    public func toTexture() -> MTLTexture? {
        guard let cgimage = base.cgImage else { return nil }
        let loader = Shared.shared.device!.textureLoader
        let options = [MTKTextureLoader.Option.SRGB : false]
        if let texture = try? loader.newTexture(cgImage: cgimage, options: options) {
            return texture
        }
        
        let width = cgimage.width, height = cgimage.height
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = MTLPixelFormat.rgba8Unorm
        descriptor.width = width
        descriptor.height = height
        descriptor.usage = MTLTextureUsage.shaderRead
        let bytesPerPixel: Int = 4
        let bytesPerRow = width * bytesPerPixel
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        let colorSpace = Shared.shared.device!.colorSpace
        
        if let currentTexture = Device.device().makeTexture(descriptor: descriptor),
           let context = CGContext(data: nil,
                                   width: width,
                                   height: height,
                                   bitsPerComponent: 8,
                                   bytesPerRow: bytesPerRow,
                                   space: colorSpace,
                                   bitmapInfo: bitmapInfo) {
            context.draw(cgimage, in: CGRect(x: 0, y: 0, width: width, height: height))
            if let data = context.data {
                let region = MTLRegionMake3D(0, 0, 0, width, height, 1)
                currentTexture.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: bytesPerRow)
                return currentTexture
            }
        }
        return nil
    }
    
    /// Convert to a filter image
    public func convert2FilterImage(filters: [C7FilterProtocol]) -> C7Image {
        guard var texture = toTexture() else { return base }
        filters.forEach { texture = texture ->> $0 }
        if let image = texture.toImage() {
            return image
        }
        return base
    }
}
