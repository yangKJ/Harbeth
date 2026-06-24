//
//  RenderView.swift
//  Harbeth
//
//  Created by Condy on 2024/8/1.
//

import Foundation
import MetalKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

open class RenderView: MTKView {

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
            }
            updateDrawableSizeIfNeeded()
            invalidateDisplay()
        }
    }

    private var cachedPipelineState: MTLRenderPipelineState?
    private var cachedPipelinePixelFormat: MTLPixelFormat?
    private var cachedPipelineSampleCount: Int = 0

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
        invalidateDisplay()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        updateDrawableSizeIfNeeded()
        invalidateDisplay()
    }
    #elseif canImport(AppKit)
    public override func layout() {
        super.layout()
        updateDrawableSizeIfNeeded()
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
        if let frame {
            switch frame.frameHostRuntimeHint.timingPolicy {
            case .lowLatency, .displayStable:
                isPaused = true
                enableSetNeedsDisplay = true
            case .completedGPUReadback:
                isPaused = true
                enableSetNeedsDisplay = true
            }
        }
    }
}

extension RenderView: MTKViewDelegate {
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        invalidateDisplay()
    }
    
    public func draw(in view: MTKView) {
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
