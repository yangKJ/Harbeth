// 由 Condy 创建于 2026/11/17。异常后宿主仍可提交前缀，已编码表面必须保持独占。
import XCTest
import Metal
@testable import Harbeth

final class ExternalEncodingFailureTests: XCTestCase {
    func testFailureCannotRecycleOrOverwriteAnotherRequestsTextures() throws {
        let context = HarbethContext.shared
        let source = try pixel([0.25, 0, 0, 1]), blue = try pixel([0, 0, 0.75, 1])
        let queue = try XCTUnwrap(source.device.makeCommandQueue())
        for profile in [RenderProfile.stablePreview, .exportQuality] {
            for afterEncoding in [false, true] {
                context.texturePool.purgeAllTexturesSync()
                let command = try XCTUnwrap(queue.makeCommandBuffer())
                let node = ImageNode.texture(source).applying(filters: [C7Brightness(brightness: 0), EncodingFailure(afterEncoding: afterEncoding)])
                XCTAssertThrowsError(try node.encodeFrame(into: command, inputColorSpace: .sRGB, workingColorSpace: .sRGB, profile: profile))
                XCTAssertEqual(command.status, .notEnqueued)
                XCTAssertEqual(context.texturePoolStatistics.currentTextureCount, 0)
                let leases = try (0..<2).map { _ in try TextureLoader.makeTextureLease(width: 17, height: 13, options: [
                    .texturePixelFormat: MTLPixelFormat.rgba16Float, .textureUsage: C7Brightness().destinationTextureContract.usage
                ]) }
                let other = try XCTUnwrap(queue.makeCommandBuffer())
                for lease in leases { _ = try PipelineIdentityFilter().encode(commandBuffer: other, textures: [lease.texture, blue]) }
                complete(other)
                complete(command)
                for lease in leases {
                    XCTAssertEqual(Array(try NeighborhoodTestImage.read(lease.texture).prefix(4)), [0, 0, 0.75, 1])
                    lease.release()
                }
            }
        }
        context.texturePool.purgeAllTexturesSync()
    }

    func testSuccessfulFrameOwnsItsOutputBeyondGPUCompletion() throws {
        let context = HarbethContext.shared, source = try pixel([0.25, 0, 0, 1])
        context.texturePool.purgeAllTexturesSync()
        let command = try XCTUnwrap(source.device.makeCommandQueue()?.makeCommandBuffer())
        let frame = try ImageNode.texture(source).applying(C7Brightness(brightness: 0.1))
            .encodeFrame(into: command, inputColorSpace: .sRGB, workingColorSpace: .sRGB)
        complete(command)
        XCTAssertEqual(context.texturePoolStatistics.currentTextureCount, 0)
        XCTAssertEqual(try NeighborhoodTestImage.read(frame.texture)[0], 0.35, accuracy: 0.001)
        frame.lease?.release()
        XCTAssertEqual(context.texturePoolStatistics.currentTextureCount, 1)
        context.texturePool.purgeAllTexturesSync()
    }

    func testFailedUnsubmittedBufferReturnsProtectedLeasesOnDestruction() throws {
        let context = HarbethContext.shared, source = try pixel([0.25, 0, 0, 1])
        context.texturePool.purgeAllTexturesSync()
        try autoreleasepool {
            let command = try XCTUnwrap(source.device.makeCommandQueue()?.makeCommandBuffer())
            let node = ImageNode.texture(source).applying(filters: [C7Brightness(), EncodingFailure(afterEncoding: true)])
            XCTAssertThrowsError(try node.encodeFrame(into: command, inputColorSpace: .sRGB, workingColorSpace: .sRGB))
            XCTAssertEqual(context.texturePoolStatistics.currentTextureCount, 0)
        }
        XCTAssertEqual(context.texturePoolStatistics.currentTextureCount, 2)
        context.texturePool.purgeAllTexturesSync()
    }

    private func pixel(_ value: [Float]) throws -> MTLTexture {
        try NeighborhoodTestImage.make(width: 17, height: 13, values: Array(repeating: value, count: 221).flatMap { $0 })
    }
    private func complete(_ command: MTLCommandBuffer) {
        let done = DispatchSemaphore(value: 0)
        command.addCompletedHandler { _ in done.signal() }
        command.commit(); command.waitUntilCompleted()
        XCTAssertEqual(done.wait(timeout: .now() + 5), .success)
        XCTAssertNil(command.error)
    }
}

private struct EncodingFailure: C7FilterProtocol, BlitProtocol {
    let afterEncoding: Bool
    var modifier: ModifierEnum { .blit }
    func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        if afterEncoding { _ = try PipelineIdentityFilter().encode(commandBuffer: commandBuffer, textures: textures) }
        throw HarbethError.configurationInvalid("受控阶段失败")
    }
}
