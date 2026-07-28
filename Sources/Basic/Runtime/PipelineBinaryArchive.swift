//
//  PipelineBinaryArchive.swift
//  Harbeth
//
//  Created by Condy on 2026/7/28.
//

import Foundation
@preconcurrency import Metal

public enum PipelineBinaryArchiveMode: String, Sendable, Codable, Equatable, Hashable {
    case disabled
    case memoryOnly
    case persistent
}

/// Metal pipeline binary archive 配置。持久化 URL 由宿主提供，Harbeth 不猜测业务缓存目录。
public struct PipelineBinaryArchiveConfiguration: Sendable, Codable, Equatable, Hashable {
    public let mode: PipelineBinaryArchiveMode
    public let persistentURL: URL?

    public init(mode: PipelineBinaryArchiveMode, persistentURL: URL? = nil) {
        self.mode = mode
        self.persistentURL = persistentURL
    }

    public static let disabled = PipelineBinaryArchiveConfiguration(mode: .disabled)
    public static let memoryOnly = PipelineBinaryArchiveConfiguration(mode: .memoryOnly)

    public static func persistent(at url: URL) -> PipelineBinaryArchiveConfiguration {
        PipelineBinaryArchiveConfiguration(mode: .persistent, persistentURL: url)
    }
}

public struct PipelineBinaryArchiveSnapshot: Sendable, Codable, Equatable, Hashable {
    public let mode: PipelineBinaryArchiveMode
    public let persistentPath: String?
    public let loadedFromDisk: Bool
    public let registeredComputePipelineCount: Int
    public let registeredRenderPipelineCount: Int
    public let serializationCount: Int
    public let lastError: String?

    public var registeredPipelineCount: Int {
        registeredComputePipelineCount + registeredRenderPipelineCount
    }
}

public struct PipelineBinaryArchiveError: Error, Sendable, Equatable, LocalizedError, HarbethDiagnosticError {
    public let reason: String

    public var errorDescription: String? { reason }
    public var harbethDiagnosticCode: String { "harbeth.pipeline.binary_archive_failed" }
    public var harbethDiagnosticMetadata: [String: String] { ["reason": reason] }
}

final class PipelineBinaryArchiveStore: @unchecked Sendable {
    private let device: MTLDevice
    private let lock = NSLock()
    private var configuration: PipelineBinaryArchiveConfiguration = .disabled
    private var archive: MTLBinaryArchive?
    private var loadedFromDisk = false
    private var registeredComputePipelineCount = 0
    private var registeredRenderPipelineCount = 0
    private var serializationCount = 0
    private var lastError: String?

    init(device: MTLDevice) {
        self.device = device
    }

    func configure(_ configuration: PipelineBinaryArchiveConfiguration) throws {
        try lock.withLock {
            let newArchive: MTLBinaryArchive?
            var newLoadedFromDisk = false
            var newLastError: String?
            switch configuration.mode {
            case .disabled:
                newArchive = nil
            case .memoryOnly:
                newArchive = try makeArchive(loading: nil)
            case .persistent:
                guard let url = configuration.persistentURL, url.isFileURL else {
                    throw PipelineBinaryArchiveError(reason: "Persistent binary archive requires a file URL.")
                }
                if FileManager.default.fileExists(atPath: url.path) {
                    do {
                        newArchive = try makeArchive(loading: url)
                        newLoadedFromDisk = true
                    } catch {
                        newLastError = "Existing archive could not be loaded and was rebuilt: \(error.localizedDescription)"
                        newArchive = try makeArchive(loading: nil)
                    }
                } else {
                    newArchive = try makeArchive(loading: nil)
                }
            }

            self.configuration = configuration
            archive = newArchive
            loadedFromDisk = newLoadedFromDisk
            registeredComputePipelineCount = 0
            registeredRenderPipelineCount = 0
            serializationCount = 0
            lastError = newLastError
        }
    }

    func attach(to descriptor: MTLComputePipelineDescriptor) {
        lock.withLock {
            guard let archive else { return }
            descriptor.binaryArchives = [archive]
            do {
                try archive.addComputePipelineFunctions(descriptor: descriptor)
                registeredComputePipelineCount += 1
            } catch {
                lastError = "Compute pipeline registration failed: \(error.localizedDescription)"
            }
        }
    }

    func attach(to descriptor: MTLRenderPipelineDescriptor) {
        lock.withLock {
            guard let archive else { return }
            descriptor.binaryArchives = [archive]
            do {
                try archive.addRenderPipelineFunctions(descriptor: descriptor)
                registeredRenderPipelineCount += 1
            } catch {
                lastError = "Render pipeline registration failed: \(error.localizedDescription)"
            }
        }
    }

    func serialize(to explicitURL: URL? = nil) throws {
        try lock.withLock {
            guard let archive else {
                throw PipelineBinaryArchiveError(reason: "Binary archive is disabled or has not been configured.")
            }
            let targetURL = explicitURL ?? configuration.persistentURL
            guard let targetURL, targetURL.isFileURL else {
                throw PipelineBinaryArchiveError(reason: "Binary archive serialization requires a file URL.")
            }
            do {
                try FileManager.default.createDirectory(
                    at: targetURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try archive.serialize(to: targetURL)
                serializationCount += 1
                lastError = nil
            } catch {
                lastError = error.localizedDescription
                throw PipelineBinaryArchiveError(reason: "Binary archive serialization failed: \(error.localizedDescription)")
            }
        }
    }

    func snapshot() -> PipelineBinaryArchiveSnapshot {
        lock.withLock {
            PipelineBinaryArchiveSnapshot(
                mode: configuration.mode,
                persistentPath: configuration.persistentURL?.path,
                loadedFromDisk: loadedFromDisk,
                registeredComputePipelineCount: registeredComputePipelineCount,
                registeredRenderPipelineCount: registeredRenderPipelineCount,
                serializationCount: serializationCount,
                lastError: lastError
            )
        }
    }

    private func makeArchive(loading url: URL?) throws -> MTLBinaryArchive {
        let descriptor = MTLBinaryArchiveDescriptor()
        descriptor.url = url
        do {
            return try device.makeBinaryArchive(descriptor: descriptor)
        } catch {
            throw PipelineBinaryArchiveError(reason: "Binary archive creation failed: \(error.localizedDescription)")
        }
    }
}

private extension NSLock {
    func withLock<Result>(_ operation: () throws -> Result) rethrows -> Result {
        lock()
        defer { unlock() }
        return try operation()
    }
}
