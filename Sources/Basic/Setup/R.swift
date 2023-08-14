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

extension R {
    
    /// 强度范围
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    public static let iRange: ParameterRange<Float, Any> = .init(min: 0.0, max: 1.0, value: 1.0)
    
    /// Screen window width.
    public static var width: CGFloat {
        #if canImport(UIKit)
        return UIScreen.main.bounds.width
        #elseif os(macOS)
        return NSScreen.main?.visibleFrame.width ?? 0.0
        #else
        return 0.0
        #endif
    }
    
    /// Screen window height.
    public static var height: CGFloat {
        #if canImport(UIKit)
        return UIScreen.main.bounds.height
        #elseif os(macOS)
        return NSScreen.main?.visibleFrame.height ?? 0.0
        #else
        return 0.0
        #endif
    }
}
