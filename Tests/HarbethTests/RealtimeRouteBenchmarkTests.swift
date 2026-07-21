import XCTest
import AVFoundation
import CoreMedia
import CoreVideo
import ImageIO
import Metal
#if canImport(Darwin)
import Darwin
#endif
@testable import Harbeth

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
    }
}

private struct BenchmarkRunReport: Codable {
    let createdAt: Date
    let deviceName: String
    let frameCount: Int
    let warmupCount: Int
    let routes: [RouteBenchmarkReport]
}

private struct RouteTimings {
    let average: Double
    let p95: Double
    let p99: Double
    let first: Double
    let stableFrames: Int
}

final class RealtimeRouteBenchmarkTests: XCTestCase {
    @MainActor
    func testRealtimeFrameRouteBenchmark5Paths() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTFail("Metal device is unavailable in this environment.")
            return
        }

        do {
            let benchmark = RealtimeRouteBenchmarker(device: device)
            let reports = try benchmark.runAll()
            XCTAssertEqual(reports.count, 5)
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
            XCTAssertEqual(decoded.routes.count, 5)
            for route in decoded.routes {
                XCTAssertGreaterThanOrEqual(route.averageFrameTimeMs, 0)
                XCTAssertGreaterThanOrEqual(route.p95FrameTimeMs, 0)
                XCTAssertGreaterThanOrEqual(route.p99FrameTimeMs, 0)
                XCTAssertGreaterThanOrEqual(route.firstFrameTimeMs, 0)
                XCTAssertGreaterThanOrEqual(route.droppedFrames, 0)
                XCTAssertGreaterThanOrEqual(route.fallbackCount, 0)
                XCTAssertGreaterThanOrEqual(route.memoryDeltaBytes, 0)
                XCTAssertGreaterThanOrEqual(route.stableFrames, 0)
            }
            for report in reports {
                let avg = String(format: "%.3f", report.averageFrameTimeMs)
                let p95 = String(format: "%.3f", report.p95FrameTimeMs)
                let p99 = String(format: "%.3f", report.p99FrameTimeMs)
                let first = String(format: "%.3f", report.firstFrameTimeMs)
                print(
                    "[RouteBenchmark] \(report.route) avg=\(avg)ms p95=\(p95)ms p99=\(p99)ms first=\(first)ms dropped=\(report.droppedFrames) fallback=\(report.fallbackCount) memory=\(report.memoryDeltaBytes)B stable=\(report.stableFrames)/\(report.frameCount)"
                )
            }
            print("[RouteBenchmark JSON] \(outputURL.path)")
        } catch {
            XCTFail("Benchmark failed: \(error)")
        }
    }
}

@MainActor
private struct RealtimeRouteBenchmarker {
    private let device: MTLDevice
    private let frameCount = 300
    private let warmupCount = 20
    private let inputWidth = 720
    private let inputHeight = 1280
    private let filters: [C7FilterProtocol] = [
        C7ColorMatrix4x4(matrix: Matrix4x4.Color.blackAndWhite),
        C7GaussianBlur(radius: 1.2),
    ]

    init(device: MTLDevice) {
        self.device = device
    }

    var benchmarkFrameCount: Int { frameCount }
    var benchmarkWarmupCount: Int { warmupCount }

    func runAll() throws -> [RouteBenchmarkReport] {
        let samples = try makeSampleBufferInputs(format: kCVPixelFormatType_32BGRA, count: frameCount + warmupCount)
        let pixelBuffers = samples.map { $0.pixelBuffer }

        guard let textureRoute = try? textureInput(width: inputWidth, height: inputHeight),
              let sourcePixelBuffer = pixelBuffers.first else {
            throw XCTestError(.failureWhileWaiting)
        }

        let sampleBufferDisplay = benchmarkSampleBufferDisplay(sampleBuffers: samples)
        let pixelBufferDisplay = benchmarkPixelBufferDisplay(pixelBuffers: pixelBuffers)
        let textureDisplay = benchmarkTextureDisplay(texture: textureRoute)
        let harbethIO = benchmarkHarbethIO(pixelBuffer: sourcePixelBuffer)
        let renderViewTexture = benchmarkRenderViewTextureAssignment(texture: textureRoute)

        return [sampleBufferDisplay, pixelBufferDisplay, textureDisplay, harbethIO, renderViewTexture]
    }

