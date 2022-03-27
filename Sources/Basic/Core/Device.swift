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
        self.ATMetalLibrary = device.makeATLibrary(forResource: "Harbeth")
        
        if defaultLibrary == nil && ATMetalLibrary == nil {
            C7FailedErrorInDebug("Could not load library")
        }
    }
    
    deinit {
        print("Device is deinit.")
    }
}

extension MTLDevice {
    
    fileprivate func makeATLibrary(forResource: String) -> MTLLibrary? {
        /// Compatible with the Bundle address used by CocoaPods to import framework
        let bundle = getFrameworkBundle(bundleName: forResource)
        guard let path = bundle.path(forResource: "default", ofType: "metallib") else {
            return nil
        }
        return try? makeLibrary(filepath: path)
    }
    
    fileprivate func getFrameworkBundle(bundleName: String) -> Bundle {
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
                print(candidate)
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
    
    static func commandQueue() -> MTLCommandQueue {
        return Shared.shared.device!.commandQueue
    }
    
    static func readMTLFunction(_ name: String) throws -> MTLFunction {
        // First read the project
        if let libray = Shared.shared.device!.defaultLibrary, let function = libray.makeFunction(name: name) {
            return function
        }
        // Then read from CocoaPods
        if let libray = Shared.shared.device!.ATMetalLibrary, let function = libray.makeFunction(name: name) {
            return function
        }
        #if DEBUG
        fatalError(C7CustomError.readFunction(name).localizedDescription)
        #else
        throw C7CustomError.readFunction(name)
        #endif
    }
}
