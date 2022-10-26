//
//  CMSampleBuffer+Ext.swift
//  Harbeth
//
//  Created by Condy on 2022/10/26.
//

import Foundation
import CoreMedia.CMSampleBuffer

extension CMSampleBuffer: C7Compatible { }

extension Queen where Base: CMSampleBuffer {
    
    public func toCGImage() -> CGImage? {
        let pixelBuffer = CMSampleBufferGetImageBuffer(base)
        return pixelBuffer?.mt.toCGImage()
    }
}
