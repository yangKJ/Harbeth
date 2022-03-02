//
//  C7Collector.swift
//  Harbeth
//
//  Created by Condy on 2022/2/13.
//

@_exported import AVFoundation
import Foundation
import CoreVideo
import MetalKit

public protocol C7CollectorProtocol {
    
    /// Multiple filter combinations.
    var filters: [C7FilterProtocol] { get set }
    
    /// Initialization method
    /// This mode directly generates images for external use.
    ///
    /// - Parameter callback: Collect generated filter image callback. You can display it directly using ImageView.
    init(callback: @escaping C7FilterImageCallback)
    
    /// Initialization method, TODO:
    /// This mode internally generates MTKView for rendering.
    ///
    /// - Parameter view: Host the render control view.
    init(view: UIView)
}

open class C7Collector: NSObject, C7CollectorProtocol {
    
    var haveMTKView: Bool = false
    var callback: C7FilterImageCallback!
    var view: UIView!
    private var textureCache: CVMetalTextureCache?
    
    public var filters: [C7FilterProtocol] = []
    
    public required init(callback: @escaping C7FilterImageCallback) {
        self.callback = callback
        #if !targetEnvironment(simulator)
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, Device.device(), nil, &textureCache)
        #endif
    }
    
    public required init(view: UIView) {
        self.haveMTKView = true
        self.view = view
    }
}

extension C7Collector {
    
    func pixelBuffer2Image(_ pixelBuffer: CVPixelBuffer?) -> C7Image? {
        guard let pixelBuffer = pixelBuffer else { return nil }
        let image = pixelBuffer.mt.convert2C7Image(textureCache: textureCache, filters: filters)
        #if !targetEnvironment(simulator)
        if let textureCache = textureCache {
            CVMetalTextureCacheFlush(textureCache, 0);
        }
        #endif
        return image
    }
}
