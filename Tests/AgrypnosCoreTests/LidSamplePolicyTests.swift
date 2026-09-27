import XCTest
@testable import AgrypnosCore

final class LidSamplePolicyTests: XCTestCase {
    func testDisengagedWithoutInboundDoesNotSample() {
        XCTAssertEqual(
            LidSamplePolicy.cadence(engaged: false, lidCloseConfirmed: false, inboundNeedsLid: false),
            .none
        )
        XCTAssertFalse(
            LidSamplePolicy.runsConfirmPulse(engaged: false, lidCloseConfirmed: false, inboundNeedsLid: false)
        )
    }

    func testInboundOffWatchStillPulsesOnlyUntilConfirm() {
        XCTAssertEqual(
            LidSamplePolicy.cadence(engaged: false, lidCloseConfirmed: false, inboundNeedsLid: true),
            .confirmPulse
        )
        XCTAssertEqual(
            LidSamplePolicy.cadence(engaged: false, lidCloseConfirmed: true, inboundNeedsLid: true),
            .coarse
        )
        XCTAssertFalse(
            LidSamplePolicy.runsConfirmPulse(engaged: false, lidCloseConfirmed: true, inboundNeedsLid: true)
        )
    }

    func testArmedWaitingForCloseUsesConfirmPulse() {
        XCTAssertEqual(
            LidSamplePolicy.cadence(engaged: true, lidCloseConfirmed: false),
            .confirmPulse
        )
        XCTAssertTrue(LidSamplePolicy.runsConfirmPulse(engaged: true, lidCloseConfirmed: false))
        XCTAssertEqual(LidSamplePolicy.confirmPulseInterval, LidCloseConfirm.pulseInterval)
    }

    func testArmedAlreadyConfirmedDropsTheFourHertzPulse() {
        XCTAssertEqual(
            LidSamplePolicy.cadence(engaged: true, lidCloseConfirmed: true),
            .coarse
        )
        XCTAssertFalse(LidSamplePolicy.runsConfirmPulse(engaged: true, lidCloseConfirmed: true))
        XCTAssertTrue(LidSamplePolicy.samplesOnTick(engaged: true, lidCloseConfirmed: true))
    }

    func testDisengagedWithoutInboundNeverPulsesEvenIfLidLooksClosed() {
        XCTAssertEqual(
            LidSamplePolicy.cadence(engaged: false, lidCloseConfirmed: true, inboundNeedsLid: false),
            .none
        )
        XCTAssertFalse(
            LidSamplePolicy.samplesOnTick(engaged: false, lidCloseConfirmed: true, inboundNeedsLid: false)
        )
    }
}
