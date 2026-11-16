//
//  TextureScopedMask.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import Metal

public extension MTLTextureCompatible_ {
    /// Build a scope-derived mask texture for advanced node and editing workflows.
    func makeMaskTexture(scope: TextureAnalysisScope, pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MTLTexture? {
        guard resolvedHistogramRegion(scope.region) != nil else { return nil }
        return try GPUTextureAnalysis.mask(target, scope: scope, pixelFormat: pixelFormat)
    }

    func makeMaskDescriptor(scope: TextureAnalysisScope,
                            component: MaskComponent = .red,
                            blendMode: MaskBlendMode = .mix,
                            invert: Bool = false,
                            featherPolicy: MaskFeatherPolicy = .none,
                            opacity: Float = 1.0,
                            pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MaskDescriptor? {
        guard let texture = try makeMaskTexture(scope: scope, pixelFormat: pixelFormat) else {
            return nil
        }
        return MaskDescriptor(
            texture: texture,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
    }
}

public extension RenderedAttachment {
    func makeMaskTexture(scope: TextureAnalysisScope, pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MTLTexture? {
        try texture.c7.makeMaskTexture(scope: scope, pixelFormat: pixelFormat)
    }

    func makeMaskDescriptor(scope: TextureAnalysisScope,
                            component: MaskComponent = .red,
                            blendMode: MaskBlendMode = .mix,
                            invert: Bool = false,
                            featherPolicy: MaskFeatherPolicy = .none,
                            opacity: Float = 1.0,
                            pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MaskDescriptor? {
        try texture.c7.makeMaskDescriptor(
            scope: scope,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            pixelFormat: pixelFormat
        )
    }
}

public extension RenderedAttachmentSet {
    func makeMaskTexture(for semantic: RenderOutputAttachmentSemantic, scope: TextureAnalysisScope, pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MTLTexture? {
        try attachment(for: semantic)?.makeMaskTexture(scope: scope, pixelFormat: pixelFormat)
    }

    func makeMaskDescriptor(for semantic: RenderOutputAttachmentSemantic,
                            scope: TextureAnalysisScope,
                            component: MaskComponent = .red,
                            blendMode: MaskBlendMode = .mix,
                            invert: Bool = false,
                            featherPolicy: MaskFeatherPolicy = .none,
                            opacity: Float = 1.0,
                            pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MaskDescriptor? {
        try attachment(for: semantic)?.makeMaskDescriptor(
            scope: scope,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            pixelFormat: pixelFormat
        )
    }
}

public extension RenderedFrame {
    func makeMaskTexture(scope: TextureAnalysisScope, pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MTLTexture? {
        try texture.c7.makeMaskTexture(scope: scope, pixelFormat: pixelFormat)
    }

    func makeMaskDescriptor(scope: TextureAnalysisScope,
                            component: MaskComponent = .red,
                            blendMode: MaskBlendMode = .mix,
                            invert: Bool = false,
                            featherPolicy: MaskFeatherPolicy = .none,
                            opacity: Float = 1.0,
                            pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MaskDescriptor? {
        try texture.c7.makeMaskDescriptor(
            scope: scope,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            pixelFormat: pixelFormat
        )
    }
}

public extension RenderRequest {
    /// Bridge scope-derived masks into request-backed advanced workflows.
    func renderMaskDescriptor(scope: TextureAnalysisScope,
                              component: MaskComponent = .red,
                              blendMode: MaskBlendMode = .mix,
                              invert: Bool = false,
                              featherPolicy: MaskFeatherPolicy = .none,
                              opacity: Float = 1.0,
                              pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MaskDescriptor? {
        try renderFrame().makeMaskDescriptor(
            scope: scope,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            pixelFormat: pixelFormat
        )
    }
}
