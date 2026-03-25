//
//  MTLSize+Ext.swift
//  Harbeth
//
//  Created by Condy on 2023/8/8.
//

import Foundation
import MetalKit

extension MTLSize: HarbethCompatible { }

extension HarbethWrapper where MTLSize == Base {
    
    /// Maximum metal texture size that can be processed.
    /// - Parameter device: Device information to create other objects.
    /// - Returns: New metal texture size.
    public func maxTextureSize(device: MTLDevice? = nil) -> MTLSize {
        func getMaxTextureDimensions() -> (width: Int, height: Int) {
            let device = device ?? Device.device()
            #if targetEnvironment(macCatalyst)
            if device.supportsFamily(.apple3) {
                return (131072, 65536)
            } else {
                return (8192, 8192)
            }
            #elseif os(macOS)
            return (131072, 65536)
            #else
            if #available(iOS 13.0, *) {
                if device.supportsFamily(.apple3) {
                    return (65536, 65536)
                } else {
                    return (16384, 16384)
                }
            } else if #available(iOS 11.0, *)  {
                if device.supportsFeatureSet(.iOS_GPUFamily3_v3) {
                    return (16384, 16384)
                } else {
                    return (8192, 8192)
                }
            } else {
                return (8192, 8192)
            }
            #endif
        }
        
        let (maxWidth, maxHeight) = getMaxTextureDimensions()
        
        guard base.width > 0, base.height > 0 else {
            return .init(width: 0, height: 0, depth: 0)
        }
        
        let aspectRatio = Float(base.width) / Float(base.height)
        if aspectRatio > 1 {
            let resultWidth = min(base.width, maxWidth)
            let resultHeight = Float(resultWidth) / aspectRatio
            return MTLSize(width: resultWidth, height: min(Int(resultHeight.rounded()), maxHeight), depth: 0)
        } else {
            let resultHeight = min(base.height, maxHeight)
            let resultWidth = Float(resultHeight) * aspectRatio
            return MTLSize(width: min(Int(resultWidth.rounded()), maxWidth), height: resultHeight, depth: 0)
        }
    }
}
