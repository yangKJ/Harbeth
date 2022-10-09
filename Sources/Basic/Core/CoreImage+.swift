//
//  CoreImage+.swift
//  Harbeth
//
//  Created by 77。 on 2022/7/13.
//

import Foundation
import CoreImage
import MetalKit

internal struct COImage {
    
    @inlinable static func drawingProcess(cgImage: CGImage, name: String, filter: C7FilterProtocol) -> CGImage {
        let ciimage = CIImage.init(cgImage: cgImage)
        let cifiter = CIFilter.init(name: name)
        filter.coreImageSetupCIFilter(cifiter, input: cgImage)
        cifiter?.setValue(ciimage, forKeyPath: kCIInputImageKey)
        guard let outputImage = cifiter?.outputImage else {
            return cgImage
        }
        let context = CIContext(options: [
            CIContextOption.workingColorSpace: Device.colorSpace(cgImage)
        ])
        let outputcgImage = context.createCGImage(outputImage, from: outputImage.extent)
        return outputcgImage ?? cgImage
    }
    
    @inlinable static func drawingProcess(texture: MTLTexture, name: String, filter: C7FilterProtocol) -> MTLTexture {
        guard var cgImage = texture.toCGImage() else {
            return texture
        }
        cgImage = Self.drawingProcess(cgImage: cgImage, name: name, filter: filter)
        
        return C7Image(cgImage: cgImage).mt.toTexture() ?? texture
    }
}
