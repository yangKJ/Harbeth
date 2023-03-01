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
    
    /// Read image resources
    public static func image(_ named: String, forResource: String = "Harbeth") -> C7Image? {
        let imageblock = { (name: String) -> C7Image? in
            C7Image.init(named: name)
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
        return nil
        #endif
    }
    
    /// Read multilingual text resources
    public static func text(_ named: String, forResource: String = "Harbeth", comment: String = "Localizable") -> String {
        guard let bundlePath = Bundle.main.path(forResource: forResource, ofType: "bundle"),
              let bundle = Bundle.init(path: bundlePath) else {
            return named
        }
        return NSLocalizedString(named, tableName: nil, bundle: bundle, value: "", comment: comment)
    }
    
    /// Read color resource
    @available(iOS 11.0, *, macOS 10.13, *)
    public static func color(_ named: String, forResource: String = "Harbeth") -> C7Color? {
        guard let bundlePath = Bundle.main.path(forResource: forResource, ofType: "bundle") else {
            return C7Color.init(named: named)
        }
        let bundle = Bundle.init(path: bundlePath)
        #if os(iOS) || os(tvOS) || os(watchOS)
        return C7Color.init(named: named, in: bundle, compatibleWith: nil)
        #elseif os(macOS)
        return C7Color.init(named: named, bundle: bundle)
        #else
        return nil
        #endif
    }
}
