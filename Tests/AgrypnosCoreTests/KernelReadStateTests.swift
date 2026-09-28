import XCTest
@testable import AgrypnosCore

final class KernelReadStateTests: XCTestCase {
    func testOnlySuccessfulExplicitReadEstablishesClearOrHeld() {
        XCTAssertEqual(SleepDisabledParser.state(pmsetG: " SleepDisabled 0\n", exit: 0), .clear)
        XCTAssertEqual(SleepDisabledParser.state(pmsetG: " SleepDisabled 1\n", exit: 0), .held)
        for output in ["", " SleepDisabled garbage\n", " SleepDisabled 2\n", "NotSleepDisabled 0\n"] {
            XCTAssertEqual(SleepDisabledParser.state(pmsetG: output, exit: 0), .unknown)
        }
        XCTAssertEqual(SleepDisabledParser.state(pmsetG: " SleepDisabled 0\n", exit: 1), .unknown)
    }
}
