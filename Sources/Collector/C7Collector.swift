//
//  C7Collector.swift
//  Harbeth
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import CoreVideo

public class C7Collector: NSObject, Collectorable, Cacheable {
    
    public var filters: [C7FilterProtocol] = []
    public var videoSettings: [String : Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    /// Whether to enable automatic direction correction of pictures? The default is true.
    public var autoCorrectDirection: Bool = true
    
    var haveMTKView: Bool = false
    var callback: C7FilterImageCallback?
    var view: C7View?
    weak var delegate: C7CollectorImageDelegate?
    
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
        deferTextureCache()
        print("C7Collector is deinit.")
    }
    
    open func setupInit() {
        let _ = self.textureCache
    }
}

extension C7Collector {
    
    func pixelBuffer2Image(_ pixelBuffer: CVPixelBuffer?) -> C7Image? {
        guard let pixelBuffer = pixelBuffer else { return nil }
        delegate?.captureOutput?(self, pixelBuffer: pixelBuffer)
        if filters.isEmpty {
            if let function = delegate?.captureOutput(_:texture:),
               let texture = pixelBuffer.mt.toMTLTexture(textureCache: textureCache) {
                function(self, texture)
            }
            // Fixed rgba => bgra when no filter.
            return pixelBuffer.mt.toCGImage()?.mt.toC7Image()
        }
        
        // CVPixelBuffer add filter and convert to image.
        guard let texture = BufferIO.convert2MTLTexture(pixelBuffer: pixelBuffer, filters: filters, textureCache: textureCache) else {
            return nil
        }
        delegate?.captureOutput?(self, texture: texture)
        return texture.toImage()
    }
    
    func processing(with pixelBuffer: CVPixelBuffer?) {
        guard var image = self.pixelBuffer2Image(pixelBuffer) else {
            return
        }
        if autoCorrectDirection {
            image = image.mt.fixOrientation()
        }
        if let callback = self.callback {
            DispatchQueue.main.async { callback(image) }
        }
        if let delegate = self.delegate {
            DispatchQueue.main.async { delegate.preview(self, fliter: image) }
        }
    }
}
