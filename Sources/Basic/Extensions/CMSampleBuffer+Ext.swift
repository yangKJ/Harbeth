//
//  CMSampleBuffer+Ext.swift
//  Harbeth
//
//  Created by Condy on 2022/10/26.
//

import Foundation
import CoreMedia

extension CMSampleBuffer: HarbethCompatible {
    @inline(__always)
    fileprivate func getAttachmentValue(for key: CFString) -> Bool? {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(self, createIfNecessary: false) as? [[CFString: Any]],
              let value = attachments.first?[key] as? Bool else {
            return nil
        }
        return value
    }
    
    @inline(__always)
    fileprivate func setAttachmentValue(for key: CFString, value: Bool) {
        guard let attachments: CFArray = CMSampleBufferGetSampleAttachmentsArray(self, createIfNecessary: true),
              0 < CFArrayGetCount(attachments) else {
            return
        }
        let attachment = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
        let key_ = Unmanaged.passUnretained(key).toOpaque()
        let value_ = Unmanaged.passUnretained(value ? kCFBooleanTrue : kCFBooleanFalse).toOpaque()
        CFDictionarySetValue(attachment, key_, value_)
    }
}

extension HarbethWrapper where Base: CMSampleBuffer {
    
    public func toCGImage() -> CGImage? {
        let pixelBuffer = CMSampleBufferGetImageBuffer(base)
        return pixelBuffer?.c7.toCGImage()
    }
    
    public func toImage() -> C7Image? {
        toCGImage()?.c7.toC7Image()
    }
    
    public var isNotSync: Bool {
        get {
            base.getAttachmentValue(for: kCMSampleAttachmentKey_NotSync) ?? false
        }
        set {
            base.setAttachmentValue(for: kCMSampleAttachmentKey_NotSync, value: newValue)
        }
    }
    
    /// Queries whether a sample buffer is still valid.
    public var isValid: Bool {
        CMSampleBufferIsValid(base)
    }
    
    public var dataBuffer: CMBlockBuffer? {
        get {
            CMSampleBufferGetDataBuffer(base)
        }
        set {
            _ = newValue.map {
                CMSampleBufferSetDataBuffer(base, newValue: $0)
            }
        }
    }
    
    /// Returns a CMSampleBuffer's CVImageBuffer of media data.
    public var imageBuffer: CVImageBuffer? {
        CMSampleBufferGetImageBuffer(base)
    }
    
    /// Returns the number of media.
    public var numSamples: CMItemCount {
        CMSampleBufferGetNumSamples(base)
    }
    
    /// Returns the total duration.
    public var duration: CMTime {
        CMSampleBufferGetDuration(base)
    }
    
    /// Returns the format description.
    public var formatDescription: CMFormatDescription? {
        CMSampleBufferGetFormatDescription(base)
    }
    
    /// Returns the numerically earliest decode timestamp.
    public var decodeTimeStamp: CMTime {
        CMSampleBufferGetDecodeTimeStamp(base)
    }
    
    /// Returns the numerically earliest presentation timestamp.
    public var presentationTimeStamp: CMTime {
        CMSampleBufferGetPresentationTimeStamp(base)
    }
}
