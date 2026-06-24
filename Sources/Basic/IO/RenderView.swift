//
//  RenderView.swift
//  Harbeth
//
//  Created by Condy on 2024/8/1.
//

import Foundation
import MetalKit
#if canImport(AVFoundation) && !os(watchOS)
import AVFoundation
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

open class RenderView: MTKView {
    private enum PreviewHostDisplayMode {
        case lowLatency
        case stablePreview
        case completedReadback
    }

    public enum ResizingMode: Sendable, Equatable {
        case aspectFit
        case aspectFill
        case scaleToFill
    }

    public private(set) var currentRenderedFrame: RenderedFrame?

    public var currentFrameHostSourceDescriptor: FrameHostSourceDescriptor? {
        currentRenderedFrame?.frameHostSourceDescriptor
    }

    public var currentFrameHostRuntimeHint: FrameHostRuntimeHint? {
        currentRenderedFrame?.frameHostRuntimeHint
    }

    public private(set) var isRealtimePreviewFriendly: Bool = false
    public private(set) var supportsVisibilityPauseForCurrentFrame: Bool = false
    public private(set) var hasCompleteRealtimePreviewMetadata: Bool = false
    public private(set) var currentPreviewHostStrategy: String = PreviewHostStrategy.metalTextureHost.rawValue
    public private(set) var isUsingSampleBufferPreviewHost: Bool = false
    public private(set) var hostRecoveredCurrentFrameByFlush: Bool = false
    public private(set) var hostFellBackCurrentFrameToMetal: Bool = false

    open override var colorPixelFormat: MTLPixelFormat {
        didSet {
            guard oldValue != colorPixelFormat else { return }
            cachedPipelineState = nil
            updateDrawableSizeIfNeeded()
            invalidateDisplay()
        }
    }

    open override var clearColor: MTLClearColor {
        didSet {
            invalidateDisplay()
        }
    }

    public var resizingMode: ResizingMode = .aspectFit {
        didSet {
            guard oldValue != resizingMode else { return }
            invalidateDisplay()
        }
    }

    /// 默认跟随屏幕 scale。调用方可在测试或特定宿主里显式指定。
    public var preferredDrawableScale: CGFloat? {
        didSet {
            guard oldValue != preferredDrawableScale else { return }
            updateDrawableSizeIfNeeded()
            invalidateDisplay()
        }
    }

    public var texture: MTLTexture? {
        didSet {
            if currentRenderedFrame?.texture !== texture {
                currentRenderedFrame = nil
                deactivateSampleBufferPreviewHost()
                currentPreviewHostStrategy = PreviewHostStrategy.metalTextureHost.rawValue
                hostRecoveredCurrentFrameByFlush = false
                hostFellBackCurrentFrameToMetal = false
            }
            updateDrawableSizeIfNeeded()
            invalidateDisplay()
        }
    }

    private var cachedPipelineState: MTLRenderPipelineState?
    private var cachedPipelinePixelFormat: MTLPixelFormat?
    private var cachedPipelineSampleCount: Int = 0
    private var previewHostDisplayMode: PreviewHostDisplayMode = .stablePreview
    #if canImport(AVFoundation) && !os(watchOS)
    private var sampleBufferPreviewLayerLease: SampleBufferPreviewLayerLease?
    private var lastSampleBufferPreviewFrame: CMSampleBuffer?
    #endif

    private lazy var samplerState: MTLSamplerState? = {
        Shared.shared.defaultContext.makeSamplerState()
    }()

