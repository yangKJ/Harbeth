import XCTest
import Metal
@testable import Harbeth

final class DeviceLibraryTests: XCTestCase {

    func testSwiftPackageCanLoadHarbethMetalLibrary() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let library = Device.makeFrameworkLibrary(device!, for: "Harbeth")

        XCTAssertNotNil(library)
    }
}
