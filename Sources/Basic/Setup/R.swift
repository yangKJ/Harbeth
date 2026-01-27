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
    
    /// Returns the host app's bundle (safe for app extensions).
    public static let app: Bundle = {
        #if os(iOS) || os(tvOS) || os(watchOS)
        if Bundle.main.bundleURL.pathExtension == "appex" {
            // Running inside an app extension
            let container = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
            return Bundle(url: container) ?? Bundle.main
        }
        #endif
        return Bundle.main
    }()
    
    public static var cacheBundles = [String: Bundle]()
    
    /// Read image resources
    public static func image(_ named: String, forResource: String = "Harbeth") -> C7Image? {
        let readImageblock = { (bundle: Bundle) -> C7Image? in
            #if os(iOS) || os(tvOS) || os(watchOS)
            return C7Image(named: named, in: bundle, compatibleWith: nil)
            #elseif os(macOS)
            return bundle.image(forResource: named)
            #else
            return nil
            #endif
        }
        if let image = readImageblock(Bundle.main) {
            return image
        }
        guard let bundle = readFrameworkBundle(with: forResource) else {
            return C7Image.init(named: named)
        }
        return readImageblock(bundle)
    }
    
    /// Read color resource
    @available(iOS 11.0, macOS 10.13, *)
    public static func color(_ named: String, forResource: String = "Harbeth") -> C7Color? {
        let readColorblock = { (bundle: Bundle) -> C7Color? in
            #if os(iOS) || os(tvOS) || os(watchOS)
            return C7Color.init(named: named, in: bundle, compatibleWith: nil)
            #elseif os(macOS)
            return C7Color.init(named: named, bundle: bundle)
            #else
            return nil
            #endif
        }
        if let color = readColorblock(Bundle.main) {
            return color
        }
        guard let bundle = readFrameworkBundle(with: forResource) else {
            return C7Color.init(named: named)
        }
        return readColorblock(bundle)
    }
    
    public static func readFrameworkBundle(with bundleName: String) -> Bundle? {
        if let bundle = cacheBundles[bundleName] {
            return bundle
        }
        let bundle__ = Bundle(for: R__.self)
        let candidates = [
            // Bundle should be present here when the package is linked into an App.
            Bundle.main.resourceURL,
            // Current app's bundle whether it's called from the app or an app extension.
            R.app.resourceURL,
            // Bundle should be present here when the package is linked into a framework.
            bundle__.resourceURL,
            // For command-line tools.
            Bundle.main.bundleURL,
        ]
        for candidate in candidates {
            let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
            if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
                cacheBundles[bundleName] = bundle
                return bundle
            }
        }
        cacheBundles[bundleName] = bundle__
        return bundle__
    }
}

private final class R__ { }

extension R {
    /// Standard intensity range [0.0, 1.0]
    public static let iRange: ParameterRange<Float, Any> = .init(min: 0.0, max: 1.0, value: 1.0)
    /// 强度范围
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    public static let intensityRange = iRange
    
    /// Screen width (main screen)
    public static var width: CGFloat {
        #if os(iOS) || os(tvOS)
        return UIScreen.main.bounds.width
        #elseif os(watchOS)
        return WKInterfaceDevice.current().screenBounds.width
        #elseif os(macOS)
        return NSScreen.main?.frame.width ?? 0
        #else
        return 0
        #endif
    }
    
    /// Screen height (main screen)
    public static var height: CGFloat {
        #if os(iOS) || os(tvOS)
        return UIScreen.main.bounds.height
        #elseif os(watchOS)
        return WKInterfaceDevice.current().screenBounds.height
        #elseif os(macOS)
        return NSScreen.main?.frame.height ?? 0
        #else
        return 0
        #endif
    }
}