    public override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device ?? Shared.shared.metalDevice)
        commonInit()
    }

    public required init(coder: NSCoder) {
        super.init(coder: coder)
        if device == nil {
            device = Shared.shared.metalDevice
        }
        commonInit()
    }

    deinit {
        deactivateSampleBufferPreviewHost()
    }

    private func commonInit() {
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColorMake(1, 1, 1, 1)
        isPaused = true
        enableSetNeedsDisplay = true
        framebufferOnly = false
        delegate = self
        #if canImport(UIKit)
        contentMode = .scaleAspectFit
        #endif
        updateDrawableSizeIfNeeded()
    }

    #if canImport(UIKit)
    public override func layoutSubviews() {
        super.layoutSubviews()
        updateDrawableSizeIfNeeded()
        updatePreviewHostScheduling()
        updateSampleBufferPreviewVisibilityIfNeeded()
        invalidateDisplay()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        updateDrawableSizeIfNeeded()
        updatePreviewHostScheduling()
        updateSampleBufferPreviewVisibilityIfNeeded()
        invalidateDisplay()
    }
    #elseif canImport(AppKit)
    public override func layout() {
        super.layout()
        updateDrawableSizeIfNeeded()
        updatePreviewHostScheduling()
        updateSampleBufferPreviewVisibilityIfNeeded()
        needsDisplay = true
    }
    #endif

    private func updateDrawableSizeIfNeeded() {
        let targetSize = bounds.size
        guard targetSize.width > 0, targetSize.height > 0 else {
            return
        }
        let scale = resolvedDrawableScale()
        #if canImport(UIKit)
        if contentScaleFactor != scale {
            contentScaleFactor = scale
        }
        #endif
        let drawableSize = CGSize(
            width: max(ceil(targetSize.width * scale), 1),
            height: max(ceil(targetSize.height * scale), 1)
        )
        guard self.drawableSize != drawableSize else {
            return
        }
        self.drawableSize = drawableSize
    }

    private func quadVertices(for texture: MTLTexture, drawableSize: CGSize) -> [Float] {
        guard drawableSize.width > 0, drawableSize.height > 0 else {
            return Rendering.defaultVertices
        }
        if resizingMode == .scaleToFill {
            return Rendering.defaultVertices
        }
        let textureAspect = Float(texture.width) / Float(max(texture.height, 1))
        let viewAspect = Float(drawableSize.width / drawableSize.height)
        let scaleX: Float
        let scaleY: Float
        switch resizingMode {
        case .aspectFit:
            if textureAspect > viewAspect {
                scaleX = 1
                scaleY = viewAspect / textureAspect
            } else {
                scaleX = textureAspect / viewAspect
                scaleY = 1
            }
        case .aspectFill:
            if textureAspect > viewAspect {
                scaleX = textureAspect / viewAspect
                scaleY = 1
            } else {
                scaleX = 1
                scaleY = viewAspect / textureAspect
            }
        case .scaleToFill:
            scaleX = 1
            scaleY = 1
        }
        return [
            -scaleX, -scaleY, 0.0, 1.0,
             scaleX, -scaleY, 1.0, 1.0,
            -scaleX,  scaleY, 0.0, 0.0,
             scaleX,  scaleY, 1.0, 0.0,
        ]
    }

    private func invalidateDisplay() {
        #if canImport(UIKit)
        setNeedsDisplay()
        #elseif canImport(AppKit)
        setNeedsDisplay(bounds)
        #endif
    }

    private func resolvedDrawableScale() -> CGFloat {
        if let preferredDrawableScale {
            return max(preferredDrawableScale, 1)
        }
        #if canImport(UIKit)
        return max(window?.screen.scale ?? UIScreen.main.scale, 1)
        #elseif canImport(AppKit)
        return max(window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1, 1)
        #else
        return 1
        #endif
    }

    private func currentRenderPipelineState() -> MTLRenderPipelineState? {
        if let cachedPipelineState,
           cachedPipelinePixelFormat == colorPixelFormat,
           cachedPipelineSampleCount == sampleCount {
            return cachedPipelineState
        }
        let pipelineState = try? Shared.shared.defaultContext.makeRenderPipelineState(
            vertex: "basicVertex",
            fragment: "basicFragment",
            pixelFormat: colorPixelFormat,
            sampleCount: sampleCount
        )
        cachedPipelineState = pipelineState
        cachedPipelinePixelFormat = colorPixelFormat
        cachedPipelineSampleCount = sampleCount
        return pipelineState
    }
}

