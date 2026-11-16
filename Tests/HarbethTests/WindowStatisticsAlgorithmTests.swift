// 由 Condy 创建于 2026/11/16。
import XCTest
import Metal
import QuartzCore
@testable import Harbeth

final class WindowStatisticsAlgorithmTests: XCTestCase {
    func testWindowStatisticsMatchIndependentQuadrantMoments() throws {
        for fixture in 0..<3 {
            let source = try texture(width: 67, height: 9, fixture: fixture)
            for (radius, oil) in [(5, false), (8, false), (5, true)] {
                let filter: any C7FilterProtocol = oil ? C7OilPainting(radius: Float(radius)) : C7Kuwahara(radius: radius)
                let output: MTLTexture = try HarbethIO(element: source.texture, filter: filter).output()
                let data = try XCTUnwrap(output.c7.rawBytes(maximumBytes: 67 * 9 * 16))
                let actual = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
                for y in 0..<9 { for x in 0..<67 {
                    let candidates = reference(source.pixels, width: 67, height: 9, x: x, y: y, radius: radius, oil: oil)
                    let pixel = Array(actual[((y * 67 + x) * 4)..<((y * 67 + x + 1) * 4)])
                    let distances = candidates.map { candidate in zip(pixel, candidate.mean).map { abs(Double($0) - $1) }.max()! }
                    let nearest = try XCTUnwrap(distances.indices.min(by: { distances[$0] < distances[$1] }))
                    XCTAssertLessThan(distances[nearest], 0.0002)
                    // 方差几乎相等时允许 Float 归约改变赢家，但不能选到实际更差的象限。
                    XCTAssertLessThanOrEqual(candidates[nearest].score - candidates.map(\.score).min()!, 0.00002)
                } }
            }
        }
    }

    func testWindowedBenchmarksRunOnlyWhenRequested() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["HARBETH_ALGORITHM_BENCHMARKS"] == "1")
        let source = try texture(width: 1024, height: 1024, fixture: 2).texture
        for oil in [false, true] {
            let old = WindowReferenceFilter(name: oil ? "C7OilPainting" : "C7Kuwahara")
            let current: any C7FilterProtocol = oil ? C7OilPainting(radius: 8) : C7Kuwahara(radius: 8)
            func sample(_ filter: any C7FilterProtocol) throws -> Double {
                let start = CACurrentMediaTime()
                let _: MTLTexture = try HarbethIO(element: source, filter: filter).output()
                return (CACurrentMediaTime() - start) * 1000
            }
            for _ in 0..<3 { _ = try sample(old); _ = try sample(current) }
            var before: [Double] = [], after: [Double] = []
            for index in 0..<7 {
                if index.isMultiple(of: 2) { before.append(try sample(old)); after.append(try sample(current)) }
                else { after.append(try sample(current)); before.append(try sample(old)) }
            }
            print("[窗口收益] \(oil ? "OilPainting" : "Kuwahara") r8 \(before.sorted()[3]) → \(after.sorted()[3]) ms")
        }
    }

    private func reference(_ pixels: [Float], width: Int, height: Int, x: Int, y: Int, radius: Int, oil: Bool) -> [(mean: [Double], score: Double)] {
        let ranges = [(-radius, 0, -radius, 0), (0, radius, -radius, 0), (0, radius, 0, radius), (-radius, 0, 0, radius)]
        let count = Double((radius + 1) * (radius + 1))
        return ranges.prefix(oil ? 2 : 4).map { range in
            var sum = [Double](repeating: 0, count: 4), squares = sum
            for dy in range.2...range.3 { for dx in range.0...range.1 {
                let offset = (min(max(y + dy, 0), height - 1) * width + min(max(x + dx, 0), width - 1)) * 4
                for channel in 0..<4 {
                    let value = Double(pixels[offset + channel])
                    sum[channel] += value; squares[channel] += value * value
                }
            } }
            var mean = sum.map { $0 / count }
            let score = (0..<3).reduce(0.0) { $0 + abs(squares[$1] / count - mean[$1] * mean[$1]) }
            if oil { mean[3] = 1 }
            return (mean, score)
        }
    }

    private func texture(width: Int, height: Int, fixture: Int) throws -> (texture: MTLTexture, pixels: [Float]) {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil)
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.shaderRead, .shaderWrite]
        let source = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        var pixels = [Float](repeating: 0, count: width * height * 4)
        for y in 0..<height { for x in 0..<width {
            let offset = (y * width + x) * 4
            let alpha: Float = fixture == 2 && (x + y) % 5 == 0 ? 0.4 : 1
            for channel in 0..<3 {
                let value: Float
                if fixture == 0 { value = 0.25 }
                else if fixture == 1 { value = x < width / 2 ? 0.2 : 0.8 }
                else { value = Float((x * 31 + y * 17 + x * y * 7 + channel * 53) % 251) / 251 }
                pixels[offset + channel] = value * alpha
            }
            pixels[offset + 3] = alpha
        } }
        pixels.withUnsafeBytes { source.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
            withBytes: $0.baseAddress!, bytesPerRow: width * 16) }
        return (source, pixels)
    }
}

private struct WindowReferenceFilter: C7FilterProtocol {
    let name: String
    var modifier: ModifierEnum { .compute(kernel: name) }
    var factors: [Float] { [8, 1] }
    var memoryAccessPattern: MemoryAccessPattern { .neighborhood }
}
