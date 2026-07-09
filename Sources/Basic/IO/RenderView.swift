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
    public var onPreviewHostExecutionReportUpdated: ((PreviewHostExecutionReport) -> Void)?
    public var onPreviewHostFleetSnapshotUpdated: ((PreviewHostFleetSnapshot) -> Void)?

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
    public private(set) var currentPreviewHostEnqueueCount: Int = 0
    public private(set) var currentPreviewHostVisibilityPauseCount: Int = 0
    public private(set) var currentPreviewHostVisibilityResumeCount: Int = 0
    public private(set) var currentPreviewHostLifecyclePauseCount: Int = 0
    public private(set) var currentPreviewHostLifecycleResumeCount: Int = 0
    public private(set) var currentPreviewHostSuspensionReason: String?
    public private(set) var currentPreviewHostLastFailureReason: String?

    var currentPreviewHostExecutionReport: PreviewHostExecutionReport {
        previewHostExecutionReport
    }

    var currentPreviewHostFleetSnapshot: PreviewHostFleetSnapshot {
        PreviewHostFleetRegistry.snapshot()
    }

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
                let previousFrame = currentRenderedFrame
                currentRenderedFrame = nil
                clearPreviewHostRuntimeSummary(for: previousFrame)
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
    private let previewHostInstanceIdentifier = UUID().uuidString
    private var lastPreviewHostVisibilityState: Bool?
    private var lastPreviewHostSuspensionReason: PreviewHostSuspensionReason?
    private var isApplicationPreviewHostActive: Bool = true
    private var previewHostNotificationObservers: [NSObjectProtocol] = []
    private var previewHostExecutionReport = PreviewHostExecutionReport.inactive(predictedStrategy: .metalTextureHost)

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
        stopObservingPreviewHostLifecycle()
        previewHostExecutionReport = PreviewHostExecutionReport.inactive(predictedStrategy: resolvedPredictedPreviewHostStrategy())
        publishPreviewHostExecutionReport(deliverCallbacks: false)
        publishPreviewHostFleetSnapshot(PreviewHostFleetRegistry.unregister(instanceID: previewHostInstanceIdentifier), deliverCallbacks: false)
        clearPreviewHostRuntimeSummary(for: currentRenderedFrame)
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
        startObservingPreviewHostLifecycle()
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
        if let cachedPipelineState, cachedPipelinePixelFormat == colorPixelFormat, cachedPipelineSampleCount == sampleCount {
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

    func makeCurrentRuntimePreviewHostSummary() -> RenderGraphDebugSnapshot.Diagnostics.RuntimePreviewHostSummary {
        makeCurrentRuntimePreviewHostSummary(fleet: PreviewHostFleetRegistry.snapshot())
    }

    func makeCurrentRuntimePreviewHostSummary(fleet: PreviewHostFleetSnapshot) -> RenderGraphDebugSnapshot.Diagnostics.RuntimePreviewHostSummary {
        RenderGraphDebugSnapshot.Diagnostics.RuntimePreviewHostSummary(report: previewHostExecutionReport, fleet: fleet)
    }

    func debugSimulatePreviewHostRecoveryForTesting() {
        setPreviewHostExecutionState(
            .recovering,
            strategy: previewHostStrategy(from: previewHostExecutionReport.actualResolvedHostStrategy),
            backingKind: previewHostBackingKind(from: previewHostExecutionReport.actualBackingKind),
            payloadMode: previewHostPayloadMode(from: previewHostExecutionReport.payloadMode),
            recoveredByFlush: true,
            fellBackToMetal: false
        )
        incrementPreviewHostRecoveryCount()
    }

    func debugSimulatePreviewHostFallbackForTesting() {
        recordPreviewHostFailure(.fallbackToMetal)
        setPreviewHostExecutionState(
            .fallbackMetal,
            strategy: .metalTextureHost,
            backingKind: .metalTextureHost,
            payloadMode: .none,
            recoveredByFlush: previewHostExecutionReport.recoveredByFlush,
            fellBackToMetal: true
        )
        incrementPreviewHostFallbackCount()
    }
}

