import XCTest
import AVFoundation
import CoreMedia
import CoreVideo
import ImageIO
import Metal
import QuartzCore
#if canImport(Darwin)
import Darwin
#endif
@testable import Harbeth

private let realtimeBenchmarkSchemaVersion = 2
private let realtimeFrameDeadlineMs = 1_000.0 / 60.0

private struct RouteCacheSnapshot: Codable {
    let texturePoolReservedBytes: Int
    let texturePoolByteLimit: Int
    let heapReservedBytes: Int
    let heapUsedBytes: Int
    let derivedResourceBytes: Int
    let derivedResourceByteLimit: Int
    let derivedResourceHits: Int
    let derivedResourceMisses: Int
    let derivedResourceEvictions: Int
    let derivedResourceRejectedInsertions: Int
    let imageResolutionBytes: Int
    let imageResolutionByteLimit: Int
    let texturePoolCreated: Int
    let texturePoolReused: Int
}

private struct RouteBenchmarkReport: Codable {
    let route: String
    let averageFrameTimeMs: Double
    let p95FrameTimeMs: Double
    let p99FrameTimeMs: Double
    let firstFrameTimeMs: Double
    let stableFrames: Int
    let droppedFrames: Int
    let fallbackCount: Int
    let memoryDeltaBytes: Int64
    let frameCount: Int

    // Schema v2：全部为追加字段，旧消费者仍可读取上面的既有键。
    let measurementScope: String?
    let includesDrawablePresentation: Bool?
    let firstFrameSucceeded: Bool?
    let deadlineMs: Double?
    let submittedFrames: Int?
    let successfulFrames: Int?
    let failedFrames: Int?
    let deadlineMissedFrames: Int?
    let backpressureDroppedFrames: Int?
    let schedulerDroppedFrames: Int?
    let inFlightLimit: Int?
    let maxInFlightFrames: Int?
    let maxBacklogFrames: Int?
    let gpuTimingAvailable: Bool?
    let gpuTimestampedFrames: Int?
    let gpuAverageFrameTimeMs: Double?
    let gpuP95FrameTimeMs: Double?
    let gpuP99FrameTimeMs: Double?
    let gpuTimingSource: String?
    let cacheState: String?
    let cacheBefore: RouteCacheSnapshot?
    let cacheAfter: RouteCacheSnapshot?

    private enum CodingKeys: String, CodingKey {
        case route
        case averageFrameTimeMs = "avgFrameTime"
        case p95FrameTimeMs = "p95"
        case p99FrameTimeMs = "p99"
        case firstFrameTimeMs = "firstFrameTime"
        case stableFrames
        case droppedFrames
        case fallbackCount
        case memoryDeltaBytes
        case frameCount
        case measurementScope
        case includesDrawablePresentation
        case firstFrameSucceeded
        case deadlineMs = "frameDeadlineMs"
        case submittedFrames
        case successfulFrames
        case failedFrames
        case deadlineMissedFrames
        case backpressureDroppedFrames
        case schedulerDroppedFrames
        case inFlightLimit
        case maxInFlightFrames
        case maxBacklogFrames
        case gpuTimingAvailable
        case gpuTimestampedFrames
        case gpuAverageFrameTimeMs = "gpuAvgFrameTime"
        case gpuP95FrameTimeMs = "gpuP95"
        case gpuP99FrameTimeMs = "gpuP99"
        case gpuTimingSource
        case cacheState
        case cacheBefore
        case cacheAfter
    }

