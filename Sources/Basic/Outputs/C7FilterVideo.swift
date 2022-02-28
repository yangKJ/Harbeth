//
//  C7FilterVideo.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import AVFoundation

public final class C7FilterVideo {
    
    public var groupFilters: [C7FilterProtocol]
    
    private let callback: C7FilterImageCallback
    private let player: AVPlayer
    private var textureCache: CVMetalTextureCache?
    
    lazy var playerItemVideoOutput: AVPlayerItemVideoOutput = {
        let attributes = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        return AVPlayerItemVideoOutput(pixelBufferAttributes: attributes)
    }()
    
    lazy var displayLink: CADisplayLink = {
        let displayLink = CADisplayLink(target: self, selector: #selector(readBuffer(_:)))
        displayLink.add(to: .current, forMode: RunLoop.Mode.default)
        displayLink.isPaused = true
        return displayLink
    }()
    
    public init(player: AVPlayer, callback: @escaping C7FilterImageCallback) {
        self.player = player
        self.callback = callback
        self.groupFilters = []
        if let currentItem = player.currentItem {
            currentItem.add(playerItemVideoOutput)
        }
        #if !targetEnvironment(simulator)
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, Device.device(), nil, &textureCache)
        #endif
    }
    
    @objc func readBuffer(_ sender: CADisplayLink) {
        var currentTime = CMTime.invalid
        currentTime = playerItemVideoOutput.itemTime(forHostTime: sender.timestamp + sender.duration)
        guard playerItemVideoOutput.hasNewPixelBuffer(forItemTime: currentTime),
              let pixelBuffer = playerItemVideoOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) else {
                  return
              }
        if let image = pixelBuffer.mt.convert2C7Image(textureCache: textureCache, filters: groupFilters) {
            DispatchQueue.main.sync { callback(image) }
        }
    }
}

extension C7FilterVideo {
    
    public func play() {
        player.play()
        displayLink.isPaused = false
    }
    
    public func pause() {
        player.pause()
        displayLink.isPaused = true
    }
}
