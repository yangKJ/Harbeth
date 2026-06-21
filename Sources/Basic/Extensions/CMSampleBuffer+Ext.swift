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
    public var attachmentContract: SampleAttachmentContract {
        SampleAttachmentContract(
            notSync: base.getAttachmentValue(for: kCMSampleAttachmentKey_NotSync),
            dependsOnOthers: base.getAttachmentValue(for: kCMSampleAttachmentKey_DependsOnOthers),
            earlierDisplayTimesAllowed: base.getAttachmentValue(for: kCMSampleAttachmentKey_EarlierDisplayTimesAllowed),
            displayImmediately: base.getAttachmentValue(for: kCMSampleAttachmentKey_DisplayImmediately),
            doNotDisplay: base.getAttachmentValue(for: kCMSampleAttachmentKey_DoNotDisplay)
        )
    }

    public var contract: SampleBufferContract {
        let formatDescription = CMSampleBufferGetFormatDescription(base)
        let imageBufferContract = CMSampleBufferGetImageBuffer(base)?.c7.contract
        return SampleBufferContract(
            numSamples: Int(CMSampleBufferGetNumSamples(base)),
            isValid: CMSampleBufferIsValid(base),
            presentationTimeStamp: TimeValueContract(time: CMSampleBufferGetPresentationTimeStamp(base)),
            decodeTimeStamp: TimeValueContract(time: CMSampleBufferGetDecodeTimeStamp(base)),
            duration: TimeValueContract(time: CMSampleBufferGetDuration(base)),
            formatDescriptionMediaType: formatDescription.map(CMFormatDescriptionGetMediaType),
            formatDescriptionMediaSubType: formatDescription.map(CMFormatDescriptionGetMediaSubType),
            pixelBufferContract: imageBufferContract,
            attachments: attachmentContract
        )
    }

    public func makeDerivedSampleBuffer(imageBuffer: CVImageBuffer) -> CMSampleBuffer? {
        var timingInfo = CMSampleTimingInfo(
            duration: CMSampleBufferGetDuration(base),
            presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(base),
            decodeTimeStamp: CMSampleBufferGetDecodeTimeStamp(base)
        )
        var formatDescription: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: imageBuffer,
            formatDescriptionOut: &formatDescription
        ) == noErr,
        let formatDescription else {
            return nil
        }
        var sampleBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: imageBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        guard status == noErr, let sampleBuffer else {
            return nil
        }
        copyAttachments(to: sampleBuffer)
        return sampleBuffer
    }

    public func copyAttachments(to sampleBuffer: CMSampleBuffer) {
        let values: [(CFString, Bool?)] = [
            (kCMSampleAttachmentKey_NotSync, base.getAttachmentValue(for: kCMSampleAttachmentKey_NotSync)),
            (kCMSampleAttachmentKey_DependsOnOthers, base.getAttachmentValue(for: kCMSampleAttachmentKey_DependsOnOthers)),
            (kCMSampleAttachmentKey_EarlierDisplayTimesAllowed, base.getAttachmentValue(for: kCMSampleAttachmentKey_EarlierDisplayTimesAllowed)),
            (kCMSampleAttachmentKey_DisplayImmediately, base.getAttachmentValue(for: kCMSampleAttachmentKey_DisplayImmediately)),
            (kCMSampleAttachmentKey_DoNotDisplay, base.getAttachmentValue(for: kCMSampleAttachmentKey_DoNotDisplay))
        ]
        for (key, value) in values {
            guard let value else { continue }
            sampleBuffer.setAttachmentValue(for: key, value: value)
        }
    }
    
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
    
    /// Returns the numerically earliest delivery timestamp.
    public var presentationTimeStamp: CMTime {
        CMSampleBufferGetPresentationTimeStamp(base)
    }
}
