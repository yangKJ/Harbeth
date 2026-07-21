//
//  CMSampleBuffer+Ext.swift
//  Harbeth
//
//  Created by Condy on 2022/10/26.
//

import Foundation
import CoreMedia
import CoreVideo
import ImageIO

nonisolated(unsafe) let harbethFrameMirrorHorizontallyAttachmentKey = "io.harbeth.frame.mirrorHorizontally" as CFString
nonisolated(unsafe) let harbethFrameMirrorVerticallyAttachmentKey = "io.harbeth.frame.mirrorVertically" as CFString
nonisolated(unsafe) let harbethFrameFollowsDeviceOrientationAttachmentKey =
    "io.harbeth.frame.followsDeviceOrientation" as CFString

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

    @inline(__always)
    fileprivate func getSampleBufferAttachmentValue(for key: CFString) -> CFTypeRef? {
        CMGetAttachment(self, key: key, attachmentModeOut: nil)
    }

    @inline(__always)
    fileprivate func setSampleBufferAttachmentValue(for key: CFString, value: CFTypeRef) {
        CMSetAttachment(self, key: key, value: value, attachmentMode: kCMAttachmentMode_ShouldPropagate)
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
        let imageBuffer = CMSampleBufferGetImageBuffer(base)
        let imageBufferContract = imageBuffer?.c7.contract
        let bridgePlan = imageBuffer.map { $0.c7.makeTextureBridgePlan() }
        let frameContract = resolveFrameContract(formatDescription: formatDescription, imageBuffer: imageBuffer, bridgePlan: bridgePlan)
        return SampleBufferContract(
            numSamples: Int(CMSampleBufferGetNumSamples(base)),
            isValid: CMSampleBufferIsValid(base),
            presentationTimeStamp: TimeValueContract(time: CMSampleBufferGetPresentationTimeStamp(base)),
            decodeTimeStamp: TimeValueContract(time: CMSampleBufferGetDecodeTimeStamp(base)),
            duration: TimeValueContract(time: CMSampleBufferGetDuration(base)),
            formatDescriptionMediaType: formatDescription.map(CMFormatDescriptionGetMediaType),
            formatDescriptionMediaSubType: formatDescription.map(CMFormatDescriptionGetMediaSubType),
            pixelBufferContract: imageBufferContract,
            frameContract: frameContract,
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

    public func makeLightweightReferenceSampleBuffer() -> CMSampleBuffer? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(base) else {
            return nil
        }
        return makeDerivedSampleBuffer(imageBuffer: imageBuffer)
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
        copySampleBufferAttachment(kCGImagePropertyOrientation, to: sampleBuffer)
        copySampleBufferAttachment(harbethFrameMirrorHorizontallyAttachmentKey, to: sampleBuffer)
        copySampleBufferAttachment(harbethFrameMirrorVerticallyAttachmentKey, to: sampleBuffer)
        copySampleBufferAttachment(harbethFrameFollowsDeviceOrientationAttachmentKey, to: sampleBuffer)
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

    private func resolveFrameContract(formatDescription: CMFormatDescription?, imageBuffer: CVImageBuffer?, bridgePlan: PixelBufferTextureBridgePlan?) -> SampleBufferFrameContract {
        let explicitOrientation = resolveOrientation(formatDescription: formatDescription, imageBuffer: imageBuffer)
        let orientation = explicitOrientation ?? .up
        let explicitMirror = resolveMirrorFlags(formatDescription: formatDescription, imageBuffer: imageBuffer)
        let inferredMirror = explicitMirror ?? inferredMirrorFlags(from: orientation)
        let followsDeviceOrientation = resolveBoolAttachment(
            harbethFrameFollowsDeviceOrientationAttachmentKey,
            formatDescription: formatDescription,
            imageBuffer: imageBuffer
        )
        return SampleBufferFrameContract(
            ownerRetained: bridgePlan?.preservesOwnerReference ?? false,
            conversionStrategy: bridgePlan?.loadStrategy,
            directPlaneBridgeCount: bridgePlan?.directPlaneBridgeCount ?? 0,
            orientation: orientation,
            mirrorHorizontally: inferredMirror.horizontal,
            mirrorVertically: inferredMirror.vertical,
            followsDeviceOrientation: followsDeviceOrientation ?? false,
            hasExplicitOrientation: explicitOrientation != nil,
            hasExplicitMirror: explicitMirror != nil || orientation.isMirrored,
            hasExplicitDeviceOrientation: followsDeviceOrientation != nil
        )
    }

    private func resolveOrientation(formatDescription: CMFormatDescription?, imageBuffer: CVImageBuffer?) -> FrameOrientation? {
        resolveOrientationAttachment(kCGImagePropertyOrientation, formatDescription: formatDescription, imageBuffer: imageBuffer)
    }

    private func resolveMirrorFlags(formatDescription: CMFormatDescription?, imageBuffer: CVImageBuffer?) -> (horizontal: Bool, vertical: Bool)? {
        let horizontal = resolveBoolAttachment(
            harbethFrameMirrorHorizontallyAttachmentKey,
            formatDescription: formatDescription,
            imageBuffer: imageBuffer
        )
        let vertical = resolveBoolAttachment(
            harbethFrameMirrorVerticallyAttachmentKey,
            formatDescription: formatDescription,
            imageBuffer: imageBuffer
        )
        guard horizontal != nil || vertical != nil else {
            return nil
        }
        return (horizontal ?? false, vertical ?? false)
    }

    private func resolveOrientationAttachment(_ key: CFString, formatDescription: CMFormatDescription?, imageBuffer: CVImageBuffer?) -> FrameOrientation? {
        if let value = base.getSampleBufferAttachmentValue(for: key),
           let orientation = Self.frameOrientation(from: value) {
            return orientation
        }
        if let formatDescription,
           let extensions = CMFormatDescriptionGetExtensions(formatDescription) as? [CFString: Any],
           let value = extensions[key],
           let orientation = Self.frameOrientation(from: value as CFTypeRef) {
            return orientation
        }
        if let imageBuffer,
           let value = CVBufferGetAttachment(imageBuffer, key, nil)?.takeUnretainedValue(),
           let orientation = Self.frameOrientation(from: value) {
            return orientation
        }
        return nil
    }

    private func resolveBoolAttachment(_ key: CFString, formatDescription: CMFormatDescription?, imageBuffer: CVImageBuffer?) -> Bool? {
        if let value = base.getSampleBufferAttachmentValue(for: key),
           let boolValue = Self.boolValue(from: value) {
            return boolValue
        }
        if let formatDescription,
           let extensions = CMFormatDescriptionGetExtensions(formatDescription) as? [CFString: Any],
           let value = extensions[key],
           let boolValue = Self.boolValue(from: value as CFTypeRef) {
            return boolValue
        }
        if let imageBuffer,
           let value = CVBufferGetAttachment(imageBuffer, key, nil)?.takeUnretainedValue(),
           let boolValue = Self.boolValue(from: value) {
            return boolValue
        }
        return nil
    }

    private func copySampleBufferAttachment(_ key: CFString, to sampleBuffer: CMSampleBuffer) {
        guard let value = base.getSampleBufferAttachmentValue(for: key) else {
            return
        }
        sampleBuffer.setSampleBufferAttachmentValue(for: key, value: value)
    }

    private func inferredMirrorFlags(from orientation: FrameOrientation) -> (horizontal: Bool, vertical: Bool) {
        switch orientation {
        case .upMirrored, .rightMirrored:
            return (true, false)
        case .downMirrored, .leftMirrored:
            return (false, true)
        case .up, .down, .left, .right, .unknown:
            return (false, false)
        }
    }

    private static func frameOrientation(from value: CFTypeRef) -> FrameOrientation? {
        if let number = value as? NSNumber {
            return frameOrientation(fromRawValue: number.uint32Value)
        }
        if let string = value as? NSString {
            return frameOrientation(fromRawValue: UInt32(string.integerValue))
        }
        return nil
    }

    private static func frameOrientation(fromRawValue rawValue: UInt32) -> FrameOrientation? {
        guard let orientation = CGImagePropertyOrientation(rawValue: rawValue) else {
            return nil
        }
        switch orientation {
        case .up:
            return .up
        case .upMirrored:
            return .upMirrored
        case .down:
            return .down
        case .downMirrored:
            return .downMirrored
        case .leftMirrored:
            return .leftMirrored
        case .right:
            return .right
        case .rightMirrored:
            return .rightMirrored
        case .left:
            return .left
        @unknown default:
            return .unknown
        }
    }

    private static func boolValue(from value: CFTypeRef) -> Bool? {
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if CFGetTypeID(value) == CFBooleanGetTypeID() {
            return CFBooleanGetValue((value as! CFBoolean))
        }
        return nil
    }
}

private extension FrameOrientation {
    var isMirrored: Bool {
        switch self {
        case .upMirrored, .downMirrored, .leftMirrored, .rightMirrored:
            return true
        case .up, .down, .left, .right, .unknown:
            return false
        }
    }
}
