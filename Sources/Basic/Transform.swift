//
//  Transform.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/7.
//

import Foundation
import MetalKit
import ImageIO

extension MTLTexture {
    public func toCGImage() -> CGImage? {
        let bytesPerPixel: Int = 4
        let imageByteCount = width * height * bytesPerPixel
        let bytesPerRow = width * bytesPerPixel
        var src = [UInt8](repeating: 0, count: Int(imageByteCount))
        
        let region = MTLRegionMake3D(0, 0, 0, width, height, 1)
        self.getBytes(&src, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        //kCGImageAlphaPremultipliedLast保留透明度
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        let colorSpace = Device.shared.colorSpace//CGColorSpaceCreateDeviceRGB()
        
        let bitsPerComponent = 8
        let context = CGContext(data: &src,
                                width: width,
                                height: height,
                                bitsPerComponent: bitsPerComponent,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo)
        
        guard let context = context else { return nil }
        return context.makeImage()
    }
    
    public func toImage() -> C7Image? {
        guard let cgImage = toCGImage() else {
            return nil
        }
        return C7Image(cgImage: cgImage)
    }
}
