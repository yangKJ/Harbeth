//
//  RenderRequest.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import Metal

/// A deferred single-frame render contract that can be compiled first and executed later.
public struct RenderRequest {
    public let compilationSource: RenderCompilationSource
    public let profile: RenderProfile
    public let derivative: ImageDerivativeSpec
    public let source: ImageSourceDescriptor
    public let outputCachePolicy: ImageCachePolicy
    public let diagnostics: RenderPlanDiagnostics
    public let renderRecipe: RenderRecipe?

    private let renderTextureClosure: () throws -> MTLTexture
    private let renderFrameClosure: ([String: String]) throws -> RenderedFrame

    init(compilationSource: RenderCompilationSource,
         profile: RenderProfile,
         derivative: ImageDerivativeSpec,
         source: ImageSourceDescriptor,
         outputCachePolicy: ImageCachePolicy,
         diagnostics: RenderPlanDiagnostics,
         renderRecipe: RenderRecipe?,
         renderTexture: @escaping () throws -> MTLTexture,
         renderFrame: @escaping ([String: String]) throws -> RenderedFrame) {
        self.compilationSource = compilationSource
        self.profile = profile
        self.derivative = derivative
        self.source = source
        self.outputCachePolicy = outputCachePolicy
        self.diagnostics = diagnostics
        self.renderRecipe = renderRecipe
        self.renderTextureClosure = renderTexture
        self.renderFrameClosure = renderFrame
    }

    public func renderTexture() throws -> MTLTexture {
        try renderTextureClosure()
    }

    public func renderFrame(metadata: [String: String] = [:]) throws -> RenderedFrame {
        try renderFrameClosure(metadata)
    }
}
