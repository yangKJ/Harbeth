//
//  URL+Ext.swift
//  Harbeth
//
//  Created by Condy on 2022/12/8.
//

import Foundation

extension URL: C7Compatible { }

extension Queen where Base == URL {
    
    public func loadCGImage() -> CGImage? {
        #if os(macOS)
        guard let nsImage = C7Image(contentsOf: base),
              let tiffData = nsImage.tiffRepresentation,
              let cgImageSource = CGImageSourceCreateWithData(tiffData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) else {
            return nil
        }
        return cgImage
        #else
        guard let uiImage = C7Image(contentsOfFile: base.path) else {
            return nil
        }
        return uiImage.cgImage
        #endif
    }
}
