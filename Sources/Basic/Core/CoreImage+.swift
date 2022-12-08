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
        guard let filter = filter as? CoreImageFiltering else { return ciImage }
        let cifiter = CIFilter.init(name: name)
        let ciimage = filter.coreImageApply(filter: cifiter, input: ciImage)
        cifiter?.setValue(ciimage, forKeyPath: kCIInputImageKey)
        return cifiter?.outputImage ?? ciimage
    }
    
    @inlinable static func drawingProcess(cgImage: CGImage, name: String, filter: C7FilterProtocol) -> CGImage {
        let ciimage = CIImage.init(cgImage: cgImage)
        let outputCIImage = drawingProcess(ciImage: ciimage, name: name, filter: filter)
        if let outputcgImage = outputCIImage.cgImage {
            return outputcgImage
        }
        let context = Device.context(cgImage: cgImage)
        let outputcgImage = context.createCGImage(outputCIImage, from: outputCIImage.extent)
        return outputcgImage ?? cgImage
    }
    
    @inlinable static func drawingProcess(texture: MTLTexture, name: String, filter: C7FilterProtocol) -> MTLTexture {
        guard let cgImage = texture.toCGImage() else {
            return texture
        }
        let outputcgImage = Self.drawingProcess(cgImage: cgImage, name: name, filter: filter)
        let image = outputcgImage.mt.toC7Image()
        return image.mt.toTexture() ?? texture
    }
}

extension COImage {
    
    @inlinable static func render(texture: MTLTexture, name: String, filter: C7FilterProtocol) -> MTLTexture {
        guard let cgImage = texture.toCGImage() else {
            return texture
        }
        var ciimage = CIImage.init(cgImage: cgImage)
        let cifiter = CIFilter.init(name: name)
        if let filter = filter as? CoreImageFiltering {
            ciimage = filter.coreImageApply(filter: cifiter, input: ciimage)
        }
        cifiter?.setValue(ciimage, forKeyPath: kCIInputImageKey)
        
        let colorSpace = Device.colorSpace()
        cifiter?.outputImage?.mt.renderImageToTexture(texture, colorSpace: colorSpace)
        
        return texture
    }
}
