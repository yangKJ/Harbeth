//
//  Image+Ext.swift
//  Harbeth
//
//  Created by Condy on 2023/7/27.
//

import Foundation
import SwiftUI

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
extension Image {
    
    public init(cgImage: CGImage) {
        self.init(c7Image: cgImage.c7.toC7Image())
    }
    
    public init(c7Image: C7Image) {
        #if os(iOS) || os(tvOS)
        self.init(uiImage: c7Image)
        #elseif os(macOS)
        self.init(nsImage: c7Image)
        #else
        #error("Unsupported Platform")
        #endif
    }
}