    init(
        route: String,
        averageFrameTimeMs: Double,
        p95FrameTimeMs: Double,
        p99FrameTimeMs: Double,
        firstFrameTimeMs: Double,
        stableFrames: Int,
        droppedFrames: Int,
        fallbackCount: Int,
        memoryDeltaBytes: Int64,
        frameCount: Int,
        measurementScope: String? = nil,
        includesDrawablePresentation: Bool? = nil,
        firstFrameSucceeded: Bool? = nil,
        deadlineMs: Double? = nil,
        submittedFrames: Int? = nil,
        successfulFrames: Int? = nil,
        failedFrames: Int? = nil,
        deadlineMissedFrames: Int? = nil,
        backpressureDroppedFrames: Int? = nil,
        schedulerDroppedFrames: Int? = nil,
        inFlightLimit: Int? = nil,
        maxInFlightFrames: Int? = nil,
        maxBacklogFrames: Int? = nil,
        gpuTimingAvailable: Bool? = nil,
        gpuTimestampedFrames: Int? = nil,
        gpuAverageFrameTimeMs: Double? = nil,
        gpuP95FrameTimeMs: Double? = nil,
        gpuP99FrameTimeMs: Double? = nil,
        gpuTimingSource: String? = nil,
        cacheState: String? = nil,
        cacheBefore: RouteCacheSnapshot? = nil,
        cacheAfter: RouteCacheSnapshot? = nil
    ) {
        self.route = route
        self.averageFrameTimeMs = averageFrameTimeMs
        self.p95FrameTimeMs = p95FrameTimeMs
        self.p99FrameTimeMs = p99FrameTimeMs
        self.firstFrameTimeMs = firstFrameTimeMs
        self.stableFrames = stableFrames
        self.droppedFrames = droppedFrames
        self.fallbackCount = fallbackCount
        self.memoryDeltaBytes = memoryDeltaBytes
        self.frameCount = frameCount
        self.measurementScope = measurementScope
        self.includesDrawablePresentation = includesDrawablePresentation
        self.firstFrameSucceeded = firstFrameSucceeded
        self.deadlineMs = deadlineMs
        self.submittedFrames = submittedFrames
        self.successfulFrames = successfulFrames
        self.failedFrames = failedFrames
        self.deadlineMissedFrames = deadlineMissedFrames
        self.backpressureDroppedFrames = backpressureDroppedFrames
        self.schedulerDroppedFrames = schedulerDroppedFrames
        self.inFlightLimit = inFlightLimit
        self.maxInFlightFrames = maxInFlightFrames
        self.maxBacklogFrames = maxBacklogFrames
        self.gpuTimingAvailable = gpuTimingAvailable
        self.gpuTimestampedFrames = gpuTimestampedFrames
        self.gpuAverageFrameTimeMs = gpuAverageFrameTimeMs
        self.gpuP95FrameTimeMs = gpuP95FrameTimeMs
        self.gpuP99FrameTimeMs = gpuP99FrameTimeMs
        self.gpuTimingSource = gpuTimingSource
        self.cacheState = cacheState
        self.cacheBefore = cacheBefore
        self.cacheAfter = cacheAfter
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        route = try container.decode(String.self, forKey: .route)
        averageFrameTimeMs = try container.decode(Double.self, forKey: .averageFrameTimeMs)
        p95FrameTimeMs = try container.decode(Double.self, forKey: .p95FrameTimeMs)
        p99FrameTimeMs = try container.decode(Double.self, forKey: .p99FrameTimeMs)
        firstFrameTimeMs = try container.decode(Double.self, forKey: .firstFrameTimeMs)
        stableFrames = try container.decode(Int.self, forKey: .stableFrames)
        droppedFrames = try container.decode(Int.self, forKey: .droppedFrames)
        fallbackCount = try container.decode(Int.self, forKey: .fallbackCount)
        memoryDeltaBytes = try container.decode(Int64.self, forKey: .memoryDeltaBytes)
        frameCount = try container.decode(Int.self, forKey: .frameCount)
        measurementScope = try container.decodeIfPresent(String.self, forKey: .measurementScope)
        includesDrawablePresentation = try container.decodeIfPresent(Bool.self, forKey: .includesDrawablePresentation)
        firstFrameSucceeded = try container.decodeIfPresent(Bool.self, forKey: .firstFrameSucceeded)
        deadlineMs = try container.decodeIfPresent(Double.self, forKey: .deadlineMs)
        submittedFrames = try container.decodeIfPresent(Int.self, forKey: .submittedFrames)
        successfulFrames = try container.decodeIfPresent(Int.self, forKey: .successfulFrames)
        failedFrames = try container.decodeIfPresent(Int.self, forKey: .failedFrames)
        deadlineMissedFrames = try container.decodeIfPresent(Int.self, forKey: .deadlineMissedFrames)
        backpressureDroppedFrames = try container.decodeIfPresent(Int.self, forKey: .backpressureDroppedFrames)
        schedulerDroppedFrames = try container.decodeIfPresent(Int.self, forKey: .schedulerDroppedFrames)
        inFlightLimit = try container.decodeIfPresent(Int.self, forKey: .inFlightLimit)
        maxInFlightFrames = try container.decodeIfPresent(Int.self, forKey: .maxInFlightFrames)
        maxBacklogFrames = try container.decodeIfPresent(Int.self, forKey: .maxBacklogFrames)
        gpuTimingAvailable = try container.decodeIfPresent(Bool.self, forKey: .gpuTimingAvailable)
        gpuTimestampedFrames = try container.decodeIfPresent(Int.self, forKey: .gpuTimestampedFrames)
        gpuAverageFrameTimeMs = try container.decodeIfPresent(Double.self, forKey: .gpuAverageFrameTimeMs)
        gpuP95FrameTimeMs = try container.decodeIfPresent(Double.self, forKey: .gpuP95FrameTimeMs)
        gpuP99FrameTimeMs = try container.decodeIfPresent(Double.self, forKey: .gpuP99FrameTimeMs)
        gpuTimingSource = try container.decodeIfPresent(String.self, forKey: .gpuTimingSource)
        cacheState = try container.decodeIfPresent(String.self, forKey: .cacheState)
        cacheBefore = try container.decodeIfPresent(RouteCacheSnapshot.self, forKey: .cacheBefore)
        cacheAfter = try container.decodeIfPresent(RouteCacheSnapshot.self, forKey: .cacheAfter)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(route, forKey: .route)
        try container.encode(averageFrameTimeMs, forKey: .averageFrameTimeMs)
        try container.encode(p95FrameTimeMs, forKey: .p95FrameTimeMs)
        try container.encode(p99FrameTimeMs, forKey: .p99FrameTimeMs)
        try container.encode(firstFrameTimeMs, forKey: .firstFrameTimeMs)
        try container.encode(stableFrames, forKey: .stableFrames)
        try container.encode(droppedFrames, forKey: .droppedFrames)
        try container.encode(fallbackCount, forKey: .fallbackCount)
        try container.encode(memoryDeltaBytes, forKey: .memoryDeltaBytes)
        try container.encode(frameCount, forKey: .frameCount)
        try container.encodeIfPresent(measurementScope, forKey: .measurementScope)
        try container.encodeIfPresent(includesDrawablePresentation, forKey: .includesDrawablePresentation)
        try container.encodeIfPresent(firstFrameSucceeded, forKey: .firstFrameSucceeded)
        try container.encodeIfPresent(deadlineMs, forKey: .deadlineMs)
        try container.encodeIfPresent(submittedFrames, forKey: .submittedFrames)
        try container.encodeIfPresent(successfulFrames, forKey: .successfulFrames)
        try container.encodeIfPresent(failedFrames, forKey: .failedFrames)
        try container.encodeIfPresent(deadlineMissedFrames, forKey: .deadlineMissedFrames)
        try container.encodeIfPresent(backpressureDroppedFrames, forKey: .backpressureDroppedFrames)
        try container.encodeIfPresent(schedulerDroppedFrames, forKey: .schedulerDroppedFrames)
        try container.encodeIfPresent(inFlightLimit, forKey: .inFlightLimit)
        try container.encodeIfPresent(maxInFlightFrames, forKey: .maxInFlightFrames)
        try container.encodeIfPresent(maxBacklogFrames, forKey: .maxBacklogFrames)
        try container.encodeIfPresent(gpuTimingAvailable, forKey: .gpuTimingAvailable)
        try container.encodeIfPresent(gpuTimestampedFrames, forKey: .gpuTimestampedFrames)
        try encodeNullable(gpuAverageFrameTimeMs, forKey: .gpuAverageFrameTimeMs, into: &container)
        try encodeNullable(gpuP95FrameTimeMs, forKey: .gpuP95FrameTimeMs, into: &container)
        try encodeNullable(gpuP99FrameTimeMs, forKey: .gpuP99FrameTimeMs, into: &container)
        try encodeNullable(gpuTimingSource, forKey: .gpuTimingSource, into: &container)
        try encodeNullable(cacheState, forKey: .cacheState, into: &container)
        try encodeNullable(cacheBefore, forKey: .cacheBefore, into: &container)
        try encodeNullable(cacheAfter, forKey: .cacheAfter, into: &container)
    }

    private func encodeNullable<Value: Encodable>(
        _ value: Value?,
        forKey key: CodingKeys,
        into container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        if let value {
            try container.encode(value, forKey: key)
        } else {
            try container.encodeNil(forKey: key)
        }
    }
}

private struct BenchmarkRunReport: Codable {
    let schemaVersion: Int
    let createdAt: Date
    let deviceName: String
    let frameCount: Int
    let warmupCount: Int
    let routes: [RouteBenchmarkReport]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case createdAt
        case deviceName
        case frameCount
        case warmupCount
        case routes
    }

    init(
        schemaVersion: Int = realtimeBenchmarkSchemaVersion,
        createdAt: Date,
        deviceName: String,
        frameCount: Int,
        warmupCount: Int,
        routes: [RouteBenchmarkReport]
    ) {
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.deviceName = deviceName
        self.frameCount = frameCount
        self.warmupCount = warmupCount
        self.routes = routes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        deviceName = try container.decode(String.self, forKey: .deviceName)
        frameCount = try container.decode(Int.self, forKey: .frameCount)
        warmupCount = try container.decode(Int.self, forKey: .warmupCount)
        routes = try container.decode([RouteBenchmarkReport].self, forKey: .routes)
    }
}

