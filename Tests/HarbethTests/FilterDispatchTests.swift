//
//  FilterDispatchTests.swift
//  Harbeth
//
//  由 Condy 创建于 2026/11/6。
//

import Metal
import MetalPerformanceShaders
import XCTest
@testable import Harbeth

final class FilterDispatchTests: XCTestCase {
    func testCallbackPreservesDestinationReturnAndActualEncodedOutput() throws {
        let (source, destination, command) = try makeInputs()
        let filters: [C7FilterProtocol] = [
            ReturningSourceFilter(modifier: .blit),
            ReturningSourceFilter(modifier: .mps(performance: MPSImageBox(
                device: source.device, kernelWidth: 1, kernelHeight: 1
            )))
        ]
        for filter in filters {
            let result = DispatchResultBox()
            let returned = try filter.apply(form: source, to: destination, for: command) { result.store($0) }
            XCTAssertTrue(returned === destination)
            XCTAssertTrue(try XCTUnwrap(result.value).get() === source)
            XCTAssertEqual(result.count, 1)
            XCTAssertTrue(try filter.apply(form: source, to: destination, for: command, complete: nil) === source)
        }
    }

    func testInvalidNonComputeProtocolThrowsWithoutCallingCompletion() throws {
        let (source, destination, command) = try makeInputs()
        let modifiers: [ModifierEnum] = [
            .blit,
            .mps(performance: MPSImageBox(device: source.device, kernelWidth: 1, kernelHeight: 1)),
            .metalCommand(label: "invalid-dispatch")
        ]
        for modifier in modifiers {
            let result = DispatchResultBox()
            let filter = DispatchOnlyFilter(modifier: modifier)
            var synchronousError: String?
            XCTAssertThrowsError(try filter.apply(form: source, to: destination, for: command, complete: nil)) {
                synchronousError = String(describing: $0)
            }
            XCTAssertThrowsError(try filter.apply(form: source, to: destination, for: command, complete: { result.store($0) })) {
                XCTAssertEqual(String(describing: $0), synchronousError)
            }
            XCTAssertEqual(result.count, 0)
        }
    }

    func testMissingComputeKernelReportsCallbackFailureButSyncThrows() throws {
        let (source, destination, command) = try makeInputs()
        let filter = DispatchOnlyFilter(modifier: .compute(kernel: "missing_dispatch_regression_kernel"))
        let callback = expectation(description: "计算管线错误通过回调交付")
        let result = DispatchResultBox()
        let returned = try filter.apply(form: source, to: destination, for: command) {
            result.store($0)
            callback.fulfill()
        }
        XCTAssertTrue(returned === destination)
        wait(for: [callback], timeout: 10)
        XCTAssertEqual(result.count, 1)
        let callbackResult = try XCTUnwrap(result.value)
        XCTAssertThrowsError(try callbackResult.get())
        XCTAssertThrowsError(try filter.apply(form: source, to: destination, for: command, complete: nil))
    }

    private func makeInputs() throws -> (MTLTexture, MTLTexture, MTLCommandBuffer) {
        let device = HarbethContext.shared.device
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 2, height: 2, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        let source = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let destination = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let command = try XCTUnwrap(device.makeCommandQueue()?.makeCommandBuffer())
        return (source, destination, command)
    }
}

private struct ReturningSourceFilter: BlitProtocol, MPSKernelProtocol {
    let modifier: ModifierEnum
    func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture { textures[1] }
}

private struct DispatchOnlyFilter: C7FilterProtocol {
    let modifier: ModifierEnum
}

private final class DispatchResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<MTLTexture, HarbethError>?
    private var countStorage = 0
    var value: Result<MTLTexture, HarbethError>? { lock.withLock { result } }
    var count: Int { lock.withLock { countStorage } }

    func store(_ value: Result<MTLTexture, HarbethError>) {
        lock.withLock {
            result = value
            countStorage += 1
        }
    }
}
