//
//  PreviewViewport.swift
//  Harbeth
//
//  Created by Condy on 2026/10/10.
//

import CoreGraphics
import Metal

/// 整张纹理在 drawable 内的归一化目标矩形，原点位于左上；越界部分由 GPU 裁剪。
public struct PreviewViewport: Sendable, Equatable {
    public let normalizedContentRect: CGRect

    public init?(normalizedContentRect: CGRect) {
        guard normalizedContentRect.origin.x.isFinite, normalizedContentRect.origin.y.isFinite,
              normalizedContentRect.size.width.isFinite, normalizedContentRect.size.height.isFinite,
              normalizedContentRect.size.width > 0, normalizedContentRect.size.height > 0,
              normalizedContentRect.maxX.isFinite, normalizedContentRect.maxY.isFinite else { return nil }
        self.normalizedContentRect = normalizedContentRect
    }
}

/// 显示采样独立于帧处理的 sampler 合同，不修改纹理或渲染结果。
public enum PreviewSampling: Sendable, Equatable {
    case linear
    case nearest
}

enum PreviewQuadGeometry {
    static func vertices(
        textureSize: CGSize, drawableSize: CGSize,
        resizingMode: RenderView.ResizingMode, viewport: PreviewViewport?
    ) -> [Float]? {
        guard textureSize.width.isFinite, textureSize.height.isFinite,
              textureSize.width > 0, textureSize.height > 0,
              drawableSize.width.isFinite, drawableSize.height.isFinite,
              drawableSize.width > 0, drawableSize.height > 0 else { return nil }
        let rect: CGRect
        if let viewport {
            rect = viewport.normalizedContentRect
        } else {
            let textureAspect = textureSize.width / textureSize.height
            let viewAspect = drawableSize.width / drawableSize.height
            let width: CGFloat
            let height: CGFloat
            switch resizingMode {
            case .aspectFit:
                width = textureAspect > viewAspect ? 1 : textureAspect / viewAspect
                height = textureAspect > viewAspect ? viewAspect / textureAspect : 1
            case .aspectFill:
                width = textureAspect > viewAspect ? textureAspect / viewAspect : 1
                height = textureAspect > viewAspect ? 1 : viewAspect / textureAspect
            case .scaleToFill:
                width = 1
                height = 1
            }
            rect = CGRect(x: (1 - width) / 2, y: (1 - height) / 2, width: width, height: height)
        }
        guard rect.origin.x.isFinite, rect.origin.y.isFinite,
              rect.size.width.isFinite, rect.size.height.isFinite,
              rect.size.width > 0, rect.size.height > 0 else { return nil }
        let visible = rect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !visible.isNull, visible.width > 0, visible.height > 0 else { return [] }
        // 先在 CGFloat 域裁可见 quad，再映射 UV；高倍率不把巨大 NDC 交给 Float。
        let left = Float(visible.minX * 2 - 1)
        let right = Float(visible.maxX * 2 - 1)
        let bottom = Float(1 - visible.maxY * 2)
        let top = Float(1 - visible.minY * 2)
        let u0 = Float((visible.minX - rect.minX) / rect.width)
        let u1 = Float((visible.maxX - rect.minX) / rect.width)
        let v0 = Float((visible.minY - rect.minY) / rect.height)
        let v1 = Float((visible.maxY - rect.minY) / rect.height)
        guard [left, right, bottom, top, u0, u1, v0, v1].allSatisfy(\.isFinite) else { return nil }
        return [left, bottom, u0, v1, right, bottom, u1, v1,
                left, top, u0, v0, right, top, u1, v0]
    }
}

enum PreviewDrawEncoder {
    static func encode(
        texture: MTLTexture, vertices: [Float], pipelineState: MTLRenderPipelineState,
        samplerState: MTLSamplerState, into encoder: MTLRenderCommandEncoder
    ) {
        guard vertices.count == 16 else { return }
        encoder.setRenderPipelineState(pipelineState)
        // 64 字节由 command encoder 捕获，避免下一帧 CPU 覆写 GPU 在途顶点缓冲。
        vertices.withUnsafeBytes { bytes in
            if let address = bytes.baseAddress {
                encoder.setVertexBytes(address, length: bytes.count, index: 0)
            }
        }
        encoder.setFragmentSamplerState(samplerState, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
}
