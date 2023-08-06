//
//  Device.swift
//  Harbeth
//
//  Created by Condy on 2021/8/8.
//

import Foundation
import MetalKit

internal final class Device: Cacheable {
    
    /// Device information to create other objects
    /// MTLDevice creation is expensive, time-consuming, and can be used forever, so you only need to create it once
    let device: MTLDevice
    /// Single command queue
    let commandQueue: MTLCommandQueue
    /// Metal file in your local project
    let defaultLibrary: MTLLibrary?
    /// Metal file in ``Harbeth Framework``
    let harbethLibrary: MTLLibrary?
    /// Cache pipe state
    lazy var pipelines = [C7KernelFunction: MTLComputePipelineState]()
    /// Load the texture tool
    lazy var textureLoader: MTKTextureLoader = MTKTextureLoader(device: device)
    /// Transform using color space
    lazy var colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
    
    lazy var context: CIContext = Device.context(colorSpace: CGColorSpaceCreateDeviceRGB())
    
    init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Could not create Metal Device")
        }
        self.device = device
        
        guard let queue = device.makeCommandQueue() else {
            fatalError("Could not create command queue")
        }
        self.commandQueue = queue
        
        if #available(iOS 10.0, macOS 10.12, *) {
            self.defaultLibrary = try? device.makeDefaultLibrary(bundle: Bundle.main)
        } else {
            self.defaultLibrary = device.makeDefaultLibrary()
        }
        self.harbethLibrary = Device.makeFrameworkLibrary(device, for: "Harbeth")
        
        if defaultLibrary == nil && harbethLibrary == nil {
            C7FailedErrorInDebug("Could not load library")
        }
    }
    
    deinit {
        print("Device is deinit.")
    }
}

extension Device {
    
    static func makeFrameworkLibrary(_ device: MTLDevice, for resource: String) -> MTLLibrary? {
        #if SWIFT_PACKAGE
        /// Fixed the Swift PM cannot read the `.metal` file.
        /// https://stackoverflow.com/questions/63237395/generating-resource-bundle-accessor-type-bundle-has-no-member-module
        if let pathURL = Bundle.module.url(forResource: "default", withExtension: "metallib") {
            var path: String
            if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                path = pathURL.path()
            } else {
                path = pathURL.path
            }
            if let library = try? device.makeLibrary(filepath: path) {
                return library
            }
        }
        #endif
        /// Compatible with the Bundle address used by CocoaPods to import framework
        let bundle = getFrameworkBundle(bundleName: resource)
        if let path = bundle.path(forResource: "default", ofType: "metallib") {
            if let library = try? device.makeLibrary(filepath: path) {
                return library
            }
        }
        return nil
    }
    
    static func getFrameworkBundle(bundleName: String) -> Bundle {
        let candidates = [
            // Bundle should be present here when the package is linked into an App.
            Bundle.main.resourceURL,
            // Bundle should be present here when the package is linked into a framework.
            Bundle(for: Device.self).resourceURL,
            // For command-line tools.
            Bundle.main.bundleURL,
        ]
        for candidate in candidates {
            let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
            if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
                return bundle
            }
        }
        // Return whatever bundle this code is in as a last resort.
        return Bundle(for: Device.self)
    }
}

extension Device {
    
    static func device() -> MTLDevice {
        return Shared.shared.device!.device
    }
    
    static func colorSpace() -> CGColorSpace {
        // Unitive the color space, otherwise it will crash.
        return Shared.shared.device?.colorSpace ?? CGColorSpaceCreateDeviceRGB()
    }
    
    static func bitmapInfo() -> UInt32 {
        // You can't get `CGImage.bitmapInfo` here, otherwise the heic and heif formats will turn blue.
        // Fixed draw bitmap after applying filter image color rgba => bgra.
        // See：https://github.com/yangKJ/Harbeth/issues/12
        return CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
    }
    
    static func commandQueue() -> MTLCommandQueue {
        return Shared.shared.device!.commandQueue
    }
    
    static func readMTLFunction(_ name: String) throws -> MTLFunction {
        // First read the project
        if let libray = Shared.shared.device?.defaultLibrary, let function = libray.makeFunction(name: name) {
            return function
        }
        // Then read from ``Harbeth Framework``
        if let libray = Shared.shared.device?.harbethLibrary, let function = libray.makeFunction(name: name) {
            return function
        }
        #if DEBUG
        fatalError(CustomError.readFunction(name).localizedDescription)
        #else
        throw CustomError.readFunction(name)
        #endif
    }
}

extension Device {
    
    static func sharedTextureCache() -> CVMetalTextureCache? {
        return Shared.shared.device?.textureCache
    }
    
    static func context() -> CIContext {
        return Shared.shared.device!.context
    }
    
    static func context(cgImage: CGImage) -> CIContext {
        let options = [CIContextOption.workingColorSpace: cgImage.colorSpace]
        return Self.context(options: options as [CIContextOption : Any])
    }
    
    static func context(colorSpace: CGColorSpace) -> CIContext {
        let options = [CIContextOption.workingColorSpace: colorSpace]
        return Self.context(options: options)
    }
    
    static func context(options: [CIContextOption : Any]) -> CIContext {
        if #available(iOS 13.0, *, macOS 10.15, *) {
            return CIContext(mtlCommandQueue: Device.commandQueue(), options: options)
        } else {
            return CIContext(options: options)
        }
    }
}
