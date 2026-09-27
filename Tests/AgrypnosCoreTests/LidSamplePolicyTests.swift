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

    func testArmedLidOpenUsesCoarseTickNotFourHertz() {
        XCTAssertEqual(
            LidSamplePolicy.cadence(engaged: true, lidCloseConfirmed: false, pendingClose: false),
            .coarse
        )
        XCTAssertFalse(LidSamplePolicy.runsConfirmPulse(engaged: true, lidCloseConfirmed: false))
        XCTAssertTrue(LidSamplePolicy.samplesOnTick(engaged: true, lidCloseConfirmed: false))
    }

    func testPendingCloseUsesConfirmPulse() {
        XCTAssertEqual(
            LidSamplePolicy.cadence(engaged: true, lidCloseConfirmed: false, pendingClose: true),
            .confirmPulse
        )
        XCTAssertTrue(
            LidSamplePolicy.runsConfirmPulse(engaged: true, lidCloseConfirmed: false, pendingClose: true)
        )
        XCTAssertEqual(LidSamplePolicy.confirmPulseInterval, LidCloseConfirm.pulseInterval)
    }

    func testInboundOpenLidDoesNotPulseForever() {
        XCTAssertEqual(
            LidSamplePolicy.cadence(
                engaged: false,
                lidCloseConfirmed: false,
                inboundNeedsLid: true,
                pendingClose: false
            ),
            .coarse
        )
        XCTAssertFalse(
            LidSamplePolicy.runsConfirmPulse(
                engaged: false,
                lidCloseConfirmed: false,
                inboundNeedsLid: true,
                pendingClose: false
            )
        )
        XCTAssertEqual(
            LidSamplePolicy.cadence(
                engaged: false,
                lidCloseConfirmed: false,
                inboundNeedsLid: true,
                pendingClose: true
            ),
            .confirmPulse
        )
        XCTAssertEqual(
            LidSamplePolicy.cadence(engaged: false, lidCloseConfirmed: true, inboundNeedsLid: true),
            .coarse
        )
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

    func testOneClosedSampleIsPendingNotConfirmed() {
        var confirm = LidCloseConfirm()
        let t0 = Date(timeIntervalSince1970: 10_000)
        XCTAssertNil(confirm.sample(true, now: t0))
        XCTAssertTrue(confirm.isPendingClose)
        XCTAssertFalse(confirm.confirmedClosed)
        XCTAssertEqual(
            confirm.sample(true, now: t0.addingTimeInterval(LidCloseConfirm.pulseInterval)),
            .closed
        )
        XCTAssertFalse(confirm.isPendingClose)
        XCTAssertTrue(confirm.confirmedClosed)
    }
}