extension RenderView: PreviewDisplaying {
    public func display(_ frame: RenderedFrame?) {
        let previousFrame = currentRenderedFrame
        if previousFrame?.cacheIdentity.fingerprint != frame?.cacheIdentity.fingerprint {
            clearPreviewHostRuntimeSummary(for: previousFrame)
        }
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
        currentPreviewHostEnqueueCount = 0
        currentPreviewHostVisibilityPauseCount = 0
        currentPreviewHostVisibilityResumeCount = 0
        currentPreviewHostLifecyclePauseCount = 0
        currentPreviewHostLifecycleResumeCount = 0
        currentPreviewHostSuspensionReason = nil
        currentPreviewHostLastFailureReason = nil
        lastPreviewHostVisibilityState = nil
        lastPreviewHostSuspensionReason = nil
        previewHostExecutionReport = .inactive(predictedStrategy: initialResolution?.strategy ?? .metalTextureHost)
        syncPublicPreviewHostState()
        publishPreviewHostExecutionReport()
        if let strategy = initialResolution?.strategy {
            recordPreviewHostStrategy(strategy)
        }
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
        let shouldPauseForVisibility = supportsVisibilityPauseForCurrentFrame && currentPreviewHostSuspension != nil
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

    var currentPreviewHostSuspension: PreviewHostSuspensionReason? {
        if isApplicationPreviewHostActive == false {
            return .applicationInactive
        }
        if supportsVisibilityPauseForCurrentFrame && isCurrentlyHostVisible == false {
            return .hostHidden
        }
        return nil
    }

    func resolvePreviewHost(for frame: RenderedFrame?) {
        guard let frame else {
            setPreviewHostExecutionState(
                .inactive,
                strategy: .metalTextureHost,
                backingKind: .metalTextureHost,
                payloadMode: .none,
                recoveredByFlush: false,
                fellBackToMetal: false
            )
            deactivateSampleBufferPreviewHost()
            return
        }
        let resolution = frame.previewHostStrategyResolution
        switch resolution.strategy {
        case .metalTextureHost, .sampleBufferRematerializedHost:
            setPreviewHostExecutionState(
                .metalActive,
                strategy: .metalTextureHost,
                backingKind: .metalTextureHost,
                payloadMode: .none,
                recoveredByFlush: false,
                fellBackToMetal: false,
                clearLastFailure: true
            )
            deactivateSampleBufferPreviewHost()
        case .sampleBufferPassthroughHost:
            #if canImport(AVFoundation) && !os(watchOS)
            guard displayWithSampleBufferPreviewHost(frame: frame, resolution: resolution) else {
                fallbackToMetalPreviewHost(frame: frame, recoveredByFlush: hostRecoveredCurrentFrameByFlush)
                return
            }
            currentPreviewHostStrategy = resolution.strategy.rawValue
            #else
            recordPreviewHostFailure(.sampleBufferHostUnsupported)
            fallbackToMetalPreviewHost(frame: frame, recoveredByFlush: false)
            #endif
        }
    }

    func fallbackToMetalPreviewHost(frame: RenderedFrame, recoveredByFlush: Bool) {
        recordPreviewHostFailure(.fallbackToMetal)
        deactivateSampleBufferPreviewHost()
        currentRenderedFrame = frame
        texture = frame.texture
        setPreviewHostExecutionState(
            .fallbackMetal,
            strategy: .metalTextureHost,
            backingKind: .metalTextureHost,
            payloadMode: .none,
            recoveredByFlush: recoveredByFlush,
            fellBackToMetal: true
        )
        incrementPreviewHostFallbackCount()
        #if canImport(AVFoundation) && !os(watchOS)
        SampleBufferPreviewLayerPool.recordFallbackToMetal()
        #endif
        Shared.shared.performanceMonitor?.recordPreviewHostFallbackToMetal(previewHostTelemetryIdentifier)
        recordPreviewHostStrategy(.metalTextureHost)
        updatePreviewHostScheduling()
        invalidateDisplay()
    }

    func deactivateSampleBufferPreviewHost() {
        #if canImport(AVFoundation) && !os(watchOS)
        SampleBufferPreviewLayerPool.return(sampleBufferPreviewLayerLease)
        sampleBufferPreviewLayerLease = nil
        lastSampleBufferPreviewFrame = nil
        recordPreviewHostPoolSnapshot()
        #endif
        isUsingSampleBufferPreviewHost = false
        lastPreviewHostVisibilityState = nil
        lastPreviewHostSuspensionReason = nil
        currentPreviewHostSuspensionReason = nil
    }

    func updateSampleBufferPreviewVisibilityIfNeeded() {
        #if canImport(AVFoundation) && !os(watchOS)
        guard isUsingSampleBufferPreviewHost else { return }
        layoutSampleBufferPreviewLayerIfNeeded()
        if let suspensionReason = currentPreviewHostSuspension {
            recordPreviewHostSuspensionIfNeeded(suspensionReason)
            if suspensionReason == .hostHidden {
                recordPreviewHostVisibilityPauseIfNeeded()
            }
            flushSampleBufferPreviewLayerForSuspendIfNeeded()
            return
        }
        recordPreviewHostLifecycleResumeIfNeeded()
        recordPreviewHostVisibilityResumeIfNeeded()
        if let sampleBuffer = lastSampleBufferPreviewFrame {
            _ = enqueueSampleBufferPreviewFrame(sampleBuffer, allowRecovery: true)
        }
        #endif
    }

    #if canImport(AVFoundation) && !os(watchOS)
    func displayWithSampleBufferPreviewHost(frame: RenderedFrame, resolution: PreviewHostStrategyResolution) -> Bool {
        guard let sampleBuffer = try? frame.makePreviewHostSampleBuffer() else {
            recordPreviewHostFailure(.missingSampleBufferPayload)
            return false
        }
        let lease = sampleBufferPreviewLayerLease ?? SampleBufferPreviewLayerPool.take()
        sampleBufferPreviewLayerLease = lease
        attachSampleBufferPreviewLayerIfNeeded(lease)
        layoutSampleBufferPreviewLayerIfNeeded()
        lastSampleBufferPreviewFrame = sampleBuffer
        isUsingSampleBufferPreviewHost = true
        let payloadMode: PreviewHostPayloadMode = resolution.strategy == .sampleBufferPassthroughHost ? .passthrough : .rematerialized
        setPreviewHostExecutionState(
            .sampleBufferActive,
            strategy: resolution.strategy,
            backingKind: .sampleBufferDisplayLayer,
            payloadMode: payloadMode,
            recoveredByFlush: false,
            fellBackToMetal: false,
            clearLastFailure: true
        )
        if let suspensionReason = currentPreviewHostSuspension {
            recordPreviewHostSuspensionIfNeeded(suspensionReason)
            if suspensionReason == .hostHidden {
                recordPreviewHostVisibilityPauseIfNeeded()
            }
            flushSampleBufferPreviewLayerForSuspendIfNeeded()
            return true
        }
        recordPreviewHostLifecycleResumeIfNeeded()
        recordPreviewHostVisibilityResumeIfNeeded()
        let enqueueSucceeded = enqueueSampleBufferPreviewFrame(sampleBuffer, allowRecovery: true)
        if enqueueSucceeded == false {
            recordPreviewHostFailure(.sampleBufferEnqueueFailed)
            return false
        }
        if resolution.hostRecoveredByFlush {
            updatePreviewHostExecutionReport {
                $0 = PreviewHostExecutionReport(
                    predictedStrategy: previewHostStrategy(from: $0.predictedStrategy),
                    actualBackingKind: previewHostBackingKind(from: $0.actualBackingKind),
                    actualResolvedHostStrategy: previewHostStrategy(from: $0.actualResolvedHostStrategy),
                    payloadMode: previewHostPayloadMode(from: $0.payloadMode),
                    state: previewHostExecutionState(from: $0.state),
                    currentSuspensionReason: previewHostSuspensionReason(from: $0.currentSuspensionReason),
                    lastFailureReason: previewHostFailureReason(from: $0.lastFailureReason),
                    recoveredByFlush: true,
                    fellBackToMetal: $0.fellBackToMetal,
                    enqueueCount: $0.enqueueCount,
                    lifecyclePauseCount: $0.lifecyclePauseCount,
                    lifecycleResumeCount: $0.lifecycleResumeCount,
                    visibilityPauseCount: $0.visibilityPauseCount,
                    visibilityResumeCount: $0.visibilityResumeCount,
                    strategySwitchCount: $0.strategySwitchCount,
                    activationCount: $0.activationCount,
                    deactivationCount: $0.deactivationCount,
                    recoveryCount: $0.recoveryCount,
                    fallbackCount: $0.fallbackCount,
                    failureCountsByReason: $0.failureCountsByReason
                )
            }
        }
        return true
    }

    func attachSampleBufferPreviewLayerIfNeeded(_ lease: SampleBufferPreviewLayerLease) {
        let hostLayer: CALayer? = self.layer
        guard let hostLayer else { return }
        guard lease.layer.superlayer !== hostLayer else {
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
        guard currentPreviewHostSuspension == nil else {
            return true
        }
        recordPreviewHostPoolSnapshot()
        if layer.status == .failed || sampleBufferPreviewLayerRequiresFlushToResume(layer) {
            if sampleBufferPreviewLayerRequiresFlushToResume(layer) {
                recordPreviewHostFailure(.requiresFlushToResume)
            }
            setPreviewHostExecutionState(
                .recovering,
                strategy: previewHostStrategy(from: previewHostExecutionReport.actualResolvedHostStrategy),
                backingKind: .sampleBufferDisplayLayer,
                payloadMode: previewHostPayloadMode(from: previewHostExecutionReport.payloadMode),
                recoveredByFlush: true,
                fellBackToMetal: false
            )
            incrementPreviewHostRecoveryCount()
            SampleBufferPreviewLayerPool.recordFlush()
            SampleBufferPreviewLayerPool.recordRecovery()
            Shared.shared.performanceMonitor?.recordPreviewHostRecovery(previewHostTelemetryIdentifier)
            layer.flush()
        }
        layer.enqueue(sampleBuffer)
        incrementPreviewHostEnqueueCount()
        Shared.shared.performanceMonitor?.recordPreviewHostEnqueue(previewHostTelemetryIdentifier)
        if allowRecovery && layer.status == .failed {
            setPreviewHostExecutionState(
                .recovering,
                strategy: previewHostStrategy(from: previewHostExecutionReport.actualResolvedHostStrategy),
                backingKind: .sampleBufferDisplayLayer,
                payloadMode: previewHostPayloadMode(from: previewHostExecutionReport.payloadMode),
                recoveredByFlush: true,
                fellBackToMetal: false
            )
            incrementPreviewHostRecoveryCount()
            SampleBufferPreviewLayerPool.recordFlush()
            SampleBufferPreviewLayerPool.recordRecovery()
            Shared.shared.performanceMonitor?.recordPreviewHostRecovery(previewHostTelemetryIdentifier)
            layer.flush()
            layer.enqueue(sampleBuffer)
            incrementPreviewHostEnqueueCount()
            Shared.shared.performanceMonitor?.recordPreviewHostEnqueue(previewHostTelemetryIdentifier)
        }
        if layer.status != .failed {
            setPreviewHostExecutionState(
                .sampleBufferActive,
                strategy: previewHostStrategy(from: previewHostExecutionReport.actualResolvedHostStrategy),
                backingKind: .sampleBufferDisplayLayer,
                payloadMode: previewHostPayloadMode(from: previewHostExecutionReport.payloadMode),
                recoveredByFlush: previewHostExecutionReport.recoveredByFlush,
                fellBackToMetal: false
            )
        }
        recordPreviewHostPoolSnapshot()
        return layer.status != .failed
    }

    func flushSampleBufferPreviewLayerForSuspendIfNeeded() {
        guard let layer = sampleBufferPreviewLayerLease?.layer else { return }
        SampleBufferPreviewLayerPool.recordFlush()
        SampleBufferPreviewLayerPool.recordFlushAndRemoveImage()
        layer.flushAndRemoveImage()
        recordPreviewHostPoolSnapshot()
    }

    func sampleBufferPreviewLayerRequiresFlushToResume(_ layer: AVSampleBufferDisplayLayer) -> Bool {
        if #available(macOS 11.0, iOS 14.0, tvOS 11.0, *) {
            return layer.requiresFlushToResumeDecoding
        }
        return false
    }
    #endif

    func startObservingPreviewHostLifecycle() {
        #if canImport(UIKit) && !os(watchOS)
        isApplicationPreviewHostActive = UIApplication.shared.applicationState != .background
        let center = NotificationCenter.default
        previewHostNotificationObservers = [
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handlePreviewHostApplicationActiveState(false)
            },
            center.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handlePreviewHostApplicationActiveState(true)
            },
            center.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handlePreviewHostApplicationActiveState(true)
            }
        ]
        #elseif canImport(AppKit)
        isApplicationPreviewHostActive = NSApp?.isActive ?? true
        let center = NotificationCenter.default
        previewHostNotificationObservers = [
            center.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handlePreviewHostApplicationActiveState(false)
            },
            center.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handlePreviewHostApplicationActiveState(true)
            }
        ]
        #endif
    }

    func stopObservingPreviewHostLifecycle() {
        guard previewHostNotificationObservers.isEmpty == false else { return }
        let center = NotificationCenter.default
        for observer in previewHostNotificationObservers {
            center.removeObserver(observer)
        }
        previewHostNotificationObservers.removeAll()
    }

    func handlePreviewHostApplicationActiveState(_ isActive: Bool) {
        guard isApplicationPreviewHostActive != isActive else { return }
        isApplicationPreviewHostActive = isActive
        updatePreviewHostScheduling()
        updateSampleBufferPreviewVisibilityIfNeeded()
    }

    var previewHostTelemetryIdentifier: String {
        "\(previewHostInstanceIdentifier):\(currentRenderedFrame?.identifier ?? "no-frame")"
    }

    func recordPreviewHostStrategy(_ strategy: PreviewHostStrategy) {
        Shared.shared.performanceMonitor?.recordPreviewHostStrategy(previewHostTelemetryIdentifier, strategy: strategy)
    }

    func recordPreviewHostPoolSnapshot() {
        #if canImport(AVFoundation) && !os(watchOS)
        Shared.shared.performanceMonitor?.recordPreviewHostPoolSnapshot(
            previewHostTelemetryIdentifier,
            snapshot: SampleBufferPreviewLayerPool.snapshot()
        )
        #endif
    }

    func recordPreviewHostVisibilityPauseIfNeeded() {
        guard lastPreviewHostVisibilityState != false else { return }
        lastPreviewHostVisibilityState = false
        incrementPreviewHostVisibilityPauseCount()
        #if canImport(AVFoundation) && !os(watchOS)
        SampleBufferPreviewLayerPool.recordVisibilityPause()
        #endif
        Shared.shared.performanceMonitor?.recordPreviewHostVisibilityPause(previewHostTelemetryIdentifier)
    }

    func recordPreviewHostVisibilityResumeIfNeeded() {
        guard lastPreviewHostVisibilityState != true else { return }
        lastPreviewHostVisibilityState = true
        incrementPreviewHostVisibilityResumeCount()
        #if canImport(AVFoundation) && !os(watchOS)
        SampleBufferPreviewLayerPool.recordVisibilityResume()
        #endif
        Shared.shared.performanceMonitor?.recordPreviewHostVisibilityResume(previewHostTelemetryIdentifier)
    }

    func recordPreviewHostLifecycleResumeIfNeeded() {
        guard lastPreviewHostSuspensionReason != nil else { return }
        lastPreviewHostSuspensionReason = nil
        updatePreviewHostExecutionReport {
            $0 = PreviewHostExecutionReport(
                predictedStrategy: previewHostStrategy(from: $0.predictedStrategy),
                actualBackingKind: previewHostBackingKind(from: $0.actualBackingKind),
                actualResolvedHostStrategy: previewHostStrategy(from: $0.actualResolvedHostStrategy),
                payloadMode: previewHostPayloadMode(from: $0.payloadMode),
                state: previewHostExecutionState(from: $0.actualBackingKind == PreviewHostBackingKind.sampleBufferDisplayLayer.rawValue ? PreviewHostExecutionState.sampleBufferActive.rawValue : PreviewHostExecutionState.metalActive.rawValue),
                currentSuspensionReason: nil,
                lastFailureReason: previewHostFailureReason(from: $0.lastFailureReason),
                recoveredByFlush: $0.recoveredByFlush,
                fellBackToMetal: $0.fellBackToMetal,
                enqueueCount: $0.enqueueCount,
                lifecyclePauseCount: $0.lifecyclePauseCount,
                lifecycleResumeCount: $0.lifecycleResumeCount + 1,
                visibilityPauseCount: $0.visibilityPauseCount,
                visibilityResumeCount: $0.visibilityResumeCount,
                strategySwitchCount: $0.strategySwitchCount,
                activationCount: $0.activationCount,
                deactivationCount: $0.deactivationCount,
                recoveryCount: $0.recoveryCount,
                fallbackCount: $0.fallbackCount,
                failureCountsByReason: $0.failureCountsByReason
            )
        }
        #if canImport(AVFoundation) && !os(watchOS)
        SampleBufferPreviewLayerPool.recordLifecycleResume()
        #endif
        Shared.shared.performanceMonitor?.recordPreviewHostLifecycleResume(previewHostTelemetryIdentifier)
    }

    func recordPreviewHostSuspensionIfNeeded(_ reason: PreviewHostSuspensionReason) {
        guard lastPreviewHostSuspensionReason != reason else { return }
        lastPreviewHostSuspensionReason = reason
        if reason == .applicationInactive {
            recordPreviewHostFailure(.lifecycleSuspended)
        } else if reason == .hostHidden {
            recordPreviewHostFailure(.visibilitySuspended)
        }
        updatePreviewHostExecutionReport {
            $0 = PreviewHostExecutionReport(
                predictedStrategy: previewHostStrategy(from: $0.predictedStrategy),
                actualBackingKind: previewHostBackingKind(from: $0.actualBackingKind),
                actualResolvedHostStrategy: previewHostStrategy(from: $0.actualResolvedHostStrategy),
                payloadMode: previewHostPayloadMode(from: $0.payloadMode),
                state: .suspended,
                currentSuspensionReason: reason,
                lastFailureReason: previewHostFailureReason(from: $0.lastFailureReason),
                recoveredByFlush: $0.recoveredByFlush,
                fellBackToMetal: $0.fellBackToMetal,
                enqueueCount: $0.enqueueCount,
                lifecyclePauseCount: $0.lifecyclePauseCount + 1,
                lifecycleResumeCount: $0.lifecycleResumeCount,
                visibilityPauseCount: $0.visibilityPauseCount,
                visibilityResumeCount: $0.visibilityResumeCount,
                strategySwitchCount: $0.strategySwitchCount,
                activationCount: $0.activationCount,
                deactivationCount: $0.deactivationCount,
                recoveryCount: $0.recoveryCount,
                fallbackCount: $0.fallbackCount,
                failureCountsByReason: $0.failureCountsByReason
            )
        }
        #if canImport(AVFoundation) && !os(watchOS)
        SampleBufferPreviewLayerPool.recordLifecyclePause()
        #endif
        Shared.shared.performanceMonitor?.recordPreviewHostLifecyclePause(previewHostTelemetryIdentifier, reason: reason)
    }

    func recordPreviewHostFailure(_ reason: PreviewHostFailureReason) {
        updatePreviewHostExecutionReport {
            var failureCounts = $0.failureCountsByReason
            failureCounts[reason.rawValue, default: 0] += 1
            $0 = PreviewHostExecutionReport(
                predictedStrategy: previewHostStrategy(from: $0.predictedStrategy),
                actualBackingKind: previewHostBackingKind(from: $0.actualBackingKind),
                actualResolvedHostStrategy: previewHostStrategy(from: $0.actualResolvedHostStrategy),
                payloadMode: previewHostPayloadMode(from: $0.payloadMode),
                state: previewHostExecutionState(from: $0.state),
                currentSuspensionReason: previewHostSuspensionReason(from: $0.currentSuspensionReason),
                lastFailureReason: reason,
                recoveredByFlush: $0.recoveredByFlush,
                fellBackToMetal: $0.fellBackToMetal,
                enqueueCount: $0.enqueueCount,
                lifecyclePauseCount: $0.lifecyclePauseCount,
                lifecycleResumeCount: $0.lifecycleResumeCount,
                visibilityPauseCount: $0.visibilityPauseCount,
                visibilityResumeCount: $0.visibilityResumeCount,
                strategySwitchCount: $0.strategySwitchCount,
                activationCount: $0.activationCount,
                deactivationCount: $0.deactivationCount,
                recoveryCount: $0.recoveryCount,
                fallbackCount: $0.fallbackCount,
                failureCountsByReason: failureCounts
            )
        }
        Shared.shared.performanceMonitor?.recordPreviewHostFailure(previewHostTelemetryIdentifier, reason: reason)
    }

    func updatePreviewHostExecutionReport(_ mutate: (inout PreviewHostExecutionReport) -> Void) {
        var report = previewHostExecutionReport
        mutate(&report)
        previewHostExecutionReport = report
        syncPublicPreviewHostState()
        publishPreviewHostExecutionReport()
    }

    func syncPublicPreviewHostState() {
        currentPreviewHostStrategy = previewHostExecutionReport.actualResolvedHostStrategy
        isUsingSampleBufferPreviewHost = previewHostExecutionReport.actualBackingKind == PreviewHostBackingKind.sampleBufferDisplayLayer.rawValue
        hostRecoveredCurrentFrameByFlush = previewHostExecutionReport.recoveredByFlush
        hostFellBackCurrentFrameToMetal = previewHostExecutionReport.fellBackToMetal
        currentPreviewHostEnqueueCount = previewHostExecutionReport.enqueueCount
        currentPreviewHostVisibilityPauseCount = previewHostExecutionReport.visibilityPauseCount
        currentPreviewHostVisibilityResumeCount = previewHostExecutionReport.visibilityResumeCount
        currentPreviewHostLifecyclePauseCount = previewHostExecutionReport.lifecyclePauseCount
        currentPreviewHostLifecycleResumeCount = previewHostExecutionReport.lifecycleResumeCount
        currentPreviewHostSuspensionReason = previewHostExecutionReport.currentSuspensionReason
        currentPreviewHostLastFailureReason = previewHostExecutionReport.lastFailureReason
    }

    func setPreviewHostExecutionState(_ state: PreviewHostExecutionState,
                                      strategy: PreviewHostStrategy,
                                      backingKind: PreviewHostBackingKind,
                                      payloadMode: PreviewHostPayloadMode,
                                      recoveredByFlush: Bool,
                                      fellBackToMetal: Bool,
                                      clearLastFailure: Bool = false) {
        updatePreviewHostExecutionReport {
            let previousState = previewHostExecutionState(from: $0.state)
            let previousStrategy = previewHostStrategy(from: $0.actualResolvedHostStrategy)
            var strategySwitchCount = $0.strategySwitchCount
            if previousStrategy != strategy {
                strategySwitchCount += 1
            }
            var activationCount = $0.activationCount
            if previousState == .inactive && state != .inactive {
                activationCount += 1
            }
            var deactivationCount = $0.deactivationCount
            if previousState != .inactive && state == .inactive {
                deactivationCount += 1
            }
            $0 = PreviewHostExecutionReport(
                predictedStrategy: previewHostStrategy(from: $0.predictedStrategy),
                actualBackingKind: backingKind,
                actualResolvedHostStrategy: strategy,
                payloadMode: payloadMode,
                state: state,
                currentSuspensionReason: state == .suspended ? previewHostSuspensionReason(from: $0.currentSuspensionReason) : nil,
                lastFailureReason: clearLastFailure ? nil : previewHostFailureReason(from: $0.lastFailureReason),
                recoveredByFlush: recoveredByFlush,
                fellBackToMetal: fellBackToMetal,
                enqueueCount: $0.enqueueCount,
                lifecyclePauseCount: $0.lifecyclePauseCount,
                lifecycleResumeCount: $0.lifecycleResumeCount,
                visibilityPauseCount: $0.visibilityPauseCount,
                visibilityResumeCount: $0.visibilityResumeCount,
                strategySwitchCount: strategySwitchCount,
                activationCount: activationCount,
                deactivationCount: deactivationCount,
                recoveryCount: $0.recoveryCount,
                fallbackCount: $0.fallbackCount,
                failureCountsByReason: $0.failureCountsByReason
            )
        }
    }

    func incrementPreviewHostEnqueueCount() {
        updatePreviewHostExecutionReport {
            $0 = PreviewHostExecutionReport(
                predictedStrategy: previewHostStrategy(from: $0.predictedStrategy),
                actualBackingKind: previewHostBackingKind(from: $0.actualBackingKind),
                actualResolvedHostStrategy: previewHostStrategy(from: $0.actualResolvedHostStrategy),
                payloadMode: previewHostPayloadMode(from: $0.payloadMode),
                state: previewHostExecutionState(from: $0.state),
                currentSuspensionReason: previewHostSuspensionReason(from: $0.currentSuspensionReason),
                lastFailureReason: previewHostFailureReason(from: $0.lastFailureReason),
                recoveredByFlush: $0.recoveredByFlush,
                fellBackToMetal: $0.fellBackToMetal,
                enqueueCount: $0.enqueueCount + 1,
                lifecyclePauseCount: $0.lifecyclePauseCount,
                lifecycleResumeCount: $0.lifecycleResumeCount,
                visibilityPauseCount: $0.visibilityPauseCount,
                visibilityResumeCount: $0.visibilityResumeCount,
                strategySwitchCount: $0.strategySwitchCount,
                activationCount: $0.activationCount,
                deactivationCount: $0.deactivationCount,
                recoveryCount: $0.recoveryCount,
                fallbackCount: $0.fallbackCount,
                failureCountsByReason: $0.failureCountsByReason
            )
        }
    }

    func incrementPreviewHostVisibilityPauseCount() {
        updatePreviewHostExecutionReport {
            $0 = PreviewHostExecutionReport(
                predictedStrategy: previewHostStrategy(from: $0.predictedStrategy),
                actualBackingKind: previewHostBackingKind(from: $0.actualBackingKind),
                actualResolvedHostStrategy: previewHostStrategy(from: $0.actualResolvedHostStrategy),
                payloadMode: previewHostPayloadMode(from: $0.payloadMode),
                state: previewHostExecutionState(from: $0.state),
                currentSuspensionReason: previewHostSuspensionReason(from: $0.currentSuspensionReason),
                lastFailureReason: previewHostFailureReason(from: $0.lastFailureReason),
                recoveredByFlush: $0.recoveredByFlush,
                fellBackToMetal: $0.fellBackToMetal,
                enqueueCount: $0.enqueueCount,
                lifecyclePauseCount: $0.lifecyclePauseCount,
                lifecycleResumeCount: $0.lifecycleResumeCount,
                visibilityPauseCount: $0.visibilityPauseCount + 1,
                visibilityResumeCount: $0.visibilityResumeCount,
                strategySwitchCount: $0.strategySwitchCount,
                activationCount: $0.activationCount,
                deactivationCount: $0.deactivationCount,
                recoveryCount: $0.recoveryCount,
                fallbackCount: $0.fallbackCount,
                failureCountsByReason: $0.failureCountsByReason
            )
        }
    }

    func incrementPreviewHostVisibilityResumeCount() {
        updatePreviewHostExecutionReport {
            $0 = PreviewHostExecutionReport(
                predictedStrategy: previewHostStrategy(from: $0.predictedStrategy),
                actualBackingKind: previewHostBackingKind(from: $0.actualBackingKind),
                actualResolvedHostStrategy: previewHostStrategy(from: $0.actualResolvedHostStrategy),
                payloadMode: previewHostPayloadMode(from: $0.payloadMode),
                state: previewHostExecutionState(from: $0.state),
                currentSuspensionReason: previewHostSuspensionReason(from: $0.currentSuspensionReason),
                lastFailureReason: previewHostFailureReason(from: $0.lastFailureReason),
                recoveredByFlush: $0.recoveredByFlush,
                fellBackToMetal: $0.fellBackToMetal,
                enqueueCount: $0.enqueueCount,
                lifecyclePauseCount: $0.lifecyclePauseCount,
                lifecycleResumeCount: $0.lifecycleResumeCount,
                visibilityPauseCount: $0.visibilityPauseCount,
                visibilityResumeCount: $0.visibilityResumeCount + 1,
                strategySwitchCount: $0.strategySwitchCount,
                activationCount: $0.activationCount,
                deactivationCount: $0.deactivationCount,
                recoveryCount: $0.recoveryCount,
                fallbackCount: $0.fallbackCount,
                failureCountsByReason: $0.failureCountsByReason
            )
        }
    }

    func incrementPreviewHostRecoveryCount() {
        updatePreviewHostExecutionReport {
            $0 = PreviewHostExecutionReport(
                predictedStrategy: previewHostStrategy(from: $0.predictedStrategy),
                actualBackingKind: previewHostBackingKind(from: $0.actualBackingKind),
                actualResolvedHostStrategy: previewHostStrategy(from: $0.actualResolvedHostStrategy),
                payloadMode: previewHostPayloadMode(from: $0.payloadMode),
                state: previewHostExecutionState(from: $0.state),
                currentSuspensionReason: previewHostSuspensionReason(from: $0.currentSuspensionReason),
                lastFailureReason: previewHostFailureReason(from: $0.lastFailureReason),
                recoveredByFlush: true,
                fellBackToMetal: $0.fellBackToMetal,
                enqueueCount: $0.enqueueCount,
                lifecyclePauseCount: $0.lifecyclePauseCount,
                lifecycleResumeCount: $0.lifecycleResumeCount,
                visibilityPauseCount: $0.visibilityPauseCount,
                visibilityResumeCount: $0.visibilityResumeCount,
                strategySwitchCount: $0.strategySwitchCount,
                activationCount: $0.activationCount,
                deactivationCount: $0.deactivationCount,
                recoveryCount: $0.recoveryCount + 1,
                fallbackCount: $0.fallbackCount,
                failureCountsByReason: $0.failureCountsByReason
            )
        }
    }

    func incrementPreviewHostFallbackCount() {
        updatePreviewHostExecutionReport {
            $0 = PreviewHostExecutionReport(
                predictedStrategy: previewHostStrategy(from: $0.predictedStrategy),
                actualBackingKind: previewHostBackingKind(from: $0.actualBackingKind),
                actualResolvedHostStrategy: previewHostStrategy(from: $0.actualResolvedHostStrategy),
                payloadMode: previewHostPayloadMode(from: $0.payloadMode),
                state: previewHostExecutionState(from: $0.state),
                currentSuspensionReason: previewHostSuspensionReason(from: $0.currentSuspensionReason),
                lastFailureReason: previewHostFailureReason(from: $0.lastFailureReason),
                recoveredByFlush: $0.recoveredByFlush,
                fellBackToMetal: true,
                enqueueCount: $0.enqueueCount,
                lifecyclePauseCount: $0.lifecyclePauseCount,
                lifecycleResumeCount: $0.lifecycleResumeCount,
                visibilityPauseCount: $0.visibilityPauseCount,
                visibilityResumeCount: $0.visibilityResumeCount,
                strategySwitchCount: $0.strategySwitchCount,
                activationCount: $0.activationCount,
                deactivationCount: $0.deactivationCount,
                recoveryCount: $0.recoveryCount,
                fallbackCount: $0.fallbackCount + 1,
                failureCountsByReason: $0.failureCountsByReason
            )
        }
    }

    func publishPreviewHostExecutionReport(deliverCallbacks: Bool = true) {
        let snapshot = PreviewHostFleetRegistry.update(instanceID: previewHostInstanceIdentifier, report: previewHostExecutionReport)
        if let cacheIdentityFingerprint = currentRenderedFrame?.cacheIdentity.fingerprint {
            PreviewHostRuntimeSummaryCache.store(
                cacheIdentityFingerprint: cacheIdentityFingerprint,
                instanceID: previewHostInstanceIdentifier,
                report: previewHostExecutionReport,
                fleet: snapshot
            )
        }
        Shared.shared.performanceMonitor?.recordPreviewHostExecution(previewHostTelemetryIdentifier, report: previewHostExecutionReport)
        if deliverCallbacks {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onPreviewHostExecutionReportUpdated?(self.previewHostExecutionReport)
            }
        }
        publishPreviewHostFleetSnapshot(snapshot, deliverCallbacks: deliverCallbacks)
    }

    func publishPreviewHostFleetSnapshot(_ snapshot: PreviewHostFleetSnapshot, deliverCallbacks: Bool = true) {
        Shared.shared.performanceMonitor?.recordPreviewHostFleetSnapshot(previewHostTelemetryIdentifier, snapshot: snapshot)
        if deliverCallbacks {
            DispatchQueue.main.async { [weak self] in
                self?.onPreviewHostFleetSnapshotUpdated?(snapshot)
            }
        }
    }

    func resolvedPredictedPreviewHostStrategy() -> PreviewHostStrategy {
        previewHostStrategy(from: currentRenderedFrame?.previewHostStrategyResolution.strategy.rawValue ?? PreviewHostStrategy.metalTextureHost.rawValue)
    }

    func previewHostStrategy(from rawValue: String) -> PreviewHostStrategy {
        PreviewHostStrategy(rawValue: rawValue) ?? .metalTextureHost
    }

    func previewHostExecutionState(from rawValue: String) -> PreviewHostExecutionState {
        PreviewHostExecutionState(rawValue: rawValue) ?? .inactive
    }

    func previewHostBackingKind(from rawValue: String) -> PreviewHostBackingKind {
        PreviewHostBackingKind(rawValue: rawValue) ?? .metalTextureHost
    }

    func previewHostPayloadMode(from rawValue: String) -> PreviewHostPayloadMode {
        PreviewHostPayloadMode(rawValue: rawValue) ?? .none
    }

    func previewHostSuspensionReason(from rawValue: String?) -> PreviewHostSuspensionReason? {
        guard let rawValue else { return nil }
        return PreviewHostSuspensionReason(rawValue: rawValue)
    }

    func previewHostFailureReason(from rawValue: String?) -> PreviewHostFailureReason? {
        guard let rawValue else { return nil }
        return PreviewHostFailureReason(rawValue: rawValue)
    }

    func clearPreviewHostRuntimeSummary(for frame: RenderedFrame?) {
        guard let cacheIdentityFingerprint = frame?.cacheIdentity.fingerprint else { return }
        PreviewHostRuntimeSummaryCache.remove(
            cacheIdentityFingerprint: cacheIdentityFingerprint,
            instanceID: previewHostInstanceIdentifier
        )
    }
}
