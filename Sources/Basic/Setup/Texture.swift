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
        
        let bitmapInfo = CGBitmapInfo(rawValue: Device.bitmapInfo())
        let colorSpace = Device.colorSpace()
        
        if let cfdata = CFDataCreate(kCFAllocatorDefault, &src, bytesPerRow * height),
           let dataProvider = CGDataProvider(data: cfdata),
           let cgimage = CGImage(width: width, height: height,
                                 bitsPerComponent: 8,
                                 bitsPerPixel: 32,
                                 bytesPerRow: bytesPerRow,
                                 space: colorSpace,
                                 bitmapInfo: bitmapInfo,
                                 provider: dataProvider,
                                 decode: nil,
                                 shouldInterpolate: true,
                                 intent: .defaultIntent) {
            return cgimage
        }
        return nil
    }
    
    public func toImage() -> C7Image? {
        guard let cgImage = toCGImage() else { return nil }
        return C7Image(cgImage: cgImage)
    }
}
