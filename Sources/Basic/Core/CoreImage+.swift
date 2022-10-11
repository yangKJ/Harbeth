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
        let options = [CIContextOption.workingColorSpace: Device.colorSpace(cgImage)]
        var context: CIContext
        if #available(iOS 13.0, *) {
            context = CIContext(mtlCommandQueue: Device.commandQueue(), options: options)
        } else {
            context = CIContext(options: options)
        }
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

extension COImage {
    
    @inlinable static func render(texture: MTLTexture, name: String, filter: C7FilterProtocol) -> MTLTexture {
        guard let cgImage = texture.toCGImage() else {
            return texture
        }
        let ciimage = CIImage.init(cgImage: cgImage)
        let cifiter = CIFilter.init(name: name)
        filter.coreImageSetupCIFilter(cifiter, input: cgImage)
        cifiter?.setValue(ciimage, forKeyPath: kCIInputImageKey)
        
        let colorSpace = Device.colorSpace(cgImage)
        cifiter?.outputImage?.mt.renderImageToTexture(texture, colorSpace: colorSpace)
        
        return texture
    }
}
