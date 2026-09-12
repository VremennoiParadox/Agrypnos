import XCTest
@testable import AgrypnosCore

final class BrightnessWritePolicyTests: XCTestCase {
    func testOneExternalScreenDoesNotCountAsBuiltIn() {
        // Lid closed + docked: often one screen, and it is the external.
        XCTAssertFalse(
            BrightnessWritePolicy.shouldWrite(displays: [
                DisplayRecord(isBuiltIn: false, isOnline: true)
            ])
        )
    }

    func testOnlyBuiltInWrites() {
        XCTAssertTrue(
            BrightnessWritePolicy.shouldWrite(displays: [
                DisplayRecord(isBuiltIn: true, isOnline: true)
            ])
        )
    }

    func testBuiltInPlusExternalStillWritesBuiltIn() {
        XCTAssertTrue(
            BrightnessWritePolicy.shouldWrite(displays: [
                DisplayRecord(isBuiltIn: true, isOnline: true),
                DisplayRecord(isBuiltIn: false, isOnline: true)
            ])
        )
    }

    func testOfflineBuiltInWithExternalSkips() {
        XCTAssertFalse(
            BrightnessWritePolicy.shouldWrite(displays: [
                DisplayRecord(isBuiltIn: true, isOnline: false),
                DisplayRecord(isBuiltIn: false, isOnline: true)
            ])
        )
    }

    func testEmptyDisplayListSkips() {
        XCTAssertFalse(BrightnessWritePolicy.shouldWrite(displays: []))
    }
}
