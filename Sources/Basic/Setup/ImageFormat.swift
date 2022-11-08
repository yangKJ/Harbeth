//
//  ImageFormat.swift
//  Harbeth
//
//  Created by Condy on 2022/10/10.
//

import Foundation

// see https://developers.google.com/speed/webp/docs/riff_container

public enum ImageFormat {
    case Unknow
    case JPEG
    case PNG
    case GIF
    case TIFF
    case WebP
    case HEIC
    case HEIF
}

extension Queen where Data == Base {
    /// Gets the image format corresponding to the data.
    public var imageFormat: ImageFormat  {
        var buffer = [UInt8](repeating: 0, count: 1)
        self.base.copyBytes(to: &buffer, count: 1)
        switch buffer {
        case [0xFF]:
            return .JPEG
        case [0x89]:
            return .PNG
        case [0x47]:
            return .GIF
        case [0x49], [0x4D]:
            return .TIFF
        case [0x52] where self.base.count >= 12:
            if let str = String(data: self.base[0...11], encoding: .ascii), str.hasPrefix("RIFF"), str.hasSuffix("WEBP") {
                return .WebP
            }
        case [0x00] where self.base.count >= 12:
            if let str = String(data: self.base[8...11], encoding: .ascii) {
                let HEICBitMaps = Set(["heic", "heis", "heix", "hevc", "hevx"])
                if HEICBitMaps.contains(str) {
                    return .HEIC
                }
                let HEIFBitMaps = Set(["mif1", "msf1"])
                if HEIFBitMaps.contains(str) {
                    return .HEIF
                }
            }
        default:
            break;
        }
        return .Unknow
    }
}
