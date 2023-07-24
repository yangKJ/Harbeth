//
//  Compositor.swift
//  Harbeth
//
//  Created by Condy on 2023/2/20.
//

import Foundation
import AVFoundation
import CoreVideo

/// See: https://www.jianshu.com/p/157acfa8d355

/// This protocol can take over the rendering of video images.
class Compositor: NSObject, AVVideoCompositing {
    
    let renderQueue = DispatchQueue(label: "com.condy.harbeth.exporter.rendering.queue")
    let renderContextQueue = DispatchQueue(label: "com.condy.harbeth.exporter.rendercontext.queue")
    
    var renderContext: AVVideoCompositionRenderContext!
    
    var requiredPixelBufferAttributesForRenderContext: [String : Any] = [
        kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32BGRA,
    ]
    
    var sourcePixelBufferAttributes: [String : Any]? = [
        kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32BGRA,
    ]
    
    /// When processing video at a certain point in time.
    /// A request will be sent to `AVVideoCompositing` to obtain video frames, time information, canvas size, etc. for processing.
    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        self.renderQueue.sync {
            guard let instruction = request.videoCompositionInstruction as? Exporter.CompositionInstruction,
                  let pixels = request.sourceFrame(byTrackID: instruction.trackID) else {
                return
            }
            let buffer = instruction.bufferCallback(pixels)
            request.finish(withComposedVideoFrame: buffer)
        }
    }
    
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        self.renderContextQueue.sync {
            self.renderContext = newRenderContext
        }
    }
}
