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
            // Fixed rgba => bgra when no filter is introduced.
            guard let cgimage = pixelBuffer.mt.toCGImage() else { return nil }
            if let function = delegate?.captureOutput(_:texture:),
               let texture = pixelBuffer.mt.convert2MTLTexture(textureCache: textureCache) {
                function(self, texture)
            }
            return cgimage.mt.toC7Image()
        }
        let image = filteringAndConvert2Image(with: pixelBuffer)
        return image
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

extension C7Collector {
    /// Inject filter and convert to image
    private func filteringAndConvert2Image(with pixelBuffer: CVPixelBuffer) -> C7Image? {
        guard var texture = pixelBuffer.mt.convert2MTLTexture(textureCache: textureCache) else {
            return nil
        }
        delegate?.captureOutput?(self, texture: texture)
        filters.forEach {
            do {
                let size = $0.resize(input: C7Size(width: texture.width, height: texture.height))
                let destTexture = Processed.destTexture(width: size.width, height: size.height)
                texture = try Processed.IO(inTexture: texture, outTexture: destTexture, filter: $0)
            } catch { }
        }
        return texture.toImage()
    }
}
