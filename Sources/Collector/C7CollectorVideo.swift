//
//  C7CollectorVideo.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import AVFoundation

public final class C7CollectorVideo: C7Collector {
    
    private var player: AVPlayer!
    public private(set) var videoOutput: AVPlayerItemVideoOutput!
    
    #if os(iOS) || os(tvOS) || os(watchOS)
    lazy var displayLink: CADisplayLink = {
        let displayLink = CADisplayLink(target: self, selector: #selector(readBuffer(_:)))
        displayLink.add(to: .current, forMode: RunLoop.Mode.default)
        displayLink.isPaused = true
        return displayLink
    }()
    #endif
    
    public convenience init(player: AVPlayer, callback: @escaping C7FilterImageCallback) {
        self.init(callback: callback)
        self.player = player
        setupPlayer(player)
    }
    
    public convenience init(player: AVPlayer, view: C7View) {
        self.init(view: view)
        self.player = player
        setupPlayer(player)
    }
    
    public convenience init(player: AVPlayer, delegate: C7CollectorImageDelegate) {
        self.init(delegate: delegate)
        self.player = player
        setupPlayer(player)
    }
    
    public override func setupInit() {
        super.setupInit()
        setupVideoOutput()
    }
}

extension C7CollectorVideo {
    
    public func play() {
        player.play()
        #if os(iOS) || os(tvOS) || os(watchOS)
        displayLink.isPaused = false
        #endif
    }
    
    public func pause() {
        player.pause()
        #if os(iOS) || os(tvOS) || os(watchOS)
        displayLink.isPaused = true
        #endif
    }
}

extension C7CollectorVideo {
    
    func setupPlayer(_ player: AVPlayer) {
        if let currentItem = player.currentItem {
            currentItem.add(videoOutput)
        }
    }
    
    func setupVideoOutput() {
        videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: videoSettings)
    }
    
    #if os(iOS) || os(tvOS) || os(watchOS)
    @objc func readBuffer(_ sender: CADisplayLink) {
        let time = videoOutput.itemTime(forHostTime: sender.timestamp + sender.duration)
        guard videoOutput.hasNewPixelBuffer(forItemTime: time) else {
            return
        }
        let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil)
        self.processing(with: pixelBuffer)
    }
    #endif
}
