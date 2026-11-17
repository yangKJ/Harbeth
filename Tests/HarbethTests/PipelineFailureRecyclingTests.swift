// 由 Condy 创建于 2026/11/17。成功、部分编码失败及未提交销毁必须遵循同一所有权。
import XCTest
import Metal
@testable import Harbeth

final class PipelineFailureRecyclingTests: XCTestCase {
    func testSuccessAndEveryFailureReturnLeasesOnlyAfterCommandLifetimeEnds() throws {
        let context = HarbethContext.shared
        let source = try NeighborhoodTestImage(width: 17, height: 13, format: .rgba16Float)
        let destination = try NeighborhoodTestImage.make(width: 17, height: 13, values: [Float](repeating: 0, count: 17 * 13 * 4))
        let queue = try XCTUnwrap(context.device.makeCommandQueue())
        for style in [FilterPipelineExecutionStyle.sequential, .parallelFromSource] {
            for failure in FailurePoint.allCases {
                for submit in [false, true] {
                    context.texturePool.purgeAllTexturesSync()
                    weak var seed: MTLTexture?
                    try autoreleasepool {
                        let lease = try TextureLoader.makeTextureLease(width: 17, height: 13, options: [
                            .texturePixelFormat: MTLPixelFormat.rgba16Float, .textureUsage: C7Brightness().destinationTextureContract.usage
                        ])
                        seed = lease.texture; lease.release()
                    }
                    XCTAssertEqual(context.texturePoolStatistics.currentTextureCount, 1)
                    try autoreleasepool {
                        let command = try XCTUnwrap(queue.makeCommandBuffer())
                        let filter = FailurePipeline(style: style, failure: failure)
                        if failure == .none {
                            _ = try filter.applyAtTexture(form: source.texture, to: destination, for: command)
                        } else {
                            XCTAssertThrowsError(try filter.applyAtTexture(form: source.texture, to: destination, for: command))
                        }
                        // 缓冲区即使尚未提交，也可能随后被宿主提交，不能提前归池。
                        XCTAssertEqual(context.texturePoolStatistics.currentTextureCount, 0)
                        XCTAssertNotNil(seed)
                        if submit {
                            let done = DispatchSemaphore(value: 0)
                            command.addCompletedHandler { _ in done.signal() }
                            command.commit(); command.waitUntilCompleted()
                            XCTAssertEqual(done.wait(timeout: .now() + 5), .success)
                            XCTAssertNil(command.error)
                        }
                    }
                    XCTAssertNotNil(seed)
                    XCTAssertEqual(context.texturePoolStatistics.currentTextureCount, failure == .firstStage ? 1 : 2,
                                   "\(style) / \(failure) / submit=\(submit)")
                    if submit && failure == .none {
                        XCTAssertEqual(try NeighborhoodTestImage.read(destination), source.values)
                    }
                }
            }
        }
        context.texturePool.purgeAllTexturesSync()
    }
}

private enum FailurePoint: CaseIterable { case none, firstStage, secondStage, missingFinal, finalEncode }
private struct FailurePipeline: C7FilterPipelineProtocol {
    let style: FilterPipelineExecutionStyle
    let failure: FailurePoint
    var pipelineExecutionStyle: FilterPipelineExecutionStyle { style }
    var pipelineFilters: [any C7FilterProtocol] {
        if failure == .firstStage { return [FailingCopy()] }
        return [C7Brightness(brightness: 0), failure == .secondStage ? FailingCopy() : C7Brightness(brightness: 0)]
    }
    func makeFinalFilter(otherInputTextures: C7InputTextures?) -> (any C7FilterProtocol)? {
        if failure == .missingFinal { return nil }
        return FinalCopy(otherInputTextures: otherInputTextures ?? [], fails: failure == .finalEncode)
    }
}
private struct FailingCopy: C7FilterProtocol, BlitProtocol {
    var modifier: ModifierEnum { .blit }
    func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        _ = try PipelineIdentityFilter().encode(commandBuffer: commandBuffer, textures: textures)
        throw HarbethError.configurationInvalid("受控中间阶段失败")
    }
}
private struct FinalCopy: C7FilterProtocol, BlitProtocol {
    let otherInputTextures: C7InputTextures
    let fails: Bool
    var modifier: ModifierEnum { .blit }
    func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        let result = try PipelineIdentityFilter().encode(commandBuffer: commandBuffer, textures: [textures[0], textures.last!])
        if fails { throw HarbethError.configurationInvalid("受控最终编码失败") }
        return result
    }
}
