//
//  CGContext+Ext.swift
//  Harbeth
//
//  Created by Condy on 2023/8/4.
//

import Foundation
import CoreGraphics
import ImageIO

extension CGContext: C7Compatible { }

extension Queen where Base: CGContext {
    
    @discardableResult public func perform(_ drawing: (CGContext) -> Void) -> CGContext {
        drawing(base)
        return base
    }
    
    public static func makeContext(for image: CGImage, size: CGSize? = nil) -> CGContext? {
        var bitmapInfo = image.bitmapInfo
        
        /**
         Modifies alpha info in order to solve following issues:
         
         [For creating CGContext]
         - A screenshot image taken on iPhone might be DisplayP3 16bpc. This is not supported in CoreGraphics.
         https://stackoverflow.com/a/42684334/2753383
         
         [For MTLTexture]
         - An image loaded from ImageIO seems to contains something different bitmap-info compared with UIImage(named:)
         That causes creating broken MTLTexture, technically texture contains alpha and wrong color format.
         I don't know why it happens.
         */
        bitmapInfo.remove(.alphaInfoMask)
        bitmapInfo.formUnion(.init(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue))
        // The image from PHImageManager uses `.byteOrder32Little`. This is not compatible with MTLTexture.
        bitmapInfo.remove(.byteOrder32Little)
        
        // Ref: https://github.com/guoyingtao/Mantis/issues/12
        let outputColorSpace: CGColorSpace
        if let colorSpace = image.colorSpace, colorSpace.supportsOutput {
            outputColorSpace = colorSpace
        } else {
            outputColorSpace = CGColorSpaceCreateDeviceRGB()
        }
        
        let width  = size.map { Int($0.width) } ?? image.width
        let height = size.map { Int($0.height) } ?? image.height
        
        if let context = CGContext(data: nil,
                                   width: width,
                                   height: height,
                                   bitsPerComponent: image.bitsPerComponent,
                                   bytesPerRow: 0,
                                   space: outputColorSpace,
                                   bitmapInfo: bitmapInfo.rawValue) {
            return context
        }
        if let context = CGContext(data: nil,
                                   width: width,
                                   height: height,
                                   bitsPerComponent: 8,
                                   bytesPerRow: 8 * 4 * image.width,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) {
            return context
        }
        return nil
    }
}
