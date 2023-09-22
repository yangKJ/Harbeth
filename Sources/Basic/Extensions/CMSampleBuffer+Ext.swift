//
//  CMSampleBuffer+Ext.swift
//  Harbeth
//
//  Created by Condy on 2022/10/26.
//

import Foundation
import CoreMedia

extension CMSampleBuffer: C7Compatible { }

extension Queen where Base: CMSampleBuffer {
    
    public func toCGImage() -> CGImage? {
        let pixelBuffer = CMSampleBufferGetImageBuffer(base)
        return pixelBuffer?.c7.toCGImage()
    }
    
    public func toImage() -> C7Image? {
        toCGImage()?.c7.toC7Image()
    }
}