private struct TimingDistribution: Equatable, Sendable {
    let average: Double
    let p95: Double
    let p99: Double

    static func make(values: [Double]) -> TimingDistribution {
        guard values.isEmpty == false else {
            return TimingDistribution(average: 0, p95: 0, p99: 0)
        }
        let finiteValues = values.filter(\.isFinite)
        guard finiteValues.isEmpty == false else {
            return TimingDistribution(average: 0, p95: 0, p99: 0)
        }
        let sorted = finiteValues.sorted()
        return TimingDistribution(
            average: finiteValues.reduce(0, +) / Double(finiteValues.count),
            p95: percentile(sortedValues: sorted, percentile: 0.95),
            p99: percentile(sortedValues: sorted, percentile: 0.99)
        )
    }

    private static func percentile(sortedValues: [Double], percentile: Double) -> Double {
        guard sortedValues.isEmpty == false else { return 0 }
        let rank = max(Int(ceil(percentile * Double(sortedValues.count))), 1)
        return sortedValues[min(rank - 1, sortedValues.count - 1)]
    }
}

private struct RealtimeFrameContext: Sendable {
    let frameIndex: Int
    let slotIndex: Int
    let scheduledAt: TimeInterval
    let deadlineAt: TimeInterval
}

private struct RealtimeRouteCompletion: Sendable {
    let succeeded: Bool
    let gpuDurationMs: Double?

    static func success(gpuDurationMs: Double?) -> RealtimeRouteCompletion {
        RealtimeRouteCompletion(succeeded: true, gpuDurationMs: gpuDurationMs)
    }

    static let failure = RealtimeRouteCompletion(succeeded: false, gpuDurationMs: nil)
}

private struct RealtimeFrameSample: Sendable {
    let endToEndTimeMs: Double
    let completion: RealtimeRouteCompletion
}

private struct RealtimeMeasurementSnapshot: Sendable {
    let frameCount: Int
    let submittedFrames: Int
    let backpressureDroppedFrames: Int
    let schedulerDroppedFrames: Int
    let timedOutFrames: Int
    let maxInFlightFrames: Int
    let maxBacklogFrames: Int
    let samples: [RealtimeFrameSample]
}

private struct RealtimeRouteStatistics: Sendable {
    let endToEndDistribution: TimingDistribution
    let gpuDistribution: TimingDistribution?
    let stableFrames: Int
    let droppedFrames: Int
    let successfulFrames: Int
    let failedFrames: Int
    let deadlineMissedFrames: Int
    let gpuTimestampedFrames: Int

    init(snapshot: RealtimeMeasurementSnapshot, deadlineMs: Double) {
        let successfulSamples = snapshot.samples.filter(\.completion.succeeded)
        let failedCallbackCount = snapshot.samples.count - successfulSamples.count
        let onTimeSamples = successfulSamples.filter { $0.endToEndTimeMs <= deadlineMs }
        let lateSamples = successfulSamples.filter { $0.endToEndTimeMs > deadlineMs }
        let gpuValues = successfulSamples.compactMap(\.completion.gpuDurationMs).filter { $0.isFinite && $0 > 0 }

        endToEndDistribution = TimingDistribution.make(values: successfulSamples.map(\.endToEndTimeMs))
        gpuDistribution = gpuValues.isEmpty ? nil : TimingDistribution.make(values: gpuValues)
        stableFrames = onTimeSamples.count
        successfulFrames = successfulSamples.count
        failedFrames = failedCallbackCount + snapshot.timedOutFrames
        deadlineMissedFrames = lateSamples.count
        gpuTimestampedFrames = gpuValues.count
        droppedFrames = snapshot.backpressureDroppedFrames
            + snapshot.schedulerDroppedFrames
            + failedFrames
            + deadlineMissedFrames
    }
}

private typealias RealtimeRouteSubmit = @Sendable (
    RealtimeFrameContext,
    @escaping @Sendable (RealtimeRouteCompletion) -> Void,
    @escaping @Sendable (Int) -> Void
) -> Void

private struct RealtimeRouteDefinition: Sendable {
    let tag: String
    let measurementScope: String
    let includesDrawablePresentation: Bool
    let expectsGPUTimestamps: Bool
    let submit: RealtimeRouteSubmit
}

private final class RealtimeRouteCadenceRunner: @unchecked Sendable {
    private let frameCount: Int
    private let deadlineSeconds: TimeInterval
    private let inFlightLimit: Int
    private let submit: RealtimeRouteSubmit
    private let schedulerQueue = DispatchQueue(label: "com.harbeth.tests.realtime-route-cadence", qos: .userInteractive)
    private let lock = NSLock()

    private var timer: DispatchSourceTimer?
    private var completion: (@Sendable (RealtimeMeasurementSnapshot) -> Void)?
    private var startTime: TimeInterval = 0
    private var startUptimeNanoseconds: UInt64 = 0
    private var nextFrameIndex = 0
    private var submittedFrames = 0
    private var backpressureDroppedFrames = 0
    private var schedulerDroppedFrames = 0
    private var timedOutFrames = 0
    private var maxInFlightFrames = 0
    private var maxBacklogFrames = 0
    private var availableSlots: [Int]
    private var activeContextsBySlot: [Int: RealtimeFrameContext] = [:]
    private var samples: [RealtimeFrameSample] = []
    private var finished = false

    init(frameCount: Int, deadlineSeconds: TimeInterval, inFlightLimit: Int, submit: @escaping RealtimeRouteSubmit) {
        self.frameCount = frameCount
        self.deadlineSeconds = deadlineSeconds
        self.inFlightLimit = inFlightLimit
        self.submit = submit
        self.availableSlots = Array(0..<inFlightLimit)
    }

    static func measure(
        frameCount: Int,
        deadlineSeconds: TimeInterval,
        inFlightLimit: Int,
        submit: @escaping RealtimeRouteSubmit
    ) async -> RealtimeMeasurementSnapshot {
        await withCheckedContinuation { continuation in
            let runner = RealtimeRouteCadenceRunner(
                frameCount: frameCount,
                deadlineSeconds: deadlineSeconds,
                inFlightLimit: inFlightLimit,
                submit: submit
            )
            runner.start { snapshot in continuation.resume(returning: snapshot) }
        }
    }

    private func start(completion: @escaping @Sendable (RealtimeMeasurementSnapshot) -> Void) {
        guard frameCount > 0 else {
            completion(
                RealtimeMeasurementSnapshot(
                    frameCount: 0,
                    submittedFrames: 0,
                    backpressureDroppedFrames: 0,
                    schedulerDroppedFrames: 0,
                    timedOutFrames: 0,
                    maxInFlightFrames: 0,
                    maxBacklogFrames: 0,
                    samples: []
                )
            )
            return
        }

        lock.lock()
        self.completion = completion
        startTime = CACurrentMediaTime()
        startUptimeNanoseconds = DispatchTime.now().uptimeNanoseconds
        let timer = DispatchSource.makeTimerSource(queue: schedulerQueue)
        self.timer = timer
        lock.unlock()

        timer.schedule(deadline: .now(), leeway: .microseconds(100))
        timer.setEventHandler { [self] in submitNextFrame() }
        timer.resume()

        let timeoutSeconds = max(Double(frameCount) * deadlineSeconds + 30, 30)
        schedulerQueue.asyncAfter(deadline: .now() + timeoutSeconds) { [weak self] in
            self?.finishIfReady(forceTimeout: true)
        }
    }

