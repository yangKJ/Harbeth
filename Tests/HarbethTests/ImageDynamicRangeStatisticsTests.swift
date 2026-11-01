import XCTest
@testable import Harbeth

final class ImageDynamicRangeStatisticsTests: XCTestCase {
    func testSeparatesRangeCountersAndHistogramChannels() throws {
        let result = try ImageDynamicRangeStatistics.analyze([
            0, 0.5, 1, 1,
            -0.1, 0.2, 0.2, 1,
            1.2, 1, 0.8, 1,
            2, 0, 0, 1.0,
            .nan, 0, 0, 1,
            0, 0, 0, 0
        ], referenceWhite: 1, outputHeadroom: 1.5)

        XCTAssertEqual(result.validPixelCount, 4)
        XCTAssertEqual(result.belowBlack, 1)
        XCTAssertEqual(result.aboveReferenceWhite, 2)
        XCTAssertEqual(result.aboveOutputLimit, 1)
        XCTAssertEqual(result.nonFinite, 1)
        XCTAssertEqual(result.transparentInvalid, 1)
        XCTAssertEqual(result.rgbHistogram.map(\.count), [256, 256, 256])
        XCTAssertEqual(result.actualPeakRGB, [2, 1, 1])
        XCTAssertEqual(result.actualPeakLuminance, 1.02994, accuracy: 0.00001)
    }

    func testInvalidBoundsFailClosed() {
        XCTAssertThrowsError(try ImageDynamicRangeStatistics.analyze([0, 0, 0], binCount: 256))
        XCTAssertThrowsError(try ImageDynamicRangeStatistics.analyze([], referenceWhite: .infinity))
        XCTAssertThrowsError(try ImageDynamicRangeStatistics.analyze([], outputHeadroom: .nan))
        XCTAssertThrowsError(try ImageDynamicRangeStatistics.analyze([], outputHeadroom: 0.5))
        XCTAssertThrowsError(try ImageDynamicRangeStatistics.analyze([], binCount: 128))
        XCTAssertThrowsError(try ImageDynamicRangeStatistics.analyze([], binCount: 4_097))
    }

    func testOutputLimitIsTheLastBinAndInputIsUnchanged() throws {
        let samples: [Float] = [0.5, 1, 1.5, 1]
        let copy = samples
        let result = try ImageDynamicRangeStatistics.analyze(samples, referenceWhite: 2, outputHeadroom: 3)

        XCTAssertEqual(samples, copy)
        XCTAssertEqual(result.outputLimit, 6)
        XCTAssertEqual(result.rgbHistogram[2].last, 0)
        XCTAssertEqual(result.luminanceHistogram.last, 0)
    }

    func testRejectsAlphaAboveOneAndKeepsNegativePeak() throws {
        let result = try ImageDynamicRangeStatistics.analyze([
            -2, -1, -0.5, 1,
            1, 1, 1, 1.5
        ])
        XCTAssertEqual(result.transparentInvalid, 1)
        XCTAssertEqual(result.validPixelCount, 1)
        XCTAssertEqual(result.actualPeakRGB, [-2, -1, -0.5])
        XCTAssertEqual(result.actualPeakLuminance, -1.18933, accuracy: 0.00001)
    }

    func testLargeFiniteInputDoesNotOverflowLuminance() throws {
        let result = try ImageDynamicRangeStatistics.analyze([Float.greatestFiniteMagnitude, 0, 0, 1])
        XCTAssertEqual(result.nonFinite, 0)
        XCTAssertEqual(result.validPixelCount, 1)
        XCTAssertTrue(result.actualPeakLuminance.isFinite)
    }
}
