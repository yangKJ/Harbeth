//
//  TextureMultiPassExecution.swift
//  Harbeth
//
//  Created by Condy on 2026/7/10.
//

import Foundation
import Metal

/// 多阶段纹理任务的轻量取消令牌。
///
/// 取消只保证在阶段开始前和阶段完成后被观察；正在提交的单个 Metal pass
/// 不会被强行中断，避免返回半写入纹理。
public final class TextureMultiPassCancellationToken {
    private let lock = NSLock()
    private var cancelled = false

    public init() {}

    public func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}

public struct TextureMultiPassResult {
    public let texture: MTLTexture
    public let completedPassCount: Int
    public let diagnostics: TextureRegionDiagnostics
    private let lease: TextureLease?

    init(texture: MTLTexture, completedPassCount: Int, diagnostics: TextureRegionDiagnostics, lease: TextureLease?) {
        self.texture = texture
        self.completedPassCount = completedPassCount
        self.diagnostics = diagnostics
        self.lease = lease
    }

    public func release() {
        lease?.release()
    }
}

/// 在一个明确生命周期内串行执行多个 Harbeth filter pass。
///
/// 中间结果由 `HarbethIO.renderManagedTexture()` 产生的租约管理；成功时只
/// 保留最终租约，失败或取消时释放当前租约，不返回部分结果。
public struct TextureMultiPassExecutor {
    public init() {}

    public func execute(source: MTLTexture,
                        passes: [[C7FilterProtocol]],
                        cancellation: TextureMultiPassCancellationToken? = nil,
                        region: TextureRegionContext? = nil,
                        footprint: SamplingFootprint = .point,
                        readbackOccurred: Bool = false) throws -> TextureMultiPassResult {
        var currentTexture = source
        var currentLease: TextureLease?
        var completedPassCount = 0
        let start = DispatchTime.now().uptimeNanoseconds

        do {
            for pass in passes {
                try checkCancellation(cancellation)
                if pass.isEmpty == false {
                    let managed = try HarbethIO(element: currentTexture, filters: pass)
                        .renderManagedTexture()
                    currentLease?.release()
                    currentTexture = managed.texture
                    currentLease = managed.lease
                }
                completedPassCount += 1
                try checkCancellation(cancellation)
            }
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            return TextureMultiPassResult(
                texture: currentTexture,
                completedPassCount: completedPassCount,
                diagnostics: TextureRegionDiagnostics(
                    logicalExtent: region?.logicalExtent,
                    readRegion: region?.readRegion,
                    writeRegion: region?.writeRegion,
                    footprint: footprint,
                    inputSize: C7Size(texture: source),
                    outputSize: C7Size(texture: currentTexture),
                    inputPixelFormat: UInt64(source.pixelFormat.rawValue),
                    outputPixelFormat: UInt64(currentTexture.pixelFormat.rawValue),
                    allocatedTextureCount: passes.filter { $0.isEmpty == false }.count,
                    estimatedByteCount: estimatedByteCount(source: source, output: currentTexture, passCount: completedPassCount),
                    passCount: completedPassCount,
                    durationMilliseconds: elapsed,
                    readbackOccurred: readbackOccurred,
                    status: .completed
                ),
                lease: currentLease
            )
        } catch {
            currentLease?.release()
            throw error
        }
    }
}

private extension TextureMultiPassExecutor {
    func checkCancellation(_ token: TextureMultiPassCancellationToken?) throws {
        guard token?.isCancelled != true else {
            throw HarbethError.textureMultiPassCancelled
        }
    }

    func estimatedByteCount(source: MTLTexture, output: MTLTexture, passCount: Int) -> Int {
        let sourceBytes = source.width * source.height * bytesPerPixel(for: source.pixelFormat)
        let outputBytes = output.width * output.height * bytesPerPixel(for: output.pixelFormat)
        return sourceBytes + outputBytes * max(passCount, 0)
    }

    func bytesPerPixel(for pixelFormat: MTLPixelFormat) -> Int {
        switch pixelFormat {
        case .rgba16Float, .bgra10_xr, .bgr10_xr, .rgb10a2Unorm:
            return 8
        case .rgba32Float:
            return 16
        case .r16Float, .rg16Float, .r16Unorm, .rg16Unorm:
            return pixelFormat == .r16Float || pixelFormat == .r16Unorm ? 2 : 4
        case .r32Float:
            return 4
        default:
            return 4
        }
    }
}
