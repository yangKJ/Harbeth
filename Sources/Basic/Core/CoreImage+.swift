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
    
    @inlinable static func drawingProcess(ciImage: CIImage, name: String, filter: C7FilterProtocol) -> CIImage {
        let cifiter = CIFilter.init(name: name)
        let ciimage = filter.coreImageApply(filter: cifiter, input: ciImage)
        cifiter?.setValue(ciimage, forKeyPath: kCIInputImageKey)
        return cifiter?.outputImage ?? ciimage
    }
    
    @inlinable static func drawingProcess(cgImage: CGImage, name: String, filter: C7FilterProtocol) -> CGImage {
        let ciimage = CIImage.init(cgImage: cgImage)
        let outputImage = drawingProcess(ciImage: ciimage, name: name, filter: filter)
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
        var ciimage = CIImage.init(cgImage: cgImage)
        let cifiter = CIFilter.init(name: name)
        ciimage = filter.coreImageApply(filter: cifiter, input: ciimage)
        cifiter?.setValue(ciimage, forKeyPath: kCIInputImageKey)
        
        let colorSpace = Device.colorSpace(cgImage)
        cifiter?.outputImage?.mt.renderImageToTexture(texture, colorSpace: colorSpace)
        
        return texture
    }
}
