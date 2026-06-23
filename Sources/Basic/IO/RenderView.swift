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

    public private(set) var currentRenderedFrame: RenderedFrame?

    public var texture: MTLTexture? {
        didSet {
            if currentRenderedFrame?.texture !== texture {
                currentRenderedFrame = nil
            }
            framebufferOnly = false
            updateDrawableSizeIfNeeded()
            invalidateDisplay()
        }
    }

    private lazy var renderPipelineState: MTLRenderPipelineState? = {
        try? Shared.shared.defaultContext.makeRenderPipelineState(
            vertex: "basicVertex",
            fragment: "basicFragment",
            pixelFormat: colorPixelFormat,
            sampleCount: sampleCount
        )
    }()

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
    }

    #if canImport(UIKit)
    public override func layoutSubviews() {
        super.layoutSubviews()
        updateDrawableSizeIfNeeded()
    }
    #elseif canImport(AppKit)
    public override func layout() {
        super.layout()
        updateDrawableSizeIfNeeded()
    }
    #endif

    private func updateDrawableSizeIfNeeded() {
        let targetSize = bounds.size
        guard targetSize.width > 0, targetSize.height > 0 else {
            return
        }
        guard drawableSize != targetSize else {
            return
        }
        drawableSize = targetSize
    }

    private func quadVertices(for texture: MTLTexture, drawableSize: CGSize) -> [Float] {
        guard drawableSize.width > 0, drawableSize.height > 0 else {
            return Rendering.defaultVertices
        }
        let textureAspect = Float(texture.width) / Float(max(texture.height, 1))
        let viewAspect = Float(drawableSize.width / drawableSize.height)
        let scaleX: Float
        let scaleY: Float
        if textureAspect > viewAspect {
            scaleX = 1
            scaleY = viewAspect / textureAspect
        } else {
            scaleX = textureAspect / viewAspect
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
}

extension RenderView: HarbethPreviewDisplaying {
    public func display(_ frame: RenderedFrame?) {
        currentRenderedFrame = frame
        texture = frame?.texture
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
              let pipelineState = renderPipelineState,
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
