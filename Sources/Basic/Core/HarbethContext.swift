//
//  HarbethContext.swift
//  Harbeth
//
//  Created by Codex on 2026/6/21.
//

import Foundation
import Metal

public final class HarbethContext {

    public static var shared: HarbethContext {
        Shared.shared.defaultContext
    }

    private let legacyDevice: Device
    private let renderPipelineLock = NSLock()
    private let samplerLock = NSLock()
    private let imageResolutionLock = NSLock()
    private var renderPipelines: [RenderPipelineCacheKey: MTLRenderPipelineState] = [:]
    private var samplerStates: [SamplerCacheKey: MTLSamplerState] = [:]
    private var imageResolutionCache: [String: MTLTexture] = [:]

    init(device: Device) {
        self.legacyDevice = device
    }

    public var device: MTLDevice {
        legacyDevice.device
    }

    public var commandQueue: MTLCommandQueue {
        legacyDevice.commandQueue
    }

    public var texturePool: TexturePool {
        Shared.shared.defaultTexturePool
    }

    public var textureAllocator: TextureAllocating {
        Shared.shared.defaultTextureAllocator
    }

    public var cvMetalTextureCache: CVMetalTextureCache? {
        legacyDevice.textureCache
    }

    public var externalLibraryProviderIdentifiers: [String] {
        Device.externalLibraryProviderIdentifiers()
    }

    @discardableResult
    public func registerExternalLibraryProvider(_ provider: ExternalMTLLibraryProvider) -> Bool {
        Device.registerExternalLibraryProvider(provider)
    }

    func computePipelineState(for kernel: String) -> MTLComputePipelineState? {
        legacyDevice.pipelineState(for: kernel)
    }

    func setComputePipelineState(_ pipeline: MTLComputePipelineState, for kernel: String) {
        legacyDevice.setPipelineState(pipeline, for: kernel)
    }

    func computePipelineState(for identity: HarbethKernelFunctionIdentity) -> MTLComputePipelineState? {
        legacyDevice.pipelineState(for: identity)
    }

    func setComputePipelineState(_ pipeline: MTLComputePipelineState, for identity: HarbethKernelFunctionIdentity) {
        legacyDevice.setPipelineState(pipeline, for: identity)
    }

    func makeRenderPipelineState(vertex: String,
                                 fragment: String,
                                 pixelFormat: MTLPixelFormat,
                                 sampleCount: Int = 1) throws -> MTLRenderPipelineState {
        try makeRenderPipelineState(
            vertexIdentity: HarbethKernelFunctionIdentity(kind: .render, primaryName: vertex),
            fragmentIdentity: HarbethKernelFunctionIdentity(kind: .render, primaryName: fragment),
            pixelFormat: pixelFormat,
            sampleCount: sampleCount
        )
    }

    func makeRenderPipelineState(vertexIdentity: HarbethKernelFunctionIdentity,
                                 fragmentIdentity: HarbethKernelFunctionIdentity,
                                 pixelFormat: MTLPixelFormat,
                                 sampleCount: Int = 1) throws -> MTLRenderPipelineState {
        try makeRenderPipelineState(
            vertexIdentity: vertexIdentity,
            fragmentIdentity: fragmentIdentity,
            renderPass: .singleColor(pixelFormat: pixelFormat, sampleCount: sampleCount)
        )
    }

    func makeRenderPipelineState(vertexIdentity: HarbethKernelFunctionIdentity,
                                 fragmentIdentity: HarbethKernelFunctionIdentity,
                                 renderPass: HarbethRenderPassContract) throws -> MTLRenderPipelineState {
        let key = RenderPipelineCacheKey(
            vertex: vertexIdentity.fingerprint,
            fragment: fragmentIdentity.fingerprint,
            renderPass: renderPass.fingerprint
        )
        renderPipelineLock.lock()
        if let cached = renderPipelines[key] {
            renderPipelineLock.unlock()
            Shared.shared.performanceMonitor?.recordPipelineCacheLookup("render", hit: true)
            return cached
        }
        renderPipelineLock.unlock()

        let descriptor = MTLRenderPipelineDescriptor()
        for attachment in renderPass.colorAttachments where attachment.index < 8 {
            descriptor.colorAttachments[attachment.index].pixelFormat = Self.pixelFormat(from: attachment.pixelFormat) ?? .invalid
        }
        descriptor.rasterSampleCount = renderPass.sampleCount
        descriptor.vertexFunction = try Device.readMTLFunction(vertexIdentity)
        descriptor.fragmentFunction = try Device.readMTLFunction(fragmentIdentity)
        guard let pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            Shared.shared.performanceMonitor?.recordPipelineCacheLookup("render", hit: false)
            throw HarbethError.renderPipelineState(vertexIdentity.primaryName, fragmentIdentity.primaryName)
        }

