//
//  AlgorithmRoundThreePerformanceTests.metal
//  Harbeth
//
//  Created by Condy on 2026/11/16.
//

import XCTest
import Metal
import QuartzCore
@testable import Harbeth

final class AlgorithmRoundThreePerformanceTests: XCTestCase {
    func testOfflineInterfacePerformanceWhenRequested() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["HARBETH_ROUND3_BENCHMARKS"] == "1")
        #if DEBUG
        throw XCTSkip("性能验收使用 Release")
        #else
        var rows: [[String: Any]] = []
        for (width, height) in [(512,512), (3840,2160)] {
            let image = try NeighborhoodTestImage(width: width, height: height, format: .rgba16Float)
            rows.append(try measure("clarity", metadata: ["width":width,"height":height]) {
                let _: MTLTexture = try HarbethIO(element: image.texture, filter: C7Clarity()).output()
            })
        }
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        for count in [8,128,1024,2048] {
            let pool = TexturePool(device: device, maxMemoryUsage: 64 * 1024 * 1024)
            var descriptors: [MTLTextureDescriptor] = []
            for i in 0..<count {
                let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: 8+i, height: 1, mipmapped: false)
                d.storageMode = .shared; d.usage = [.shaderRead,.shaderWrite]
                descriptors.append(d)
                pool.enqueueTextureSync(try XCTUnwrap(device.makeTexture(descriptor: d)))
            }
            rows.append(try measure("poolExact500", metadata: ["keys":count]) {
                for _ in 0..<500 {
                    pool.enqueueTextureSync(try XCTUnwrap(pool.dequeueTexture(matching: descriptors[0], allowsSizeTolerance: false)))
                }
            })
            let miss = descriptors[0].copy() as! MTLTextureDescriptor
            miss.width = 9000
            rows.append(measure("poolToleranceMiss500", metadata: ["keys":count]) {
                for _ in 0..<500 { XCTAssertNil(pool.dequeueTexture(matching: miss, allowsSizeTolerance: true)) }
            })
        }
        let report: [String: Any] = ["author":"Condy","device":device.name,"configuration":"release",
            "measurement":"同步离屏接口或500次池操作；2次预热7次样本p50；非drawable呈现","rows":rows]
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("HarbethRoundThreePerformance-20261116.json")
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted,.sortedKeys]).write(to: url)
        print("[第三轮性能验收] \(url.path)")
        #endif
    }

    private func measure(_ name: String, metadata: [String: Any], operation: () throws -> Void) rethrows -> [String: Any] {
        for _ in 0..<2 { try autoreleasepool(invoking: operation) }
        var times: [Double] = []
        for _ in 0..<7 {
            let start = CACurrentMediaTime()
            try autoreleasepool(invoking: operation)
            times.append((CACurrentMediaTime() - start) * 1000)
        }
        times.sort()
        var row = metadata; row["name"] = name; row["p50Ms"] = times[3]; row["p95Ms"] = times[6]
        return row
    }
}
