//
//  Collectorable.swift
//  Harbeth
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import MetalKit

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

public protocol Collectorable {
    
    /// Multiple filter combinations.
    var filters: [C7FilterProtocol] { get set }
    
    /// Initialization method
    /// - Parameter delegate: Protocol to generate filter images.
    init(delegate: C7CollectorImageDelegate)
    
    /// Initialization method
    /// This mode directly generates images for external use.
    ///
    /// - Parameter callback: Collect generated filter image callback. You can display it directly using ImageView.
    init(callback: @escaping C7FilterImageCallback)
    
    /// Initialization method, TODO:
    /// This mode internally generates MTKView for rendering.
    ///
    /// - Parameter view: Host the render control view.
    init(view: C7View)
}