    func run(iterations: Int? = nil, action: () throws -> Void) -> RouteTimings {
        let iterationCount = iterations ?? frameCount
        var durations: [Double] = []
        durations.reserveCapacity(iterationCount + warmupCount)

        var stableFrames = 0
        let warmupLimit = max(warmupCount, 0)

        autoreleasepool {
            for _ in 0..<warmupLimit {
                _ = try? action()
            }

            for _ in 0..<iterationCount {
                let start = CFAbsoluteTimeGetCurrent()
                do {
                    try action()
                    let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
                    durations.append(elapsed)
                    stableFrames += 1
                } catch {
                    stableFrames += 0
                }
            }
        }

        let sorted = durations.sorted()
        let first = sorted.first ?? 0
        let durationTotal = sorted.reduce(0, +)
        let avg = sorted.isEmpty ? 0 : durationTotal / Double(sorted.count)
        let p95 = percentile(sorted, value: 0.95)
        let p99 = percentile(sorted, value: 0.99)

        return RouteTimings(average: avg, p95: p95, p99: p99, first: first, stableFrames: stableFrames)
    }

    private func percentile(_ values: [Double], value: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let index = Int(Double(values.count - 1) * value)
        return values[min(values.count - 1, max(0, index))]
    }

    func benchmarkSampleBufferDisplay(sampleBuffers: [BenchmarkSampleBuffer]) -> RouteBenchmarkReport {
        let tag = "sampleBuffer -> ImageNode -> RenderView.display"
        let renderView = RenderView(frame: .zero)
        PixelBufferPool.resetRealtimePoolMetrics()
        let baselineFallback = PixelBufferPool.realtimeAllocationFallbackCount
        let startMemory = currentResidentMemory()
        let sampleBuffer = sampleBuffers[0].sampleBuffer

        let timings = run {
            let frame = try ImageNode.sampleBuffer(sampleBuffer)
                .applying(filters: filters)
                .makeFrame(profile: .interactiveLatency)
            renderView.display(frame)
        }

        return RouteBenchmarkReport(
            route: tag,
            averageFrameTimeMs: timings.average,
            p95FrameTimeMs: timings.p95,
            p99FrameTimeMs: timings.p99,
            firstFrameTimeMs: timings.first,
            stableFrames: timings.stableFrames,
            droppedFrames: 0,
            fallbackCount: max(0, PixelBufferPool.realtimeAllocationFallbackCount - baselineFallback),
            memoryDeltaBytes: Int64(currentResidentMemoryDifference(from: startMemory)),
            frameCount: frameCount
        )
    }

    func benchmarkPixelBufferDisplay(pixelBuffers: [CVPixelBuffer]) -> RouteBenchmarkReport {
        let tag = "pixelBuffer -> ImageNode -> RenderView.display"
        let renderView = RenderView(frame: .zero)
        PixelBufferPool.resetRealtimePoolMetrics()
        let baselineFallback = PixelBufferPool.realtimeAllocationFallbackCount
        let startMemory = currentResidentMemory()
        let pixelBuffer = pixelBuffers[0]

        let timings = run {
            let frame = try ImageNode.pixelBuffer(pixelBuffer)
                .applying(filters: filters)
                .makeFrame(profile: .interactiveLatency)
            renderView.display(frame)
        }

        return RouteBenchmarkReport(
            route: tag,
            averageFrameTimeMs: timings.average,
            p95FrameTimeMs: timings.p95,
            p99FrameTimeMs: timings.p99,
            firstFrameTimeMs: timings.first,
            stableFrames: timings.stableFrames,
            droppedFrames: 0,
            fallbackCount: max(0, PixelBufferPool.realtimeAllocationFallbackCount - baselineFallback),
            memoryDeltaBytes: Int64(currentResidentMemoryDifference(from: startMemory)),
            frameCount: frameCount
        )
    }

