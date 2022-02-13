//
//  RenderingDevice.swift
//  MetalQueen
//
//  Created by Condy on 2021/8/8.
//

import Foundation
import MetalKit
import CoreGraphics

public class RenderingDevice {
    
    /// 设备信息，创建其他对象
    /// MTLDevice 的创建很昂贵、耗时，并且它可以一直使用，所以只需要创建一次即可
    public let device: MTLDevice
    /// 单一命令队列
    public let commandQueue: MTLCommandQueue
    /// 默认提供的函数库，项目中所有 `.metal` 文件
    public let defaultLibrary: MTLLibrary?
    ///`ATMetalBand`库当中的所有 `.metal` 文件
    public let ATMetalLibrary: MTLLibrary?
    /// 加载纹理工具
    public let textureLoader: MTKTextureLoader
    public let colorSpace: CGColorSpace
    
    public static let shared = RenderingDevice()
    
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
        // 兼容CocoaPods导入framework方式的Bundle地址
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
        // 先读取项目当中的`.metal`
        if let libray = RenderingDevice.shared.defaultLibrary, let function = libray.makeFunction(name: name) {
            return function
        }
        // 再读取CocoaPods当中
        if let libray = RenderingDevice.shared.ATMetalLibrary, let function = libray.makeFunction(name: name) {
            return function
        }
        
        fatalError("Read MTL Function failed with \(name)")
    }
}
