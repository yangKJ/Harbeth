//
//  R.swift
//  Harbeth
//
//  Created by Condy on 2022/10/19.
//

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 资源文件读取
public struct R {
    
    /// Load image resources
    public static func image(_ named: String, forResource: String = "Harbeth") -> C7Image {
        let imageblock = { (name: String) -> C7Image in
            let image = C7Image(named: named)
            return image ?? C7Image()
        }
        guard let bundlePath = Bundle.main.path(forResource: forResource, ofType: "bundle") else {
            return imageblock(named)
        }
        let bundle = Bundle.init(path: bundlePath)
        #if os(iOS) || os(tvOS) || os(watchOS)
        guard let image = C7Image(named: named, in: bundle, compatibleWith: nil) else {
            return imageblock(named)
        }
        return image
        #elseif os(macOS)
        guard let image = bundle?.image(forResource: named) else {
            return imageblock(named)
        }
        return image
        #else
        #error("Unsupported Platform")
        #endif
    }
}