    func benchmarkTextureDisplay(texture: MTLTexture) -> RouteBenchmarkReport {
        let tag = "texture -> ImageNode -> RenderView.display"
        let renderView = RenderView(frame: .zero)
        let startMemory = currentResidentMemory()

        let timings = run {
            let frame = try ImageNode.texture(texture)
                .applying(filters: filters)
                .makeFrame(profile: .interactiveLatency)
            renderView.display(frame)
        }

        return RouteBenchmarkReport(
            route: tag,
            averageFrameTimeMs: timings.average,
            p95FrameTimeMs: timings.p95,
            p99FrameTimeMs: timings.p99,
            firstFrameTimeMs: timings.first,
            stableFrames: timings.stableFrames,
            droppedFrames: 0,
            fallbackCount: 0,
            memoryDeltaBytes: Int64(currentResidentMemoryDifference(from: startMemory)),
            frameCount: frameCount
        )
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

    func benchmarkHarbethIO(pixelBuffer: CVPixelBuffer) -> RouteBenchmarkReport {
        let tag = "HarbethIO -> output"
        let startMemory = currentResidentMemory()

        let timings = run {
            _ = try HarbethIO(element: pixelBuffer, filters: filters)
                .configured(for: .interactiveLatency)
                .output()
        }

        return RouteBenchmarkReport(
            route: tag,
            averageFrameTimeMs: timings.average,
            p95FrameTimeMs: timings.p95,
            p99FrameTimeMs: timings.p99,
            firstFrameTimeMs: timings.first,
            stableFrames: timings.stableFrames,
            droppedFrames: 0,
            fallbackCount: 0,
            memoryDeltaBytes: Int64(currentResidentMemoryDifference(from: startMemory)),
            frameCount: frameCount
        )
    }

    func benchmarkRenderViewTextureAssignment(texture: MTLTexture) -> RouteBenchmarkReport {
        let tag = "RenderView.texture"
        let renderView = RenderView(frame: .zero)
        let startMemory = currentResidentMemory()

        let timings = run { renderView.texture = texture }

        return RouteBenchmarkReport(
            route: tag,
            averageFrameTimeMs: timings.average,
            p95FrameTimeMs: timings.p95,
            p99FrameTimeMs: timings.p99,
            firstFrameTimeMs: timings.first,
            stableFrames: timings.stableFrames,
            droppedFrames: 0,
            fallbackCount: 0,
            memoryDeltaBytes: Int64(currentResidentMemoryDifference(from: startMemory)),
            frameCount: frameCount
        )
    }

    private func makeSampleBufferInputs(format: OSType, count: Int) throws -> [BenchmarkSampleBuffer] {
        try (0..<count).map { index in
            let pixelBuffer = try makePixelBuffer(width: inputWidth, height: inputHeight, pixelFormatType: format)
            guard let sampleBuffer = makeSampleBuffer(from: pixelBuffer, timestamp: CMTime(value: CMTimeValue(index), timescale: 60)) else {
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
        guard formatStatus == noErr, let formatDescription else {
            return nil
        }

        var timing = CMSampleTimingInfo(
            duration: CMTime.invalid,
            presentationTimeStamp: timestamp,
            decodeTimeStamp: CMTime.invalid
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
            kCVPixelBufferPixelFormatTypeKey: pixelFormatType, kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height, kCVPixelBufferMetalCompatibilityKey: true,
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
            bytes.withMemoryRebound(to: integer_t.self) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), intPtr.baseAddress, &count)
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

private struct BenchmarkSampleBuffer {
    let sampleBuffer: CMSampleBuffer
    let pixelBuffer: CVPixelBuffer
}
