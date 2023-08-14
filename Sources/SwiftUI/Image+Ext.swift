//
//  Image+Ext.swift
//  Harbeth
//
//  Created by Condy on 2023/7/27.
//

import Foundation
import SwiftUI

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
extension Image {
    
    public init(cgImage: CGImage) {
        self.init(c7Image: cgImage.c7.toC7Image())
    }
    
    public init(c7Image: C7Image) {
        #if os(iOS)
        self.init(uiImage: c7Image)
        #elseif os(macOS)
        self.init(nsImage: c7Image)
        #else
        #error("Unsupported Platform")
        #endif
    }
}

#if os(iOS) || os(tvOS) || os(watchOS)

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
extension C7Image.Orientation {
    
    @inlinable var toSwiftUI: Image.Orientation {
        switch self {
        case .up:
            return .up
        case .upMirrored:
            return .upMirrored
        case .down:
            return .down
        case .downMirrored:
            return .downMirrored
        case .left:
            return .left
        case .leftMirrored:
            return .leftMirrored
        case .right:
            return .right
        case .rightMirrored:
            return .rightMirrored
        @unknown default:
            return .up
        }
    }
}

#endif

