//
//  RenderView.swift
//  Harbeth
//
//  Created by Condy on 2024/8/1.
//

import Foundation
import MetalKit

#if os(iOS) || os(tvOS) || os(watchOS)
open class RenderView: C7View {
    
    private var screenScale: CGFloat = 1.0
    private var backgroundAccessingBounds: CGRect = .zero
    
    public lazy var renderView: MTKView = {
        let renderView = MTKView(frame: self.bounds, device: Device.device())
        //renderView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        renderView.delegate = self
        renderView.isPaused = true
        renderView.enableSetNeedsDisplay = false
        renderView.contentMode = self.contentMode
        renderView.framebufferOnly = false
        renderView.autoResizeDrawable = true
        return renderView
    }()
    
    public override init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        self.setupMTKView()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupMTKView()
    }
    
    public var inputTexture: MTLTexture? {
        didSet {
            self.updateContentScaleFactor()
            self.setNeedsRedraw()
        }
    }
    
    public var filters: [C7FilterProtocol] = [] {
        didSet {
            self.updateContentScaleFactor()
            self.setNeedsRedraw()
        }
    }
    
    public var drawsImmediately: Bool = false {
        didSet {
            if drawsImmediately {
                renderView.isPaused = true
                renderView.enableSetNeedsDisplay = false
            } else {
                renderView.isPaused = true
                renderView.enableSetNeedsDisplay = true
            }
        }
    }
    
    open override func didMoveToWindow() {
        super.didMoveToWindow()
        if let screen = self.window?.screen {
            screenScale = min(screen.nativeScale, screen.scale)
        } else {
            screenScale = 1.0
        }
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        self.renderView.frame = self.bounds
        self.updateContentScaleFactor()
        self.setNeedsRedraw()
    }
}

extension RenderView {
    
    private func setupMTKView() {
        if #available(iOS 11.0, *) {
            self.accessibilityIgnoresInvertColors = true
        }
        self.isOpaque = true
        self.addSubview(renderView)
    }
    
    private func setNeedsRedraw() {
        if drawsImmediately {
            renderView.draw()
        } else {
            renderView.setNeedsDisplay()
        }
    }
    
    private func updateContentScaleFactor() {
        guard let inputTexture = inputTexture,
              inputTexture.width > 0, inputTexture.height > 0,
              renderView.frame.width > 0, renderView.frame.height > 0,
              self.window?.screen != nil else {
            return
        }
        let ws = CGFloat(inputTexture.width) / renderView.frame.width
        let wh = CGFloat(inputTexture.height) / renderView.frame.height
        let scale = max(min(max(ws, wh), screenScale), 1.0)
        if abs(renderView.contentScaleFactor - scale) > 0.00001 {
            renderView.contentScaleFactor = scale
        }
    }
}

extension RenderView: MTKViewDelegate {
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    public func draw(in view: MTKView) {
        guard let texture = inputTexture, self.alpha > 0, !self.isHidden else {
            // Clear current drawable.
            if let descriptor = view.currentRenderPassDescriptor, let drawable = view.currentDrawable {
                let commandBuffer = Device.commandQueue().makeCommandBuffer()
                let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: descriptor)
                commandEncoder?.endEncoding()
                commandBuffer?.present(drawable)
                commandBuffer?.commit()
            }
            return
        }
        guard let commandBuffer = Device.commandQueue().makeCommandBuffer(),
              let currentDrawable = view.currentDrawable else {
            return
        }
        guard !filters.isEmpty else {
            commandBuffer.present(currentDrawable)
            commandBuffer.commit()
            return
        }
        do {
            var destTexture = currentDrawable.texture
            for filter in self.filters {
                let inputTexture = try filter.combinationBegin(for: commandBuffer, source: texture, dest: destTexture)
                switch filter.modifier {
                case .compute, .mps, .render:
                    destTexture = try filter.applyAtTexture(form: inputTexture, to: destTexture, for: commandBuffer)
                default:
                    break
                }
                let _ = try filter.combinationAfter(for: commandBuffer, input: destTexture, source: texture)
            }
        } catch {
            commandBuffer.present(currentDrawable)
            commandBuffer.commit()
        }
    }
}
#endif
