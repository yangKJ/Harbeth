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

public class C7Collector: NSObject, Collectorable {
    
    public var filters: [C7FilterProtocol] = []
    public var videoSettings: [String : Any] = [
        kCVPixelBufferMetalCompatibilityKey as String: true,
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    /// Whether to enable automatic direction correction of pictures? The default is true.
    public var autoCorrectDirection: Bool = true
    
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
        flushTextureCache()
        print("C7Collector is deinit.")
    }
    
    open func setupInit() {
        setupTextureCache()
    }
}

extension C7Collector {
    
    func pixelBuffer2Image(_ pixelBuffer: CVPixelBuffer?) -> C7Image? {
        guard let pixelBuffer = pixelBuffer else { return nil }
        if filters.isEmpty {
            // Fixed rgba => bgra when no filter is introduced.
            guard let cgimage = pixelBuffer.mt.convert2cgImage() else { return nil }
            return C7Image.init(cgImage: cgimage)
        }
        
        let image = filteringAndConvert2Image(with: pixelBuffer)
        
        flushTextureCache()
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
            delegate.preview(self, fliter: image)
        }
    }
}

extension C7Collector {
    
    private func setupTextureCache() {
        #if !targetEnvironment(simulator)
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, Device.device(), nil, &textureCache)
        #endif
    }
    
    private func flushTextureCache() {
        #if !targetEnvironment(simulator)
        if let textureCache = textureCache {
            CVMetalTextureCacheFlush(textureCache, 0)
        }
        #endif
    }
    
    /// Inject filter and convert to image
    private func filteringAndConvert2Image(with pixelBuffer: CVPixelBuffer) -> C7Image? {
        guard var texture = pixelBuffer.mt.convert2MTLTexture(textureCache: textureCache) else {
            return nil
        }
        // 运算符组合滤镜效果，生成纹理
        filters.forEach { texture = texture ->> $0 }
        return texture.toImage()
    }
}
