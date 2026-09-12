import XCTest
@testable import AgrypnosCore

final class PowerStatusParserTests: XCTestCase {
    func testBatteryDischarging() {
        let text = """
        Now drawing from 'Battery Power'
         -InternalBattery-0\t67%; discharging; 3:45 remaining present: true
        """
        let reading = BatteryStatusParser.parse(pmsetBatt: text)
        XCTAssertTrue(reading.onBattery)
        XCTAssertTrue(reading.discharging)
        XCTAssertEqual(reading.percent, 67)
        XCTAssertTrue(reading.onBatteryDischarging)
    }

    func testACCharged() {
        let text = """
        Now drawing from 'AC Power'
         -InternalBattery-0\t100%; charged; 0:00 remaining present: true
        """
        let reading = BatteryStatusParser.parse(pmsetBatt: text)
        XCTAssertFalse(reading.onBattery)
        XCTAssertFalse(reading.discharging)
        XCTAssertEqual(reading.percent, 100)
    }

    func testSleepDisabledPresentAndAbsent() {
        XCTAssertTrue(SleepDisabledParser.parse(pmsetG: " hibernatemode 3\n SleepDisabled\t1\n"))
        XCTAssertFalse(SleepDisabledParser.parse(pmsetG: " hibernatemode 3\n SleepDisabled 0\n"))
        XCTAssertFalse(SleepDisabledParser.parse(pmsetG: " hibernatemode 3\n"))
    }
}
