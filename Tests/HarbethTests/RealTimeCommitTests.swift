import XCTest
@preconcurrency import Metal
@testable import Harbeth

final class RealTimeCommitTests: XCTestCase {
    override func tearDown() {
        HarbethContext.shared.enablePerformanceMonitor = false
        super.tearDown()
    }

    func testRealTimeCommitDeliversOnlyAfterSchedulingWithMonitorOnAndOff() throws {
        let statuses = try [false, true].map { enabled in
            HarbethContext.shared.enablePerformanceMonitor = enabled
            guard let commandBuffer = HarbethContext.shared.makeCommandBuffer() else {
                throw HarbethError.commandBuffer
            }
            let state = RealTimeCommitState()
            let commandBufferTransfer = HarbethUncheckedTransfer(value: commandBuffer)

            commandBuffer.realTimeCommit(identifier: "real-time-monitor-\(enabled)") {
                state.record(status: commandBufferTransfer.value.status)
            }
            commandBuffer.waitUntilCompleted()

            XCTAssertEqual(state.callbackCount, 1)
            XCTAssertTrue(state.callbackStatus == .scheduled || state.callbackStatus == .completed)
            return state.callbackStatus
        }

        XCTAssertEqual(statuses.count, 2)
    }
}

private final class RealTimeCommitState: @unchecked Sendable {
    private let lock = NSLock()
    private var storedCallbackCount = 0
    private var storedCallbackStatus: MTLCommandBufferStatus = .notEnqueued

    var callbackCount: Int { lock.withLock { storedCallbackCount } }
    var callbackStatus: MTLCommandBufferStatus { lock.withLock { storedCallbackStatus } }

    func record(status: MTLCommandBufferStatus) {
        lock.withLock {
            storedCallbackCount += 1
            storedCallbackStatus = status
        }
    }
}
