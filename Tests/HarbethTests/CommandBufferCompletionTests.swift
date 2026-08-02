import Metal
import XCTest
@testable import Harbeth

final class CommandBufferCompletionTests: XCTestCase {
    func testCompletedStatusDoesNotProduceAnError() {
        XCTAssertNil(
            CommandBufferCompletionValidator.error(
                status: .completed,
                underlyingError: nil
            )
        )
    }

    func testUnderlyingGPUErrorIsPreserved() {
        let underlying = NSError(
            domain: "CommandBufferCompletionTests",
            code: 7,
            userInfo: nil
        )
        let error = CommandBufferCompletionValidator.error(
            status: .error,
            underlyingError: underlying
        )

        guard case .error(let received)? = error else {
            return XCTFail("GPU error 应保留底层错误。")
        }
        XCTAssertEqual((received as NSError).domain, underlying.domain)
        XCTAssertEqual((received as NSError).code, underlying.code)
    }

    func testNonCompletedStatusMapsToCommandBufferStatusError() {
        let error = CommandBufferCompletionValidator.error(
            status: .notEnqueued,
            underlyingError: nil
        )

        guard case .commandBufferAsyncCommit(let status)? = error else {
            return XCTFail("非完成状态应映射为 command-buffer status error。")
        }
        XCTAssertEqual(status, .notEnqueued)
    }
}
