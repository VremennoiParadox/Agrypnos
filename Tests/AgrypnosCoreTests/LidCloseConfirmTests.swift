import XCTest
@testable import AgrypnosCore

final class LidCloseConfirmTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testOneClosedSampleDoesNotConfirm() {
        var lid = LidCloseConfirm()
        XCTAssertNil(lid.sample(true, now: t0))
        XCTAssertFalse(lid.confirmedClosed)
    }

    func testClosedThenOpenBeforePulseDoesNotConfirm() {
        var lid = LidCloseConfirm()
        XCTAssertNil(lid.sample(true, now: t0))
        XCTAssertNil(lid.sample(false, now: t0.addingTimeInterval(0.1)))
        XCTAssertFalse(lid.confirmedClosed)
    }

    func testTwoClosedSamplesOnePulseApartConfirm() {
        var lid = LidCloseConfirm()
        XCTAssertNil(lid.sample(true, now: t0))
        XCTAssertEqual(
            lid.sample(true, now: t0.addingTimeInterval(LidCloseConfirm.pulseInterval)),
            .closed
        )
        XCTAssertTrue(lid.confirmedClosed)
    }

    func testTwoClosedSamplesAtTheSameInstantDoNotConfirm() {
        var lid = LidCloseConfirm()
        XCTAssertNil(lid.sample(true, now: t0))
        XCTAssertNil(lid.sample(true, now: t0))
        XCTAssertFalse(lid.confirmedClosed)
    }

    func testOpenAfterConfirmEmitsOpened() {
        var lid = LidCloseConfirm()
        _ = lid.sample(true, now: t0)
        _ = lid.sample(true, now: t0.addingTimeInterval(LidCloseConfirm.pulseInterval))
        XCTAssertEqual(lid.sample(false, now: t0.addingTimeInterval(0.5)), .opened)
        XCTAssertFalse(lid.confirmedClosed)
    }

    func testPulseIntervalMatchesLidPoll() {
        XCTAssertEqual(LidCloseConfirm.pulseInterval, 0.25)
    }

    func testResetClearsConfirm() {
        var lid = LidCloseConfirm()
        _ = lid.sample(true, now: t0)
        _ = lid.sample(true, now: t0.addingTimeInterval(LidCloseConfirm.pulseInterval))
        lid.reset()
        XCTAssertFalse(lid.confirmedClosed)
        XCTAssertNil(lid.sample(true, now: t0.addingTimeInterval(1)))
    }

    func testPendingCloseDoesNotRecaptureOpenBrightness() {
        XCTAssertTrue(LidCloseConfirm.shouldRecaptureOpenBrightness(rawClosed: false, confirmedClosed: false))
        XCTAssertFalse(LidCloseConfirm.shouldRecaptureOpenBrightness(rawClosed: true, confirmedClosed: false))
        XCTAssertFalse(LidCloseConfirm.shouldRecaptureOpenBrightness(rawClosed: false, confirmedClosed: true))
        XCTAssertFalse(LidCloseConfirm.shouldRecaptureOpenBrightness(rawClosed: true, confirmedClosed: true))
    }
}
