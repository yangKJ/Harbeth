//
//  MTLSize+Ext.swift
//  Harbeth
//
//  Created by Condy on 2023/8/8.
//

import Foundation
import MetalKit

extension MTLSize: C7Compatible { }

extension Queen where MTLSize == Base {
    
    /// Maximum metal texture size that can be processed.
    /// - Parameter device: Device information to create other objects.
    /// - Returns: New metal texture size.
    public func maxTextureSize(device: MTLDevice? = nil) -> MTLSize {
        func supportsOnly8K() -> Bool {
            let device = device ?? Device.device()
            #if targetEnvironment(macCatalyst)
            return !device.supportsFamily(.apple3)
            #elseif os(macOS)
            return false
            #else
            if #available(iOS 13.0, *) {
                return !device.supportsFamily(.apple3)
            } else if #available(iOS 11.0, *)  {
                return !device.supportsFeatureSet(.iOS_GPUFamily3_v3)
            } else {
                return false
            }
            #endif
        }
        let maxSide: Int = supportsOnly8K() ? 8192 : 16_384
        guard base.width > 0, base.height > 0 else {
            return .init(width: 0, height: 0, depth: 0)
        }
        let aspectRatio = Float(base.width) / Float(base.height)
        if aspectRatio > 1 {
            let resultWidth = min(base.width, maxSide)
            let resultHeight = Float(resultWidth) / aspectRatio
            return MTLSize(width: resultWidth, height: Int(resultHeight.rounded()), depth: 0)
        } else {
            let resultHeight = min(base.height, maxSide)
            let resultWidth = Float(resultHeight) * aspectRatio
            return MTLSize(width: Int(resultWidth.rounded()), height: resultHeight, depth: 0)
        }
    }
}