    private func submitNextFrame() {
        var context: RealtimeFrameContext?
        var shouldScheduleNextFrame = false

        lock.lock()
        while finished == false, nextFrameIndex < frameCount {
            let candidateIndex = nextFrameIndex
            let scheduledAt = startTime + Double(candidateIndex) * deadlineSeconds
            let deadlineAt = scheduledAt + deadlineSeconds
            if CACurrentMediaTime() > deadlineAt {
                schedulerDroppedFrames += 1
                nextFrameIndex += 1
                continue
            }

            nextFrameIndex += 1
            if availableSlots.isEmpty {
                backpressureDroppedFrames += 1
            } else {
                let slotIndex = availableSlots.removeFirst()
                let admitted = RealtimeFrameContext(
                    frameIndex: candidateIndex,
                    slotIndex: slotIndex,
                    scheduledAt: scheduledAt,
                    deadlineAt: deadlineAt
                )
                activeContextsBySlot[slotIndex] = admitted
                submittedFrames += 1
                maxInFlightFrames = max(maxInFlightFrames, activeContextsBySlot.count)
                context = admitted
            }
            break
        }
        shouldScheduleNextFrame = finished == false && nextFrameIndex < frameCount
        lock.unlock()

        if let context {
            submit(
                context,
                { [weak self] result in self?.recordCompletion(context: context, result: result) },
                { [weak self] depth in self?.recordBacklog(depth) }
            )
        }
        if shouldScheduleNextFrame { scheduleNextFrame() }
        finishIfReady()
    }

    private func scheduleNextFrame() {
        lock.lock()
        guard finished == false, nextFrameIndex < frameCount, let timer else {
            lock.unlock()
            return
        }
        let intervalNanoseconds = UInt64((deadlineSeconds * 1_000_000_000).rounded())
        let targetUptime = startUptimeNanoseconds + UInt64(nextFrameIndex) * intervalNanoseconds
        lock.unlock()

        timer.schedule(
            deadline: DispatchTime(uptimeNanoseconds: targetUptime),
            leeway: .microseconds(100)
        )
    }

    private func recordBacklog(_ depth: Int) {
        lock.lock()
        if finished == false { maxBacklogFrames = max(maxBacklogFrames, max(depth, 0)) }
        lock.unlock()
    }

    private func recordCompletion(context: RealtimeFrameContext, result: RealtimeRouteCompletion) {
        let completedAt = CACurrentMediaTime()
        lock.lock()
        guard finished == false, activeContextsBySlot[context.slotIndex]?.frameIndex == context.frameIndex else {
            lock.unlock()
            return
        }
        activeContextsBySlot.removeValue(forKey: context.slotIndex)
        availableSlots.append(context.slotIndex)
        samples.append(
            RealtimeFrameSample(
                endToEndTimeMs: max((completedAt - context.scheduledAt) * 1_000, 0),
                completion: result
            )
        )
        lock.unlock()
        finishIfReady()
    }

    private func finishIfReady(forceTimeout: Bool = false) {
        var payload: (RealtimeMeasurementSnapshot, @Sendable (RealtimeMeasurementSnapshot) -> Void, DispatchSourceTimer)?

        lock.lock()
        if finished == false {
            if forceTimeout {
                schedulerDroppedFrames += max(frameCount - nextFrameIndex, 0)
                nextFrameIndex = frameCount
                timedOutFrames += activeContextsBySlot.count
                activeContextsBySlot.removeAll()
                availableSlots = Array(0..<inFlightLimit)
            }

            if nextFrameIndex >= frameCount, activeContextsBySlot.isEmpty, let completion, let timer {
                finished = true
                let snapshot = RealtimeMeasurementSnapshot(
                    frameCount: frameCount,
                    submittedFrames: submittedFrames,
                    backpressureDroppedFrames: backpressureDroppedFrames,
                    schedulerDroppedFrames: schedulerDroppedFrames,
                    timedOutFrames: timedOutFrames,
                    maxInFlightFrames: maxInFlightFrames,
                    maxBacklogFrames: maxBacklogFrames,
                    samples: samples
                )
                self.completion = nil
                self.timer = nil
                payload = (snapshot, completion, timer)
            }
        }
        lock.unlock()

        if let payload {
            payload.2.setEventHandler {}
            payload.2.cancel()
            payload.1(payload.0)
        }
    }
}

final class RealtimeRouteBenchmarkTests: XCTestCase {
    @MainActor
    func testRealtimeFrameRouteBenchmark5Paths() async {
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTFail("Metal device is unavailable in this environment.")
            return
        }

