// 由 Condy 创建于 2026/11/16。
import XCTest
import Metal
import QuartzCore
@testable import Harbeth

/// 仅按需运行 Release 接口基准；普通回归由提交数、读回范围和像素合同约束。
final class AnalysisPerformanceRegressionTests: XCTestCase {
    func testAnalysisAndNeighborhoodInterfaceBenchmarks() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["HARBETH_ANALYSIS_BENCHMARKS"] == "1")
        #if DEBUG
        throw XCTSkip("完整接口性能对照使用 Release")
        #else
        let source = try texture(width: 3840, height: 2160)
        let frame = try ImageNode.texture(source).makeFrame()
        var rows: [[String: Any]] = []
        for (name, region): (String, MTLRegion) in [
            ("emptyROI", MTLRegionMake2D(0,0,0,0)), ("pointROI", MTLRegionMake2D(7,11,1,1))
        ] {
            rows.append(try measure(name) {
                let result = try XCTUnwrap(source.c7.makeStatistics(region: region))
                XCTAssertEqual(result.sampleCount, region.size.width * region.size.height)
            })
        }
        for small in [false, true] {
            let scope = TextureAnalysisScope(region: small ? MTLRegionMake2D(3,5,64,64) : nil,
                mask: MaskDescriptor(texture: source, component: .alpha))
            rows.append(try measure(small ? "maskedBundleROI" : "maskedBundleFull") {
                let result = RenderedAnalysisBundle.makeScopeBundle(frame: frame, channel: .red, bins: 256,
                    histogramHeight: 64, scope: scope, preferredMethod: .gpuMPS, attachmentDebugPolicies: [])
                XCTAssertEqual(result.statistics?.sampleCount, small ? 4096 : 3840 * 2160)
                XCTAssertEqual(result.histogram?.totalSampleCount, result.statistics?.sampleCount)
            })
        }
        let image = try texture(width: 1024, height: 1024)
        for (name, filter): (String, any C7FilterProtocol) in [
            ("detailPreserving", C7DetailPreservingBlur(strength: 1)),
            ("detailEnhancer", C7DetailEnhancer(amount: 1)), ("noiseZero", C7NoiseReduction(amount: 0))
        ] {
            rows.append(try measure(name) { let _: MTLTexture = try HarbethIO(element: image, filter: filter).output() })
        }
        let report: [String: Any] = ["author": "Condy", "configuration": "release", "device": source.device.name,
            "measurement": "同步离屏完整接口；3次预热，11次样本；无drawable呈现", "rows": rows]
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("HarbethAnalysisPerformance-20261116.json")
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: url)
        print("[分析接口验收] \(url.path)")
        #endif
    }

    private func measure(_ name: String, operation: () throws -> Void) throws -> [String: Any] {
        for _ in 0..<3 { try autoreleasepool(invoking: operation) }
        var values: [Double] = []
        for _ in 0..<11 {
            let start = CACurrentMediaTime()
            try autoreleasepool(invoking: operation)
            values.append((CACurrentMediaTime() - start) * 1000)
        }
        values.sort()
        return ["name": name, "p50Ms": values[5], "p95Ms": values[10]]
    }

    private func texture(width: Int, height: Int) throws -> MTLTexture {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.shaderRead, .shaderWrite]
        let result = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        var pixels = [Float16](repeating: 1, count: width * height * 4)
        for i in 0..<(width * height) {
            pixels[i * 4] = Float16(Float((i * 13) % 251) / 251)
            pixels[i * 4 + 1] = Float16(Float((i * 7) % 251) / 251)
            pixels[i * 4 + 2] = 0.25
        }
        pixels.withUnsafeBytes { result.replace(region: MTLRegionMake2D(0,0,width,height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 8) }
        return result
    }
}
