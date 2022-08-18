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

public class C7Collector: NSObject, C7CollectorProtocol {
    
    public var filters: [C7FilterProtocol] = []
    
    var haveMTKView: Bool = false
    var callback: C7FilterImageCallback?
    var view: C7View?
    weak var delegate: C7CollectorImageDelegate?
    private var textureCache: CVMetalTextureCache?
    
    public required init(delegate: C7CollectorImageDelegate) {
        self.delegate = delegate
        super.init()
        setupInit()
    }
    
    public required init(callback: @escaping C7FilterImageCallback) {
        self.callback = callback
        super.init()
        setupInit()
    }
    
    public required init(view: C7View) {
        self.haveMTKView = true
        self.view = view
        super.init()
        setupInit()
    }
    
    deinit {
        delegate = nil
        print("C7Collector is deinit.")
    }
    
    open func setupInit() {
        setupTextureCache()
    }
}

extension C7Collector {
    
    private func setupTextureCache() {
        #if !targetEnvironment(simulator)
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, Device.device(), nil, &textureCache)
        #endif
    }
    
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
    
    func generateFilterImage(with pixelBuffer: CVPixelBuffer?) {
        guard let image = self.pixelBuffer2Image(pixelBuffer) else {
            return
        }
        if let callback = self.callback {
            DispatchQueue.main.async { callback(image) }
        }
        if let delegate = self.delegate {
            delegate.preview(self, fliter: image)
        }
    }
}
