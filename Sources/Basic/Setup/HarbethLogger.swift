//
//  HarbethLogger.swift
//  Harbeth
//
//  Created by Condy on 2026/7/21.
//

import Foundation

public enum HarbethLogLevel: Int, Sendable, Comparable {
    case debug = 0
    case info
    case warning
    case error

    public static func < (lhs: HarbethLogLevel, rhs: HarbethLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum HarbethLogOutcome: String, Codable, Equatable, Sendable {
    case observed
    case succeeded
    case failed
    case recovered
    case fallback
    case cancelled
    case degraded
}

public struct HarbethLogEvent: Sendable {
    public let level: HarbethLogLevel
    public let origin: String
    public let category: String
    public let code: String?
    public let outcome: HarbethLogOutcome
    public let message: String
    public let metadata: [String: String]
    public let correlationID: String?
    public let timestamp: Date

    public init(
        level: HarbethLogLevel,
        origin: String = "harbeth",
        category: String,
        code: String? = nil,
        outcome: HarbethLogOutcome = .observed,
        message: String,
        metadata: [String: String] = [:],
        correlationID: String? = nil,
        timestamp: Date = Date()
    ) {
        self.level = level
        self.origin = origin
        self.category = category
        self.code = code
        self.outcome = outcome
        self.message = message
        self.metadata = metadata
        self.correlationID = correlationID
        self.timestamp = timestamp
    }
}

/// Harbeth 默认静默；宿主可按需接入自己的日志系统。
/// Harbeth is silent by default; the host can access its own log system on demand.
public enum HarbethLogger {
    public typealias Handler = @Sendable (HarbethLogEvent) -> Void

    private final class Storage: @unchecked Sendable {
        let lock = NSLock()
        var minimumLevel: HarbethLogLevel = .warning
        var handler: Handler?
    }

    private static let storage = Storage()

    public static var minimumLevel: HarbethLogLevel {
        get {
            storage.lock.lock()
            defer { storage.lock.unlock() }
            return storage.minimumLevel
        }
        set {
            storage.lock.lock()
            storage.minimumLevel = newValue
            storage.lock.unlock()
        }
    }

    public static var handler: Handler? {
        get {
            storage.lock.lock()
            defer { storage.lock.unlock() }
            return storage.handler
        }
        set {
            storage.lock.lock()
            storage.handler = newValue
            storage.lock.unlock()
        }
    }

    public static func log(
        _ level: HarbethLogLevel,
        origin: String = "harbeth",
        category: String,
        code: String? = nil,
        outcome: HarbethLogOutcome = .observed,
        metadata: [String: String] = [:],
        correlationID: String? = nil,
        message: @autoclosure () -> String
    ) {
        storage.lock.lock()
        let minimumLevel = storage.minimumLevel
        let handler = storage.handler
        storage.lock.unlock()
        guard level >= minimumLevel, let handler else { return }
        handler(
            HarbethLogEvent(
                level: level,
                origin: origin,
                category: category,
                code: code,
                outcome: outcome,
                message: message(),
                metadata: metadata,
                correlationID: correlationID
            )
        )
    }
}

public enum HarbethRelease {
    public static let version = "3.0.0"
}

/// 可直接附加到 Issue 的最小运行环境快照，不包含图片或用户内容。
/// The minimum running environment snapshot that can be directly attached to the Issue does not include pictures or user content.
public struct HarbethSupportSnapshot: Codable, Sendable, Equatable {
    public let libraryVersion: String
    public let platform: String
    public let operatingSystem: String
    public let metalDeviceName: String?
    public let performanceMonitoringEnabled: Bool
    public let timestamp: Date

    public init(libraryVersion: String = HarbethRelease.version,
                platform: String,
                operatingSystem: String,
                metalDeviceName: String?,
                performanceMonitoringEnabled: Bool,
                timestamp: Date = Date()) {
        self.libraryVersion = libraryVersion
        self.platform = platform
        self.operatingSystem = operatingSystem
        self.metalDeviceName = metalDeviceName
        self.performanceMonitoringEnabled = performanceMonitoringEnabled
        self.timestamp = timestamp
    }

    public static func capture() -> HarbethSupportSnapshot {
        #if os(iOS)
        let platform = "iOS/iPadOS"
        #elseif os(macOS)
        let platform = "macOS"
        #elseif os(tvOS)
        let platform = "tvOS"
        #else
        let platform = "unsupported"
        #endif
        return HarbethSupportSnapshot(
            platform: platform,
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            metalDeviceName: MTLCreateSystemDefaultDevice()?.name,
            performanceMonitoringEnabled: HarbethContext.shared.enablePerformanceMonitor
        )
    }

    public func json(prettyPrinted: Bool = true) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        let data = try encoder.encode(self)
        guard let value = String(data: data, encoding: .utf8) else {
            throw HarbethError.configurationInvalid("Support snapshot is not valid UTF-8.")
        }
        return value
    }
}