extension RenderView: HarbethPreviewDisplaying {
    public func display(_ frame: RenderedFrame?) {
        currentRenderedFrame = frame
        texture = frame?.texture
        let hint = frame?.frameHostRuntimeHint
        isRealtimePreviewFriendly = hint?.isRealtimePreviewEligible ?? false
        supportsVisibilityPauseForCurrentFrame = hint?.supportsVisibilityPause ?? false
        hasCompleteRealtimePreviewMetadata = hint?.metadataCompleteness.isCompleteForRealtimePreview ?? false
        previewHostDisplayMode = Self.displayMode(for: hint?.timingPolicy)
        let initialResolution = frame?.previewHostStrategyResolution
        currentPreviewHostStrategy = initialResolution?.strategy.rawValue ?? PreviewHostStrategy.metalTextureHost.rawValue
        hostRecoveredCurrentFrameByFlush = initialResolution?.hostRecoveredByFlush ?? false
        hostFellBackCurrentFrameToMetal = initialResolution?.hostFellBackToMetal ?? false
        updatePreviewHostScheduling()
        resolvePreviewHost(for: frame)
        if isPaused == false {
            draw()
        }
    }
}

extension RenderView: MTKViewDelegate {
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        invalidateDisplay()
    }
    
    public func draw(in view: MTKView) {
        guard isUsingSampleBufferPreviewHost == false else {
            return
        }
        guard let texture,
              let renderPassDescriptor = currentRenderPassDescriptor,
              let drawable = currentDrawable,
              let pipelineState = currentRenderPipelineState(),
              let commandBuffer = Shared.shared.commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        let vertices = quadVertices(for: texture, drawableSize: drawableSize)
        guard let vertexBuffer = device?.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Float>.size,
            options: []
        ) else {
            renderEncoder.endEncoding()
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        if let samplerState {
            renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        }
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

private extension RenderView {
    private static func displayMode(for timingPolicy: PreviewHostTimingPolicy?) -> PreviewHostDisplayMode {
        switch timingPolicy {
        case .lowLatency:
            return .lowLatency
        case .completedGPUReadback:
            return .completedReadback
        case .displayStable, .none:
            return .stablePreview
        }
    }

    func updatePreviewHostScheduling() {
        let shouldPauseForVisibility = supportsVisibilityPauseForCurrentFrame && isCurrentlyHostVisible == false
        if isUsingSampleBufferPreviewHost {
            isPaused = true
            enableSetNeedsDisplay = true
            return
        }
        switch previewHostDisplayMode {
        case .lowLatency:
            isPaused = shouldPauseForVisibility
            enableSetNeedsDisplay = shouldPauseForVisibility
        case .stablePreview, .completedReadback:
            isPaused = true
            enableSetNeedsDisplay = true
        }
    }

    var isCurrentlyHostVisible: Bool {
        #if canImport(UIKit)
        return window != nil && isHidden == false && alpha > 0.001
        #elseif canImport(AppKit)
        return window != nil && isHidden == false
        #else
        return true
        #endif
    }

    func resolvePreviewHost(for frame: RenderedFrame?) {
        guard let frame else {
            currentPreviewHostStrategy = PreviewHostStrategy.metalTextureHost.rawValue
            hostRecoveredCurrentFrameByFlush = false
            hostFellBackCurrentFrameToMetal = false
            deactivateSampleBufferPreviewHost()
            return
        }
        let resolution = frame.previewHostStrategyResolution
        switch resolution.strategy {
        case .metalTextureHost:
            currentPreviewHostStrategy = PreviewHostStrategy.metalTextureHost.rawValue
            deactivateSampleBufferPreviewHost()
        case .sampleBufferPassthroughHost, .sampleBufferRematerializedHost:
            #if canImport(AVFoundation) && !os(watchOS)
            guard displayWithSampleBufferPreviewHost(frame: frame, resolution: resolution) else {
                fallbackToMetalPreviewHost(frame: frame, recoveredByFlush: hostRecoveredCurrentFrameByFlush)
                return
            }
            currentPreviewHostStrategy = resolution.strategy.rawValue
            #else
            fallbackToMetalPreviewHost(frame: frame, recoveredByFlush: false)
            #endif
        }
    }

    func fallbackToMetalPreviewHost(frame: RenderedFrame, recoveredByFlush: Bool) {
        deactivateSampleBufferPreviewHost()
        currentRenderedFrame = frame
        texture = frame.texture
        currentPreviewHostStrategy = PreviewHostStrategy.metalTextureHost.rawValue
        hostRecoveredCurrentFrameByFlush = recoveredByFlush
        hostFellBackCurrentFrameToMetal = true
        updatePreviewHostScheduling()
        invalidateDisplay()
    }

    func deactivateSampleBufferPreviewHost() {
        #if canImport(AVFoundation) && !os(watchOS)
        SampleBufferPreviewLayerPool.return(sampleBufferPreviewLayerLease)
        sampleBufferPreviewLayerLease = nil
        lastSampleBufferPreviewFrame = nil
        #endif
        isUsingSampleBufferPreviewHost = false
    }

    func updateSampleBufferPreviewVisibilityIfNeeded() {
        #if canImport(AVFoundation) && !os(watchOS)
        guard isUsingSampleBufferPreviewHost else { return }
        layoutSampleBufferPreviewLayerIfNeeded()
        guard isCurrentlyHostVisible else { return }
        if let sampleBuffer = lastSampleBufferPreviewFrame {
            _ = enqueueSampleBufferPreviewFrame(sampleBuffer, allowRecovery: true)
        }
        #endif
    }

    #if canImport(AVFoundation) && !os(watchOS)
    func displayWithSampleBufferPreviewHost(frame: RenderedFrame,
                                            resolution: PreviewHostStrategyResolution) -> Bool {
        guard let sampleBuffer = try? frame.makePreviewHostSampleBuffer() else {
            return false
        }
        let lease = sampleBufferPreviewLayerLease ?? SampleBufferPreviewLayerPool.take()
        sampleBufferPreviewLayerLease = lease
        attachSampleBufferPreviewLayerIfNeeded(lease)
        layoutSampleBufferPreviewLayerIfNeeded()
        lastSampleBufferPreviewFrame = sampleBuffer
        isUsingSampleBufferPreviewHost = true
        hostRecoveredCurrentFrameByFlush = false
        hostFellBackCurrentFrameToMetal = false
        if supportsVisibilityPauseForCurrentFrame && isCurrentlyHostVisible == false {
            return true
        }
        let enqueueSucceeded = enqueueSampleBufferPreviewFrame(sampleBuffer, allowRecovery: true)
        if enqueueSucceeded == false {
            return false
        }
        hostRecoveredCurrentFrameByFlush = hostRecoveredCurrentFrameByFlush || resolution.hostRecoveredByFlush
        return true
    }

    func attachSampleBufferPreviewLayerIfNeeded(_ lease: SampleBufferPreviewLayerLease) {
        guard let hostLayer = layer else { return }
        guard lease.layer.superlayer !== layer else {
            return
        }
        hostLayer.addSublayer(lease.layer)
    }

    func layoutSampleBufferPreviewLayerIfNeeded() {
        guard let lease = sampleBufferPreviewLayerLease else { return }
        lease.prepare(frame: bounds, contentsScale: resolvedDrawableScale())
        switch resizingMode {
        case .aspectFit:
            lease.layer.videoGravity = .resizeAspect
        case .aspectFill:
            lease.layer.videoGravity = .resizeAspectFill
        case .scaleToFill:
            lease.layer.videoGravity = .resize
        }
    }

    func enqueueSampleBufferPreviewFrame(_ sampleBuffer: CMSampleBuffer, allowRecovery: Bool) -> Bool {
        guard let layer = sampleBufferPreviewLayerLease?.layer else {
            return false
        }
        if layer.status == .failed || sampleBufferPreviewLayerRequiresFlushToResume(layer) {
            hostRecoveredCurrentFrameByFlush = true
            layer.flush()
        }
        layer.enqueue(sampleBuffer)
        if allowRecovery && layer.status == .failed {
            hostRecoveredCurrentFrameByFlush = true
            layer.flush()
            layer.enqueue(sampleBuffer)
        }
        return layer.status != .failed
    }

    func sampleBufferPreviewLayerRequiresFlushToResume(_ layer: AVSampleBufferDisplayLayer) -> Bool {
        if #available(macOS 11.0, iOS 11.0, tvOS 11.0, *) {
            return layer.requiresFlushToResumeDecoding
        }
        return false
    }
    #endif
}
