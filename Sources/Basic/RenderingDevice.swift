//
//  RenderingDevice.swift
//  MetalQueen
//
//  Created by Condy on 2021/8/8.
//

import Foundation
import MetalKit
import CoreGraphics

class RenderingDevice {
    
    /// Device information to create other objects
    /// MTLDevice creation is expensive, time-consuming, and can be used forever, so you only need to create it once
    let device: MTLDevice
    /// Single command queue
    let commandQueue: MTLCommandQueue
    /// Metal file in your local project
    let defaultLibrary: MTLLibrary?
    /// Metal file in ATMetalBand
    let ATMetalLibrary: MTLLibrary?
    /// Load the texture tool
    let textureLoader: MTKTextureLoader
    let colorSpace: CGColorSpace
    
    static let shared = RenderingDevice()
    
    private init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Could not create Metal Device")
        }
        self.device = device
        
        guard let queue = device.makeCommandQueue() else {
            fatalError("Could not create command queue")
        }
        self.commandQueue = queue
        
        self.defaultLibrary = device.makeDefaultLibrary()
        self.ATMetalLibrary = device.makeATLibrary(forResource: "ATMetalLibrary")
        
        if defaultLibrary == nil && ATMetalLibrary == nil {
            fatalError("Could not load library")
        }
        
        self.textureLoader = MTKTextureLoader(device: device)
        
        self.colorSpace = CGColorSpaceCreateDeviceRGB()
    }
}

extension MTLDevice {
    
    func makeATLibrary(forResource: String) -> MTLLibrary? {
        /// Compatible with the Bundle address used by CocoaPods to import framework
        guard let bundleURL = Bundle.main.url(forResource: forResource, withExtension: "bundle"),
              let bundle = Bundle(url: bundleURL) else {
                  return nil
              }
        guard let path = bundle.path(forResource: "default", ofType: "metallib") else {
            return nil
        }
        return try? makeLibrary(filepath: path)
    }
}

extension RenderingDevice {
    
    static func readMTLFunction(_ name: String) -> MTLFunction {
        // Read the project first
        if let libray = RenderingDevice.shared.defaultLibrary, let function = libray.makeFunction(name: name) {
            return function
        }
        // Then read from CocoaPods
        if let libray = RenderingDevice.shared.ATMetalLibrary, let function = libray.makeFunction(name: name) {
            return function
        }
        
        fatalError("Read MTL Function failed with \(name)")
    }
}