        renderPipelineLock.lock()
        renderPipelines[key] = pipelineState
        renderPipelineLock.unlock()
        Shared.shared.performanceMonitor?.recordPipelineCacheLookup("render", hit: false)
        return pipelineState
    }

    private static func pixelFormat(from value: String?) -> MTLPixelFormat? {
        guard let value else { return nil }
        switch value {
        case String(describing: MTLPixelFormat.rgba8Unorm):
            return .rgba8Unorm
        case String(describing: MTLPixelFormat.bgra8Unorm):
            return .bgra8Unorm
        case String(describing: MTLPixelFormat.rgba16Float):
            return .rgba16Float
        case String(describing: MTLPixelFormat.r8Unorm):
            return .r8Unorm
        case String(describing: MTLPixelFormat.rg8Unorm):
            return .rg8Unorm
        case String(describing: MTLPixelFormat.rgba32Float):
            return .rgba32Float
        default:
            return nil
        }
    }

    public func makeSamplerState(minFilter: MTLSamplerMinMagFilter = .linear,
                                 magFilter: MTLSamplerMinMagFilter = .linear,
                                 mipFilter: MTLSamplerMipFilter = .notMipmapped,
                                 sAddressMode: MTLSamplerAddressMode = .clampToEdge,
                                 tAddressMode: MTLSamplerAddressMode = .clampToEdge) -> MTLSamplerState? {
        let key = SamplerCacheKey(
            minFilter: Int(minFilter.rawValue),
            magFilter: Int(magFilter.rawValue),
            mipFilter: Int(mipFilter.rawValue),
            sAddressMode: Int(sAddressMode.rawValue),
            tAddressMode: Int(tAddressMode.rawValue)
        )
        samplerLock.lock()
        if let cached = samplerStates[key] {
            samplerLock.unlock()
            Shared.shared.performanceMonitor?.recordPipelineCacheLookup("sampler", hit: true)
            return cached
        }
        samplerLock.unlock()

        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = minFilter
        descriptor.magFilter = magFilter
        descriptor.mipFilter = mipFilter
        descriptor.sAddressMode = sAddressMode
        descriptor.tAddressMode = tAddressMode
        let state = device.makeSamplerState(descriptor: descriptor)
        samplerLock.lock()
        if let state {
            samplerStates[key] = state
        }
        samplerLock.unlock()
        Shared.shared.performanceMonitor?.recordPipelineCacheLookup("sampler", hit: false)
        return state
    }

    public func makeSamplerState(_ descriptor: ImageSamplerDescriptor) -> MTLSamplerState? {
        makeSamplerState(
            minFilter: descriptor.minFilter,
            magFilter: descriptor.magFilter,
            mipFilter: descriptor.mipFilter,
            sAddressMode: descriptor.sAddressMode,
            tAddressMode: descriptor.tAddressMode
        )
    }

    public func cachedResolvedTexture(for fingerprint: String) -> MTLTexture? {
        imageResolutionLock.lock()
        let texture = imageResolutionCache[fingerprint]
        imageResolutionLock.unlock()
        return texture
    }

    public func storeResolvedTexture(_ texture: MTLTexture, for fingerprint: String) {
        imageResolutionLock.lock()
        imageResolutionCache[fingerprint] = texture
        imageResolutionLock.unlock()
    }

    public func resetCaches() {
        legacyDevice.removePipelineStates()
        legacyDevice.removeFunctionCache()
        renderPipelineLock.lock()
        renderPipelines.removeAll()
        renderPipelineLock.unlock()
        samplerLock.lock()
        samplerStates.removeAll()
        samplerLock.unlock()
        imageResolutionLock.lock()
        imageResolutionCache.removeAll()
        imageResolutionLock.unlock()
    }

    public func debugCacheSnapshot() -> CacheSnapshot {
        renderPipelineLock.lock()
        let renderCount = renderPipelines.count
        renderPipelineLock.unlock()
        samplerLock.lock()
        let samplerCount = samplerStates.count
        samplerLock.unlock()
        imageResolutionLock.lock()
        let imageResolutionCount = imageResolutionCache.count
        imageResolutionLock.unlock()
        return CacheSnapshot(
            functionCacheCount: legacyDevice.functionCacheCount,
            computePipelineCount: legacyDevice.pipelineCount,
            renderPipelineCount: renderCount,
            samplerCount: samplerCount,
            imageResolutionCount: imageResolutionCount,
            hasTexturePool: true,
            hasCVMetalTextureCache: cvMetalTextureCache != nil
        )
    }
}

public extension HarbethContext {
    struct CacheSnapshot: Sendable, Equatable {
        public let functionCacheCount: Int
        public let computePipelineCount: Int
        public let renderPipelineCount: Int
        public let samplerCount: Int
        public let imageResolutionCount: Int
        public let hasTexturePool: Bool
        public let hasCVMetalTextureCache: Bool
    }
}

private struct RenderPipelineCacheKey: Hashable {
    let vertex: String
    let fragment: String
    let renderPass: String
}

private struct SamplerCacheKey: Hashable {
    let minFilter: Int
    let magFilter: Int
    let mipFilter: Int
    let sAddressMode: Int
    let tAddressMode: Int
}
