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
    private var renderPipelines: [RenderPipelineCacheKey: MTLRenderPipelineState] = [:]
    private var samplerStates: [SamplerCacheKey: MTLSamplerState] = [:]

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

    func makeRenderPipelineState(vertex: String,
                                 fragment: String,
                                 pixelFormat: MTLPixelFormat,
                                 sampleCount: Int = 1) throws -> MTLRenderPipelineState {
        let key = RenderPipelineCacheKey(
            vertex: vertex,
            fragment: fragment,
            pixelFormat: pixelFormat.rawValue,
            sampleCount: sampleCount
        )
        renderPipelineLock.lock()
        if let cached = renderPipelines[key] {
            renderPipelineLock.unlock()
            Shared.shared.performanceMonitor?.recordPipelineCacheLookup("render", hit: true)
            return cached
        }
        renderPipelineLock.unlock()

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        descriptor.rasterSampleCount = sampleCount
        descriptor.vertexFunction = try Device.readMTLFunction(vertex)
        descriptor.fragmentFunction = try Device.readMTLFunction(fragment)
        guard let pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            Shared.shared.performanceMonitor?.recordPipelineCacheLookup("render", hit: false)
            throw HarbethError.renderPipelineState(vertex, fragment)
        }

        renderPipelineLock.lock()
        renderPipelines[key] = pipelineState
        renderPipelineLock.unlock()
        Shared.shared.performanceMonitor?.recordPipelineCacheLookup("render", hit: false)
        return pipelineState
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

    public func resetCaches() {
        renderPipelineLock.lock()
        renderPipelines.removeAll()
        renderPipelineLock.unlock()
        samplerLock.lock()
        samplerStates.removeAll()
        samplerLock.unlock()
    }

    public func debugCacheSnapshot() -> CacheSnapshot {
        renderPipelineLock.lock()
        let renderCount = renderPipelines.count
        renderPipelineLock.unlock()
        samplerLock.lock()
        let samplerCount = samplerStates.count
        samplerLock.unlock()
        return CacheSnapshot(
            computePipelineCount: legacyDevice.pipelineCount,
            renderPipelineCount: renderCount,
            samplerCount: samplerCount,
            hasTexturePool: true,
            hasCVMetalTextureCache: cvMetalTextureCache != nil
        )
    }
}

public extension HarbethContext {
    struct CacheSnapshot: Sendable, Equatable {
        public let computePipelineCount: Int
        public let renderPipelineCount: Int
        public let samplerCount: Int
        public let hasTexturePool: Bool
        public let hasCVMetalTextureCache: Bool
    }
}

private struct RenderPipelineCacheKey: Hashable {
    let vertex: String
    let fragment: String
    let pixelFormat: UInt
    let sampleCount: Int
}

private struct SamplerCacheKey: Hashable {
    let minFilter: Int
    let magFilter: Int
    let mipFilter: Int
    let sAddressMode: Int
    let tAddressMode: Int
}