        do {
            let benchmark = RealtimeRouteBenchmarker(device: device)
            let reports = try await benchmark.runAll()
            XCTAssertEqual(reports.map(\.route), [
                "sampleBuffer -> ImageNode -> RenderView.display",
                "pixelBuffer -> ImageNode -> RenderView.display",
                "texture -> ImageNode -> RenderView.display",
                "HarbethIO -> output",
                "RenderView.texture",
            ])

            let runReport = BenchmarkRunReport(
                createdAt: Date(),
                deviceName: device.name,
                frameCount: benchmark.benchmarkFrameCount,
                warmupCount: benchmark.benchmarkWarmupCount,
                routes: reports
            )
            let outputURL = try benchmark.write(runReport: runReport)
            let data = try Data(contentsOf: outputURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(BenchmarkRunReport.self, from: data)

            XCTAssertEqual(decoded.schemaVersion, realtimeBenchmarkSchemaVersion)
            XCTAssertEqual(decoded.routes.count, 5)
            for (index, route) in decoded.routes.enumerated() {
                XCTAssertGreaterThanOrEqual(route.averageFrameTimeMs, 0)
                XCTAssertGreaterThanOrEqual(route.p95FrameTimeMs, 0)
                XCTAssertGreaterThanOrEqual(route.p99FrameTimeMs, 0)
                XCTAssertGreaterThanOrEqual(route.firstFrameTimeMs, 0)
                XCTAssertGreaterThanOrEqual(route.droppedFrames, 0)
                XCTAssertGreaterThanOrEqual(route.fallbackCount, 0)
                XCTAssertNotNil(route.cacheBefore)
                XCTAssertNotNil(route.cacheAfter)
                XCTAssertGreaterThanOrEqual(route.memoryDeltaBytes, 0)
                XCTAssertGreaterThanOrEqual(route.stableFrames, 0)
                XCTAssertEqual(route.stableFrames + route.droppedFrames, route.frameCount)
                XCTAssertEqual(route.deadlineMs ?? 0, realtimeFrameDeadlineMs, accuracy: 0.000_001)
                XCTAssertEqual(
                    (route.submittedFrames ?? 0)
                        + (route.backpressureDroppedFrames ?? 0)
                        + (route.schedulerDroppedFrames ?? 0),
                    route.frameCount
                )
                XCTAssertEqual(
                    (route.successfulFrames ?? 0) + (route.failedFrames ?? 0),
                    route.submittedFrames
                )
                let deadlineMissedFrames = route.deadlineMissedFrames ?? 0
                let failedFrames = route.failedFrames ?? 0
                let backpressureDroppedFrames = route.backpressureDroppedFrames ?? 0
                let schedulerDroppedFrames = route.schedulerDroppedFrames ?? 0
                let accountedDroppedFrames = deadlineMissedFrames
                    + failedFrames
                    + backpressureDroppedFrames
                    + schedulerDroppedFrames
                XCTAssertEqual(accountedDroppedFrames, route.droppedFrames)
                XCTAssertLessThanOrEqual(route.maxInFlightFrames ?? 0, route.inFlightLimit ?? 0)
                XCTAssertGreaterThan(route.successfulFrames ?? 0, 0)
                XCTAssertEqual(route.includesDrawablePresentation, false)

                if index < 4 {
                    XCTAssertEqual(route.gpuTimingAvailable, true)
                    XCTAssertGreaterThan(route.gpuTimestampedFrames ?? 0, 0)
                    XCTAssertNotNil(route.gpuAverageFrameTimeMs)
                } else {
                    XCTAssertEqual(route.gpuTimingAvailable, false)
                    XCTAssertEqual(route.gpuTimestampedFrames, 0)
                    XCTAssertNil(route.gpuAverageFrameTimeMs)
                }
            }

            for report in reports {
                let avg = String(format: "%.3f", report.averageFrameTimeMs)
                let p95 = String(format: "%.3f", report.p95FrameTimeMs)
                let p99 = String(format: "%.3f", report.p99FrameTimeMs)
                let first = String(format: "%.3f", report.firstFrameTimeMs)
                let gpu = report.gpuAverageFrameTimeMs.map { String(format: "%.3f", $0) } ?? "n/a"
                print(
                    "[RouteBenchmark] \(report.route) e2e.avg=\(avg)ms e2e.p95=\(p95)ms e2e.p99=\(p99)ms first=\(first)ms gpu.avg=\(gpu)ms deadline=16.67ms dropped=\(report.droppedFrames) deadlineMissed=\(report.deadlineMissedFrames ?? 0) backpressure=\(report.backpressureDroppedFrames ?? 0) inFlight.max=\(report.maxInFlightFrames ?? 0) backlog.max=\(report.maxBacklogFrames ?? 0) fallback=\(report.fallbackCount) memory=\(report.memoryDeltaBytes)B stable=\(report.stableFrames)/\(report.frameCount)"
                )
            }
            print("[RouteBenchmark JSON] \(outputURL.path)")
        } catch {
            XCTFail("Benchmark failed: \(error)")
        }
    }
}

final class RealtimeRouteBenchmarkContractTests: XCTestCase {
    func testMetricCalculationSeparatesDeadlineFailureAndAdmissionDrops() {
        let deadline = realtimeFrameDeadlineMs
        let snapshot = RealtimeMeasurementSnapshot(
            frameCount: 6,
            submittedFrames: 4,
            backpressureDroppedFrames: 1,
            schedulerDroppedFrames: 1,
            timedOutFrames: 0,
            maxInFlightFrames: 3,
            maxBacklogFrames: 2,
            samples: [
                RealtimeFrameSample(
                    endToEndTimeMs: 10,
                    completion: .success(gpuDurationMs: 2)
                ),
                RealtimeFrameSample(
                    endToEndTimeMs: deadline,
                    completion: .success(gpuDurationMs: 3)
                ),
                RealtimeFrameSample(
                    endToEndTimeMs: deadline + 0.001,
                    completion: .success(gpuDurationMs: nil)
                ),
                RealtimeFrameSample(endToEndTimeMs: 4, completion: .failure),
            ]
        )

        let metrics = RealtimeRouteStatistics(snapshot: snapshot, deadlineMs: deadline)

        XCTAssertEqual(metrics.stableFrames, 2)
        XCTAssertEqual(metrics.successfulFrames, 3)
        XCTAssertEqual(metrics.failedFrames, 1)
        XCTAssertEqual(metrics.deadlineMissedFrames, 1)
        XCTAssertEqual(metrics.droppedFrames, 4)
        XCTAssertEqual(metrics.gpuTimestampedFrames, 2)
        XCTAssertEqual(metrics.gpuDistribution, TimingDistribution(average: 2.5, p95: 3, p99: 3))
    }

    func testTimingDistributionUsesNearestRankAndIgnoresInputOrder() {
        let values = Array(1...100).map(Double.init).reversed()
        let distribution = TimingDistribution.make(values: Array(values))

        XCTAssertEqual(distribution.average, 50.5)
        XCTAssertEqual(distribution.p95, 95)
        XCTAssertEqual(distribution.p99, 99)
        XCTAssertEqual(TimingDistribution.make(values: [2, 1]).p95, 2)
        XCTAssertEqual(TimingDistribution.make(values: []), TimingDistribution(average: 0, p95: 0, p99: 0))
    }

