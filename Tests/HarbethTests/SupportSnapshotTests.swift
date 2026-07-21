import XCTest
@testable import Harbeth

final class SupportSnapshotTests: XCTestCase {
    func testSupportSnapshotProducesStableJSON() throws {
        let snapshot = HarbethSupportSnapshot(
            platform: "macOS",
            operatingSystem: "Test OS",
            metalDeviceName: "Test GPU",
            performanceMonitoringEnabled: true,
            timestamp: Date(timeIntervalSince1970: 0)
        )

        let json = try snapshot.json()

        XCTAssertTrue(json.contains("\"libraryVersion\" : \"3.0.0\""))
        XCTAssertTrue(json.contains("\"metalDeviceName\" : \"Test GPU\""))
        XCTAssertTrue(json.contains("\"performanceMonitoringEnabled\" : true"))
    }
}
