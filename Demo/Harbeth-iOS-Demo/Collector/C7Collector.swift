//
//  C7Collector.swift
//  Harbeth
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import CoreVideo
import Harbeth

@objc public protocol C7CollectorImageDelegate: NSObjectProtocol {
    
    /// The filter image is returned in the child thread.
    ///
    /// - Parameters:
    ///   - collector: collector
    ///   - image: fliter image
    func preview(_ collector: C7Collector, fliter image: C7Image)
    
    /// Capture other relevant information. The child thread returns the result.
    /// - Parameters:
    ///   - collector: Collector
    ///   - pixelBuffer: A CVPixelBuffer object containing the video frame data and additional information about the frame, such as its format and presentation time.
    @objc optional func captureOutput(_ collector: C7Collector, pixelBuffer: CVPixelBuffer)
    
    /// Capture CVPixelBuffer converted to MTLTexture.
    /// - Parameters:
    ///   - collector: Collector
    ///   - texture: CVPixelBuffer => MTLTexture
    @objc optional func captureOutput(_ collector: C7Collector, texture: MTLTexture)
}

public class C7Collector: NSObject, Cacheable {
    
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
        guard let pixelBuffer = pixelBuffer else {
            return nil
        }
        delegate?.captureOutput?(self, pixelBuffer: pixelBuffer)
        let texture = pixelBuffer.mt.toMTLTexture(textureCache: textureCache)
        let dest = BoxxIO(element: texture, filters: filters)
        guard let texture = try? dest.output() else {
            return nil
        }
        delegate?.captureOutput?(self, texture: texture)
        return texture.mt.toImage()
    }
    
    func processing(with pixelBuffer: CVPixelBuffer?) {
        guard let pixelBuffer = pixelBuffer else {
            return
        }
        delegate?.captureOutput?(self, pixelBuffer: pixelBuffer)
        guard let texture = pixelBuffer.mt.toMTLTexture(textureCache: textureCache) else {
            return
        }
        let dest = BoxxIO(element: texture, filters: filters)
        dest.transmitOutput(success: { [weak self] desTexture in
            guard let `self` = self else {
                return
            }
            self.delegate?.captureOutput?(self, texture: desTexture)
            guard var image = desTexture.mt.toImage() else {
                return
            }
            if self.autoCorrectDirection {
                image = image.mt.fixOrientation()
            }
            DispatchQueue.main.async {
                self.callback?(image)
                self.delegate?.preview(self, fliter: image)
            }
        })
    }
}
