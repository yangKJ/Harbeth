//
//  CADisplayLink.swift
//  Harbeth
//
//  Created by Condy on 2023/1/6.
//

#if os(macOS)

import Foundation
import AppKit
import CoreVideo

public final class CADisplayLink: NSObject {
    private let impl: DisplayLinkImpl
    
    /// Creates a display link with the target and selector.
    public init(target: Any, selector: Selector) {
        self.impl = DisplayLinkImpl(target: target, selector: selector)
        super.init()
    }
    
    public override init() {
        fatalError("Use init(target:selector:)")
    }
    
    /// The duration between frames (in seconds).
    public var duration: CFTimeInterval {
        impl.duration
    }
    
    /// The timestamp of the last frame.
    public var timestamp: CFTimeInterval {
        impl.timestamp
    }
    
    /// Number of frames to skip between callbacks (default: 1).
    /// Note: This implementation ignores frameInterval for simplicity.
    public var frameInterval: Int {
        get { impl.frameInterval }
        set { impl.frameInterval = newValue }
    }
    
    /// Pauses or resumes the display link.
    public var isPaused: Bool {
        get { impl.isPaused }
        set { impl.isPaused = newValue }
    }
    
    /// Adds the display link to a run loop.
    public func add(to runloop: RunLoop, forMode mode: RunLoop.Mode) {
        impl.add(to: runloop, forMode: mode)
    }
    
    /// Removes the display link from a run loop.
    public func remove(from runloop: RunLoop, forMode mode: RunLoop.Mode) {
        impl.remove(from: runloop, forMode: mode)
    }
    
    /// Invalidates the display link.
    public func invalidate() {
        impl.invalidate()
    }
}

private final class DisplayLinkImpl: NSObject {
    private let target: Any
    private let selector: Selector
    private var cvLink: CVDisplayLink?
    private var source: DispatchSourceUserDataAdd?
    private var timeRef = CVTimeStamp()
    private var registeredRunLoops: [RunLoop: Set<RunLoop.Mode>] = [:]
    
    var duration: CFTimeInterval {
        guard let link = cvLink else { return 1.0 / 60.0 }
        CVDisplayLinkGetCurrentTime(link, &timeRef)
        if timeRef.videoTimeScale > 0, timeRef.videoRefreshPeriod > 0 {
            return CFTimeInterval(timeRef.videoRefreshPeriod) / CFTimeInterval(timeRef.videoTimeScale)
        }
        return 1.0 / 60.0
    }
    
    var timestamp: CFTimeInterval {
        guard let link = cvLink else { return CACurrentMediaTime() }
        CVDisplayLinkGetCurrentTime(link, &timeRef)
        if timeRef.videoTimeScale > 0 {
            return CFTimeInterval(timeRef.videoTime) / CFTimeInterval(timeRef.videoTimeScale)
        }
        return CACurrentMediaTime()
    }
    
    var frameInterval: Int = 1 // Basic implementation; could be enhanced
    var isPaused: Bool = false {
        didSet {
            if isPaused { suspend() } else { resume() }
        }
    }
    
    init(target: Any, selector: Selector) {
        self.target = target
        self.selector = selector
        super.init()
        var link: CVDisplayLink?
        if CVDisplayLinkCreateWithActiveCGDisplays(&link) == kCVReturnSuccess {
            self.cvLink = link
        }
    }
    
    deinit {
        invalidate()
    }
    
    func add(to runloop: RunLoop, forMode mode: RunLoop.Mode) {
        if source == nil {
            setupDispatchSource(for: runloop)
        }
        registeredRunLoops[runloop, default: []].insert(mode)
        if !isPaused {
            resume()
        }
    }
    
    func remove(from runloop: RunLoop, forMode mode: RunLoop.Mode) {
        registeredRunLoops[runloop]?.remove(mode)
        if let modes = registeredRunLoops[runloop], modes.isEmpty {
            registeredRunLoops.removeValue(forKey: runloop)
        }
        if registeredRunLoops.isEmpty {
            suspend()
        }
    }
    
    func invalidate() {
        suspend()
        source?.cancel()
        source = nil
        registeredRunLoops.removeAll()
        isPaused = true
    }
    
    private func setupDispatchSource(for runloop: RunLoop) {
        let queue = runloop == .main ? DispatchQueue.main : DispatchQueue.global(qos: .userInteractive)
        let src = DispatchSource.makeUserDataAddSource(queue: queue)
        self.source = src
        if let link = cvLink {
            CVDisplayLinkSetOutputCallback(link, { (_, _, _, _, _, ptr) -> CVReturn in
                if let p = ptr {
                    let s = Unmanaged<DispatchSourceUserDataAdd>.fromOpaque(p).takeUnretainedValue()
                    s.add(data: 1)
                }
                return kCVReturnSuccess
            }, Unmanaged.passUnretained(src).toOpaque())
        }
        src.setEventHandler { [weak self] in
            guard let self else { return }
            for (rl, modes) in self.registeredRunLoops {
                for mode in modes {
                    rl.perform(self.selector, target: self.target, argument: self, order: 0, modes: [mode])
                }
            }
        }
        src.resume()
    }
    
    private func resume() {
        guard let link = cvLink, !CVDisplayLinkIsRunning(link) else { return }
        CVDisplayLinkStart(link)
    }
    
    private func suspend() {
        guard let link = cvLink, CVDisplayLinkIsRunning(link) else { return }
        CVDisplayLinkStop(link)
    }
}

#endif
