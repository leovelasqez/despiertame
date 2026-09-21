import XCTest
@testable import Despiertame

final class DistanceFormatTests: XCTestCase {
    func testMetersBelowOneKilometer() {
        let text = DistanceFormat.string(350)
        XCTAssertTrue(text.contains("350"), text)
        XCTAssertTrue(text.lowercased().contains("m"), text)
        XCTAssertFalse(text.lowercased().contains("km"), text)
    }

    func testMetersAreRoundedToTens() {
        XCTAssertTrue(DistanceFormat.string(347).contains("350"))
        XCTAssertTrue(DistanceFormat.string(42).contains("42"))
    }

    func testKilometersWithOneDecimal() {
        let text = DistanceFormat.string(2_400)
        XCTAssertTrue(text.lowercased().contains("km"), text)
        XCTAssertTrue(text.contains("2"), text)
        XCTAssertTrue(text.contains("4"), text)
    }

    func testLargeDistancesHaveNoDecimals() {
        let text = DistanceFormat.string(12_600)
        XCTAssertTrue(text.contains("13"), text)
        XCTAssertTrue(text.lowercased().contains("km"), text)
    }

    func testNegativeAndInvalidValues() {
        XCTAssertTrue(DistanceFormat.string(-20).contains("0"))
        XCTAssertEqual(DistanceFormat.string(.nan), "—")
        XCTAssertEqual(DistanceFormat.accuracy(-1), "GPS sin señal")
    }

    func testSpeedConversion() {
        // 10 m/s = 36 km/h
        let text = DistanceFormat.speed(10)
        XCTAssertTrue(text.contains("36"), text)
    }
}