    func testSchemaV2DecoderReadsLegacyJSONWithoutInventingEvidence() throws {
        let legacyJSON = """
        {
          "createdAt": "2026-07-08T16:00:00Z",
          "deviceName": "Legacy GPU",
          "frameCount": 300,
          "warmupCount": 20,
          "routes": [{
            "route": "RenderView.texture",
            "avgFrameTime": 0.02,
            "p95": 0.03,
            "p99": 0.04,
            "firstFrameTime": 0.05,
            "stableFrames": 300,
            "droppedFrames": 0,
            "fallbackCount": 0,
            "memoryDeltaBytes": 0,
            "frameCount": 300
          }]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(BenchmarkRunReport.self, from: Data(legacyJSON.utf8))

        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.routes.first?.route, "RenderView.texture")
        XCTAssertNil(decoded.routes.first?.deadlineMs)
        XCTAssertNil(decoded.routes.first?.gpuTimingAvailable)
        XCTAssertNil(decoded.routes.first?.gpuAverageFrameTimeMs)
    }

    func testLegacyDecoderIgnoresSchemaV2AdditiveFields() throws {
        let report = RouteBenchmarkReport(
            route: "HarbethIO -> output",
            averageFrameTimeMs: 2,
            p95FrameTimeMs: 3,
            p99FrameTimeMs: 4,
            firstFrameTimeMs: 5,
            stableFrames: 299,
            droppedFrames: 1,
            fallbackCount: 0,
            memoryDeltaBytes: 64,
            frameCount: 300,
            measurementScope: "processingAndOutputDelivery",
            includesDrawablePresentation: false,
            firstFrameSucceeded: true,
            deadlineMs: realtimeFrameDeadlineMs,
            submittedFrames: 300,
            successfulFrames: 300,
            failedFrames: 0,
            deadlineMissedFrames: 1,
            backpressureDroppedFrames: 0,
            schedulerDroppedFrames: 0,
            inFlightLimit: 6,
            maxInFlightFrames: 2,
            maxBacklogFrames: 0,
            gpuTimingAvailable: true,
            gpuTimestampedFrames: 300,
            gpuAverageFrameTimeMs: 1,
            gpuP95FrameTimeMs: 1.5,
            gpuP99FrameTimeMs: 1.8,
            gpuTimingSource: "MTLCommandBuffer.gpuStartTime/gpuEndTime"
        )
        let run = BenchmarkRunReport(
            createdAt: Date(timeIntervalSince1970: 0),
            deviceName: "GPU",
            frameCount: 300,
            warmupCount: 20,
            routes: [report]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(run)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let legacy = try decoder.decode(LegacyBenchmarkRunReport.self, from: data)

        XCTAssertEqual(legacy.frameCount, 300)
        XCTAssertEqual(legacy.routes.first?.averageFrameTimeMs, 2)
        XCTAssertEqual(legacy.routes.first?.stableFrames, 299)
        XCTAssertEqual(legacy.routes.first?.droppedFrames, 1)
    }

    func testUnavailableGPUTimingEncodesAsExplicitNull() throws {
        let report = RouteBenchmarkReport(
            route: "RenderView.texture",
            averageFrameTimeMs: 1,
            p95FrameTimeMs: 2,
            p99FrameTimeMs: 3,
            firstFrameTimeMs: 1,
            stableFrames: 300,
            droppedFrames: 0,
            fallbackCount: 0,
            memoryDeltaBytes: 0,
            frameCount: 300,
            measurementScope: "hostAssignmentOnly",
            includesDrawablePresentation: false,
            firstFrameSucceeded: true,
            deadlineMs: realtimeFrameDeadlineMs,
            submittedFrames: 300,
            successfulFrames: 300,
            failedFrames: 0,
            deadlineMissedFrames: 0,
            backpressureDroppedFrames: 0,
            schedulerDroppedFrames: 0,
            inFlightLimit: 6,
            maxInFlightFrames: 1,
            maxBacklogFrames: 0,
            gpuTimingAvailable: false,
            gpuTimestampedFrames: 0
        )
        let data = try JSONEncoder().encode(report)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertTrue(object["gpuAvgFrameTime"] is NSNull)
        XCTAssertTrue(object["gpuP95"] is NSNull)
        XCTAssertTrue(object["gpuP99"] is NSNull)
        XCTAssertTrue(object["gpuTimingSource"] is NSNull)
    }
}

@MainActor
private struct RealtimeRouteBenchmarker {
    private let device: MTLDevice
    private let frameCount = 300
    private let warmupCount = 20
    private let inputWidth = 720
    private let inputHeight = 1280
    private let inFlightLimit = 6
    private let filters: [C7FilterProtocol] = [
        C7ColorMatrix4x4(matrix: Matrix4x4.Color.blackAndWhite),
        C7GaussianBlur(radius: 1.2),
    ]

    init(device: MTLDevice) {
        self.device = device
    }

    var benchmarkFrameCount: Int { frameCount }
    var benchmarkWarmupCount: Int { warmupCount }

    func runAll() async throws -> [RouteBenchmarkReport] {
        let sampleInputs = try makeSampleBufferInputs(format: kCVPixelFormatType_32BGRA, count: inFlightLimit)
        let pixelBuffers = sampleInputs.map(\.pixelBuffer)
        let textures = try (0..<inFlightLimit).map { _ in
            try textureInput(width: inputWidth, height: inputHeight)
        }

        let context = HarbethContext.shared
        let enabledMonitorForBenchmark = context.enablePerformanceMonitor == false
        if enabledMonitorForBenchmark {
            context.enablePerformanceMonitor = true
            var configuration = PerformanceMonitor.Configuration()
            configuration.enabled = true
            configuration.logLevel = .error
            configuration.maxStoredMetrics = 256
            context.performanceMonitor.configure(configuration)
        }
        defer {
            context.performanceMonitor.clearAllMetrics()
            if enabledMonitorForBenchmark { context.enablePerformanceMonitor = false }
        }

        let sampleRouteState = ImageNodeBenchmarkRouteState(
            sources: .sampleBuffers(sampleInputs),
            filters: filters
        )
        let pixelRouteState = ImageNodeBenchmarkRouteState(
            sources: .pixelBuffers(pixelBuffers),
            filters: filters
        )
        let textureRouteState = ImageNodeBenchmarkRouteState(
            sources: .textures(textures),
            filters: filters
        )
        let harbethIOState = HarbethIOBenchmarkRouteState(pixelBuffers: pixelBuffers, filters: filters)
        let renderViewState = RenderViewAssignmentBenchmarkRouteState(textures: textures)

        let sampleRoute = makeRoute(
            tag: "sampleBuffer -> ImageNode -> RenderView.display",
            measurementScope: "processingAndHostHandoff",
            expectsGPUTimestamps: true,
            state: sampleRouteState
        )
        let pixelRoute = makeRoute(
            tag: "pixelBuffer -> ImageNode -> RenderView.display",
            measurementScope: "processingAndHostHandoff",
            expectsGPUTimestamps: true,
            state: pixelRouteState
        )
        let textureRoute = makeRoute(
            tag: "texture -> ImageNode -> RenderView.display",
            measurementScope: "processingAndHostHandoff",
            expectsGPUTimestamps: true,
            state: textureRouteState
        )
        let harbethIORoute = RealtimeRouteDefinition(
            tag: "HarbethIO -> output",
            measurementScope: "processingAndOutputDelivery",
            includesDrawablePresentation: false,
            expectsGPUTimestamps: true,
            submit: { context, completion, backlog in
                Task { @MainActor in harbethIOState.submit(context, completion: completion, observeBacklog: backlog) }
            }
        )
        let renderViewRoute = RealtimeRouteDefinition(
            tag: "RenderView.texture",
            measurementScope: "hostAssignmentOnly",
            includesDrawablePresentation: false,
            expectsGPUTimestamps: false,
            submit: { context, completion, backlog in
                Task { @MainActor in renderViewState.submit(context, completion: completion, observeBacklog: backlog) }
            }
        )

        PixelBufferPool.resetRealtimePoolMetrics()
        var baselineFallback = PixelBufferPool.realtimeAllocationFallbackCount
        let sampleReport = await benchmark(
            route: sampleRoute,
            fallbackCount: { max(0, PixelBufferPool.realtimeAllocationFallbackCount - baselineFallback) }
        )

        PixelBufferPool.resetRealtimePoolMetrics()
        baselineFallback = PixelBufferPool.realtimeAllocationFallbackCount
        let pixelReport = await benchmark(
            route: pixelRoute,
            fallbackCount: { max(0, PixelBufferPool.realtimeAllocationFallbackCount - baselineFallback) }
        )

        let textureReport = await benchmark(route: textureRoute, fallbackCount: { 0 })
        let harbethIOReport = await benchmark(route: harbethIORoute, fallbackCount: { 0 })
        let renderViewReport = await benchmark(route: renderViewRoute, fallbackCount: { 0 })
        return [sampleReport, pixelReport, textureReport, harbethIOReport, renderViewReport]
    }

    private func makeRoute(
        tag: String,
        measurementScope: String,
        expectsGPUTimestamps: Bool,
        state: ImageNodeBenchmarkRouteState
    ) -> RealtimeRouteDefinition {
        RealtimeRouteDefinition(
            tag: tag,
            measurementScope: measurementScope,
            includesDrawablePresentation: false,
            expectsGPUTimestamps: expectsGPUTimestamps,
            submit: { context, completion, backlog in
                Task { @MainActor in state.submit(context, completion: completion, observeBacklog: backlog) }
            }
        )
    }

    private func benchmark(
        route: RealtimeRouteDefinition,
        fallbackCount: () -> Int
    ) async -> RouteBenchmarkReport {
        HarbethContext.shared.performanceMonitor.clearAllMetrics()
        HarbethContext.shared.resetCaches()
        HarbethContext.shared.texturePool.purgeAllTexturesSync()
        let cacheBefore = makeCacheSnapshot()
        let startMemory = currentResidentMemory()
        let firstFrame = await submitOnce(route: route, frameIndex: -1)

        if warmupCount > 0 {
            for warmupIndex in 0..<warmupCount {
                _ = await submitOnce(route: route, frameIndex: -(warmupIndex + 2))
            }
        }
        HarbethContext.shared.performanceMonitor.clearAllMetrics()

        let snapshot = await RealtimeRouteCadenceRunner.measure(
            frameCount: frameCount,
            deadlineSeconds: realtimeFrameDeadlineMs / 1_000,
            inFlightLimit: inFlightLimit,
            submit: route.submit
        )
        let statistics = RealtimeRouteStatistics(snapshot: snapshot, deadlineMs: realtimeFrameDeadlineMs)
        let gpuTimingAvailable = statistics.gpuDistribution != nil
        let cacheAfter = makeCacheSnapshot()

        return RouteBenchmarkReport(
            route: route.tag,
            averageFrameTimeMs: statistics.endToEndDistribution.average,
            p95FrameTimeMs: statistics.endToEndDistribution.p95,
            p99FrameTimeMs: statistics.endToEndDistribution.p99,
            firstFrameTimeMs: firstFrame.endToEndTimeMs,
            stableFrames: statistics.stableFrames,
            droppedFrames: statistics.droppedFrames,
            fallbackCount: fallbackCount(),
            memoryDeltaBytes: Int64(currentResidentMemoryDifference(from: startMemory)),
            frameCount: frameCount,
            measurementScope: route.measurementScope,
            includesDrawablePresentation: route.includesDrawablePresentation,
            firstFrameSucceeded: firstFrame.completion.succeeded,
            deadlineMs: realtimeFrameDeadlineMs,
            submittedFrames: snapshot.submittedFrames,
            successfulFrames: statistics.successfulFrames,
            failedFrames: statistics.failedFrames,
            deadlineMissedFrames: statistics.deadlineMissedFrames,
            backpressureDroppedFrames: snapshot.backpressureDroppedFrames,
            schedulerDroppedFrames: snapshot.schedulerDroppedFrames,
            inFlightLimit: inFlightLimit,
            maxInFlightFrames: snapshot.maxInFlightFrames,
            maxBacklogFrames: snapshot.maxBacklogFrames,
            gpuTimingAvailable: gpuTimingAvailable,
            gpuTimestampedFrames: statistics.gpuTimestampedFrames,
            gpuAverageFrameTimeMs: statistics.gpuDistribution?.average,
            gpuP95FrameTimeMs: statistics.gpuDistribution?.p95,
            gpuP99FrameTimeMs: statistics.gpuDistribution?.p99,
            gpuTimingSource: gpuTimingAvailable && route.expectsGPUTimestamps
                ? "MTLCommandBuffer.gpuStartTime/gpuEndTime via PerformanceMonitor"
                : nil,
            cacheState: "harbeth-caches-reset; driver caches and prepared sources retained",
            cacheBefore: cacheBefore,
            cacheAfter: cacheAfter
        )
    }

    private func makeCacheSnapshot() -> RouteCacheSnapshot {
        let context = HarbethContext.shared
        let cache = context.debugCacheSnapshot()
        let pool = context.texturePool.statistics
        let derived = context.derivedResourceCacheSnapshot
        return RouteCacheSnapshot(
            texturePoolReservedBytes: cache.texturePoolByteCount,
            texturePoolByteLimit: cache.texturePoolByteLimit,
            heapReservedBytes: pool.heapReservedMemory,
            heapUsedBytes: pool.heapUsedMemory,
            derivedResourceBytes: cache.derivedResourceByteCount,
            derivedResourceByteLimit: cache.derivedResourceByteLimit,
            derivedResourceHits: derived.hitCount,
            derivedResourceMisses: derived.missCount,
            derivedResourceEvictions: derived.evictionCount,
            derivedResourceRejectedInsertions: derived.rejectedInsertionCount,
            imageResolutionBytes: cache.imageResolutionByteCount,
            imageResolutionByteLimit: cache.imageResolutionByteLimit,
            texturePoolCreated: pool.totalTexturesCreated,
            texturePoolReused: pool.totalTexturesReused
        )
    }

    private func submitOnce(route: RealtimeRouteDefinition, frameIndex: Int) async -> RealtimeFrameSample {
        let startedAt = CACurrentMediaTime()
        let context = RealtimeFrameContext(
            frameIndex: frameIndex,
            slotIndex: 0,
            scheduledAt: startedAt,
            deadlineAt: .greatestFiniteMagnitude
        )
        return await withCheckedContinuation { continuation in
            route.submit(
                context,
                { result in
                    continuation.resume(
                        returning: RealtimeFrameSample(
                            endToEndTimeMs: max((CACurrentMediaTime() - startedAt) * 1_000, 0),
                            completion: result
                        )
                    )
                },
                { _ in }
            )
        }
    }

    func write(runReport: BenchmarkRunReport) throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(
            "HarbethRealtimeRouteBenchmarks",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        let outputURL = directory.appendingPathComponent("latest.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(runReport)
        try data.write(to: outputURL, options: .atomic)
        return outputURL
    }

    private func makeSampleBufferInputs(format: OSType, count: Int) throws -> [BenchmarkSampleBuffer] {
        try (0..<count).map { index in
            let pixelBuffer = try makePixelBuffer(width: inputWidth, height: inputHeight, pixelFormatType: format)
            guard let sampleBuffer = makeSampleBuffer(
                from: pixelBuffer,
                timestamp: CMTime(value: CMTimeValue(index), timescale: 60)
            ) else {
                throw HarbethError.sampleBufferCreationFailed
            }
            return BenchmarkSampleBuffer(sampleBuffer: sampleBuffer, pixelBuffer: pixelBuffer)
        }
    }

    private func makeSampleBuffer(from pixelBuffer: CVPixelBuffer, timestamp: CMTime) -> CMSampleBuffer? {
        var formatDescription: CMFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        guard formatStatus == noErr, let formatDescription else { return nil }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 60),
            presentationTimeStamp: timestamp,
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        let sampleStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard sampleStatus == noErr, let sampleBuffer else { return nil }
        CMSetAttachment(
            sampleBuffer,
            key: kCGImagePropertyOrientation,
            value: NSNumber(value: CGImagePropertyOrientation.right.rawValue),
            attachmentMode: kCMAttachmentMode_ShouldPropagate
        )
        return sampleBuffer
    }

    private func makePixelBuffer(width: Int, height: Int, pixelFormatType: OSType) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: pixelFormatType,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:],
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            pixelFormatType,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw HarbethError.pixelBufferCreationFailed
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
            memset(baseAddress, 0, CVPixelBufferGetBytesPerRow(pixelBuffer) * height)
        }
        return pixelBuffer
    }

    private func textureInput(width: Int, height: Int) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw HarbethError.makeTexture
        }

        let bytes = [UInt8](repeating: 64, count: width * height * 4)
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: width * 4
        )
        return texture
    }

    private func currentResidentMemory() -> UInt64 {
        #if os(macOS) || os(iOS) || os(tvOS)
        var info = task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutableBytes(of: &info) { bytes in
            bytes.withMemoryRebound(to: integer_t.self) { pointer in
                task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), pointer.baseAddress, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(info.resident_size)
        #else
        return 0
        #endif
    }

    private func currentResidentMemoryDifference(from baseline: UInt64) -> UInt64 {
        let current = currentResidentMemory()
        return current > baseline ? current - baseline : 0
    }
}

@MainActor
private final class ImageNodeBenchmarkRouteState {
    enum Sources {
        case sampleBuffers([BenchmarkSampleBuffer])
        case pixelBuffers([CVPixelBuffer])
        case textures([MTLTexture])
    }

    private let sources: Sources
    private let filters: [C7FilterProtocol]
    private let renderView = RenderView(frame: .zero)

    init(sources: Sources, filters: [C7FilterProtocol]) {
        self.sources = sources
        self.filters = filters
    }

    func submit(
        _ context: RealtimeFrameContext,
        completion: @escaping @Sendable (RealtimeRouteCompletion) -> Void,
        observeBacklog: @escaping @Sendable (Int) -> Void
    ) {
        let node: ImageNode
        switch sources {
        case .sampleBuffers(let values):
            node = ImageNode.sampleBuffer(values[context.slotIndex].sampleBuffer)
        case .pixelBuffers(let values):
            node = ImageNode.pixelBuffer(values[context.slotIndex])
        case .textures(let values):
            node = ImageNode.texture(values[context.slotIndex])
        }

        node.applying(filters: filters).transmitFrame(profile: .interactiveLatency) { [self] result in
            switch result {
            case .success(let frame):
                let metricsIdentifier = frame.metadata["performanceMonitoringIdentifier"] ?? frame.identifier
                let gpuDuration = benchmarkGPUTimeMs(identifier: metricsIdentifier)
                Task { @MainActor [self] in
                    if CACurrentMediaTime() <= context.deadlineAt { renderView.display(frame) }
                    completion(.success(gpuDurationMs: gpuDuration))
                }
            case .failure:
                completion(.failure)
            }
        }
        observeBacklog(currentRenderOperationBacklog())
    }
}

@MainActor
private final class HarbethIOBenchmarkRouteState {
    private let pixelBuffers: [CVPixelBuffer]
    private let filters: [C7FilterProtocol]

    init(pixelBuffers: [CVPixelBuffer], filters: [C7FilterProtocol]) {
        self.pixelBuffers = pixelBuffers
        self.filters = filters
    }

    func submit(
        _ context: RealtimeFrameContext,
        completion: @escaping @Sendable (RealtimeRouteCompletion) -> Void,
        observeBacklog: @escaping @Sendable (Int) -> Void
    ) {
        let identifier = "RealtimeRoute.HarbethIO.slot\(context.slotIndex)"
        HarbethIO(
            element: pixelBuffers[context.slotIndex],
            filters: filters,
            identifier: identifier
        )
        // Pixel-buffer materialization waits for GPU completion. HarbethIO profiles do not alter
        // `transmitOutputRealTimeCommit`; that historical field remains the sole public switch.
        .configured(for: .interactiveLatency)
        .transmitOutput { result in
            switch result {
            case .success:
                completion(.success(gpuDurationMs: benchmarkGPUTimeMs(identifier: identifier)))
            case .failure:
                completion(.failure)
            }
        }
        observeBacklog(currentRenderOperationBacklog())
    }
}

@MainActor
private final class RenderViewAssignmentBenchmarkRouteState {
    private let textures: [MTLTexture]
    private let renderView = RenderView(frame: .zero)

    init(textures: [MTLTexture]) {
        self.textures = textures
    }

    func submit(
        _ context: RealtimeFrameContext,
        completion: @escaping @Sendable (RealtimeRouteCompletion) -> Void,
        observeBacklog: @escaping @Sendable (Int) -> Void
    ) {
        if CACurrentMediaTime() <= context.deadlineAt {
            renderView.texture = textures[context.slotIndex]
        }
        observeBacklog(0)
        completion(.success(gpuDurationMs: nil))
    }
}

private func benchmarkGPUTimeMs(identifier: String) -> Double? {
    guard let nanoseconds = HarbethContext.shared.performanceMonitor.getMetrics(identifier)?.gpuTotalTimeNanoseconds,
          nanoseconds > 0 else {
        return nil
    }
    let milliseconds = Double(nanoseconds) / 1_000_000
    return milliseconds.isFinite && milliseconds > 0 ? milliseconds : nil
}

private func currentRenderOperationBacklog() -> Int {
    let queue = HarbethContext.shared.renderOperationQueue
    return max(queue.operationCount - max(queue.maxConcurrentOperationCount, 1), 0)
}

private struct BenchmarkSampleBuffer {
    let sampleBuffer: CMSampleBuffer
    let pixelBuffer: CVPixelBuffer
}

private struct LegacyBenchmarkRunReport: Decodable {
    let frameCount: Int
    let routes: [LegacyRouteBenchmarkReport]
}

private struct LegacyRouteBenchmarkReport: Decodable {
    let averageFrameTimeMs: Double
    let stableFrames: Int
    let droppedFrames: Int

    private enum CodingKeys: String, CodingKey {
        case averageFrameTimeMs = "avgFrameTime"
        case stableFrames
        case droppedFrames
    }
}
