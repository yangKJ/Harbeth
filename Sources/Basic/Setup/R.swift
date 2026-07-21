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

private final class ResourceBundleCache: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Bundle] = [:]

    func bundle(named name: String) -> Bundle? {
        lock.lock()
        defer { lock.unlock() }
        return storage[name]
    }

    func store(_ bundle: Bundle, named name: String) {
        lock.lock()
        storage[name] = bundle
        lock.unlock()
    }

    func snapshot() -> [String: Bundle] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func replace(with bundles: [String: Bundle]) {
        lock.lock()
        storage = bundles
        lock.unlock()
    }
}

/// 资源文件读取
public struct R {

    /// Returns the host app's bundle (safe for app extensions).
    public static let app: Bundle = {
        #if os(iOS) || os(tvOS)
        if Bundle.main.bundleURL.pathExtension == "appex" {
            // Running inside an app extension
            let container = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
            return Bundle(url: container) ?? Bundle.main
        }
        #endif
        return Bundle.main
    }()
    private static let bundleCache = ResourceBundleCache()

    public static var cacheBundles: [String: Bundle] {
        get { bundleCache.snapshot() }
        set { bundleCache.replace(with: newValue) }
    }

    /// Read image resources
    public static func image(_ named: String, forResource: String = "Harbeth") -> C7Image? {
        let readImageblock = { (bundle: Bundle) -> C7Image? in
            #if os(iOS) || os(tvOS)
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
            #if os(iOS) || os(tvOS)
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
        if let bundle = bundleCache.bundle(named: bundleName) {
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
                bundleCache.store(bundle, named: bundleName)
                return bundle
            }
        }
        bundleCache.store(bundle__, named: bundleName)
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
}
