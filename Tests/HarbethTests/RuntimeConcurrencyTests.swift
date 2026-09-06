//
//  RuntimeConcurrencyTests.swift
//  Harbeth
//
//  Created by Condy on 2026/09/06.
//

import XCTest
import MetalKit
@testable import Harbeth

final class RuntimeConcurrencyTests: XCTestCase {
    func testDeviceTextureLoaderIsInitializedOncePerDeviceUnderConcurrentFirstAccess() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "当前环境没有 Metal 设备。")

        for _ in 0..<8 {
            let device = HarbethUncheckedTransfer(value: Device())
            let start = DispatchSemaphore(value: 0)
            let group = DispatchGroup()
            let recorder = LoaderIdentityRecorder()

            for _ in 0..<16 {
                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    start.wait()
                    let loader = device.value.textureLoader
                    recorder.append(loader)
                    group.leave()
                }
            }
            for _ in 0..<16 { start.signal() }
            XCTAssertEqual(group.wait(timeout: .now() + 5), .success, "并发 loader 初始化超时。")
            guard recorder.count == 16 else { return XCTFail("超时后不读取未完成的 loader 数组。") }

            let loaders = recorder.loaders
            XCTAssertEqual(loaders.count, 16)
            XCTAssertEqual(Set(loaders.map(ObjectIdentifier.init)).count, 1)
        }
    }

    func testConcurrentTransmitOutputWithImmutableFilterProducesIdenticalPixels() async throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "当前环境没有 Metal 设备。")
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 2, height: 2, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        let input = try XCTUnwrap(HarbethContext.shared.device.makeTexture(descriptor: descriptor))
        let pixels = Array(repeating: UInt8(80), count: 16)
        input.replace(region: MTLRegionMake2D(0, 0, 2, 2), mipmapLevel: 0, withBytes: pixels, bytesPerRow: 8)
        let filter = ImmutableReferenceBrightness(brightness: 0.1)
        let io = HarbethIO(element: input, filter: filter)
        let values = try await withThrowingTaskGroup(of: Data.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    let output = try await io.transmitOutput()
                    return try XCTUnwrap(output.c7.bytes())
                }
            }
            var results: [Data] = []
            for try await value in group { results.append(value) }
            return results
        }
        XCTAssertEqual(values.count, 16)
        XCTAssertGreaterThan(values[0].first ?? 0, 80)
        XCTAssertTrue(values.dropFirst().allSatisfy { $0 == values[0] })
    }
}

private final class ImmutableReferenceBrightness: C7FilterProtocol, Sendable {
    let brightness: Float

    init(brightness: Float) { self.brightness = brightness }

    var factors: [Float] { [brightness] }
    var modifier: ModifierEnum { .compute(kernel: "C7Brightness") }
}

private final class LoaderIdentityRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedLoaders: [MTKTextureLoader] = []

    func append(_ loader: MTKTextureLoader) {
        lock.withLock { storedLoaders.append(loader) }
    }

    var loaders: [MTKTextureLoader] {
        lock.withLock { storedLoaders }
    }

    var count: Int {
        lock.withLock { storedLoaders.count }
    }
}
