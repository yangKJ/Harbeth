//
//  Device.swift
//  MetalQueen
//
//  Created by Condy on 2021/8/8.
//

import Foundation
import MetalKit

internal final class Device {
    
    /// Device information to create other objects
    /// MTLDevice creation is expensive, time-consuming, and can be used forever, so you only need to create it once
    let device: MTLDevice
    /// Single command queue
    let commandQueue: MTLCommandQueue
    /// Metal file in your local project
    let defaultLibrary: MTLLibrary?
    /// Metal file in ATMetalBand
    let ATMetalLibrary: MTLLibrary?
    /// Cache pipe state
    lazy var pipelines = [C7KernelFunction: MTLComputePipelineState]()
    /// Load the texture tool
    lazy var textureLoader: MTKTextureLoader = MTKTextureLoader(device: device)
    /// Transform using color space
    lazy var colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
    
    lazy var context: CIContext = {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let options = [CIContextOption.workingColorSpace: colorSpace]
        let context: CIContext
        if #available(iOS 13.0, *) {
            context = CIContext(mtlCommandQueue: Device.commandQueue(), options: options)
        } else {
            context = CIContext(options: options)
        }
        return context
    }()
    
    init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Could not create Metal Device")
        }
        self.device = device
        
        guard let queue = device.makeCommandQueue() else {
            fatalError("Could not create command queue")
        }
        self.commandQueue = queue
        
        if #available(OSX 10.12, *) {
            self.defaultLibrary = try? device.makeDefaultLibrary(bundle: Bundle.main)
        } else {
            self.defaultLibrary = device.makeDefaultLibrary()
        }
        self.ATMetalLibrary = Device.makeATLibrary(device, for: "Harbeth")
        
        if defaultLibrary == nil && ATMetalLibrary == nil {
            C7FailedErrorInDebug("Could not load library")
        }
    }
    
    deinit {
        print("Device is deinit.")
    }
}

extension Device {
    
    static func makeATLibrary(_ device: MTLDevice, for resource: String) -> MTLLibrary? {
        /// Compatible with the Bundle address used by CocoaPods to import framework
        let bundle = getFrameworkBundle(bundleName: resource)
        guard let path = bundle.path(forResource: "default", ofType: "metallib") else {
            return nil
        }
        return try? device.makeLibrary(filepath: path)
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
    
    static func colorSpace(_ cgimage: CGImage? = nil) -> CGColorSpace {
        return cgimage?.colorSpace ?? (Shared.shared.device?.colorSpace ?? CGColorSpaceCreateDeviceRGB())
    }
    
    static func bitmapInfo(_ cgimage: CGImage? = nil) -> UInt32 {
        if let c = cgimage?.bitmapInfo.rawValue {
            return c
        }
        //kCGImageAlphaPremultipliedLast保留透明度
        return CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
    }
    
    static func commandQueue() -> MTLCommandQueue {
        return Shared.shared.device!.commandQueue
    }
    
    static func context() -> CIContext {
        return Shared.shared.device!.context
    }
    
    static func readMTLFunction(_ name: String) throws -> MTLFunction {
        // First read the project
        if let libray = Shared.shared.device?.defaultLibrary, let function = libray.makeFunction(name: name) {
            return function
        }
        // Then read from CocoaPods
        if let libray = Shared.shared.device?.ATMetalLibrary, let function = libray.makeFunction(name: name) {
            return function
        }
        #if DEBUG
        fatalError(C7CustomError.readFunction(name).localizedDescription)
        #else
        throw C7CustomError.readFunction(name)
        #endif
    }
}
