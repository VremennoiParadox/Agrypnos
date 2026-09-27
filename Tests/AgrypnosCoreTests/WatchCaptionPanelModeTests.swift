import XCTest
@testable import AgrypnosCore

final class WatchCaptionPanelModeTests: XCTestCase {
    func testDimPanelCaptionsStayTheBrightnessFloorStory() {
        XCTAssertEqual(
            AgrypnosCopy.captionPrepared(floor: 15, panelPowerMode: .floor),
            AgrypnosCopy.captionPrepared(floor: 15)
        )
        XCTAssertEqual(
            AgrypnosCopy.captionPrepared(floor: 15),
            "Armed. Waiting for lid close — then brightness floor, keyboard backlight off. Auto-off at 15% battery."
        )
        XCTAssertEqual(
            AgrypnosCopy.watchCaption(
                engaged: true, leftover: false, floor: 15, lidClosed: false, panelPowerMode: .floor
            ),
            AgrypnosCopy.captionPrepared(floor: 15)
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(
                engaged: true, leftover: false, onBattery: false, lidClosed: false, panelPowerMode: .floor
            ),
            AgrypnosCopy.menuTooltipOn
        )
    }

    func testSleepPanelArmedCaptionDoesNotLieAboutTheFloor() {
        let caption = AgrypnosCopy.captionPrepared(floor: 15, panelPowerMode: .displaySleep)
        XCTAssertEqual(
            caption,
            "Armed. Waiting for lid close — then the panel sleeps + keyboard backlight off. Keep the watch still holds the Mac awake."
        )
        XCTAssertEqual(
            AgrypnosCopy.watchCaption(
                engaged: true, leftover: false, floor: 15, lidClosed: false, panelPowerMode: .displaySleep
            ),
            caption
        )
        assertSleepPanelHonesty(caption)
        assertFitsCaption(caption)
        assertFitsCaption(AgrypnosCopy.captionPrepared(floor: 100, panelPowerMode: .displaySleep))
    }

    func testSleepPanelLidClosedCaptionKeepsHoldHonesty() {
        let caption = AgrypnosCopy.captionLidClosed(floor: 15, panelPowerMode: .displaySleep)
        XCTAssertEqual(
            caption,
            "Lid closed. Panel sleeps + keyboard backlight off. Keep the watch still holds the Mac awake. Auto-off at 15% battery."
        )
        XCTAssertEqual(
            AgrypnosCopy.watchCaption(
                engaged: true, leftover: false, floor: 15, lidClosed: true, panelPowerMode: .displaySleep
            ),
            caption
        )
        XCTAssertTrue(caption.contains("15%"))
        assertSleepPanelHonesty(caption)
        assertFitsCaption(caption)
        assertFitsCaption(AgrypnosCopy.captionLidClosed(floor: 100, panelPowerMode: .displaySleep))
    }

    func testSleepPanelLeftoverAndTooltipFollowPanelSleep() {
        let open = AgrypnosCopy.leftoverCaption(
            floor: 15, lidClosed: false, panelPowerMode: .displaySleep
        )
        let closed = AgrypnosCopy.leftoverCaption(
            floor: 15, lidClosed: true, panelPowerMode: .displaySleep
        )
        XCTAssertEqual(
            open,
            "Leftover SleepDisabled. Lid close — then the panel sleeps + keyboard backlight off. Keep the watch still holds the Mac awake."
        )
        XCTAssertEqual(
            closed,
            "Leftover SleepDisabled. Lid closed. Panel sleeps + keyboard backlight off. Keep the watch still holds the Mac awake. Auto-off at 15% battery."
        )
        XCTAssertEqual(
            AgrypnosCopy.leftoverNotify(for: .displaySleep),
            "SleepDisabled was already on. Agrypnos adopted it. Lid close still sleeps the panel + keyboard backlight off. Keep the watch still holds the Mac awake."
        )
        XCTAssertEqual(
            AgrypnosCopy.leftoverNotify(for: .floor),
            AgrypnosCopy.leftoverNotify
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(
                engaged: true, leftover: false, onBattery: false, lidClosed: false, panelPowerMode: .displaySleep
            ),
            "Agrypnos: armed. Waiting for lid close — then the panel sleeps + keyboard backlight off. Keep the watch still holds the Mac awake."
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(
                engaged: true, leftover: false, onBattery: true, lidClosed: false, panelPowerMode: .displaySleep
            ),
            "Agrypnos: armed. Waiting for lid close — then the panel sleeps + keyboard backlight off. Keep the watch still holds the Mac awake. On battery."
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(
                engaged: true, leftover: false, onBattery: false, lidClosed: true, panelPowerMode: .displaySleep
            ),
            "Agrypnos: lid closed. Panel sleeps + keyboard backlight off. Keep the watch still holds the Mac awake."
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(
                engaged: true, leftover: true, onBattery: false, lidClosed: false, panelPowerMode: .displaySleep
            ),
            "Agrypnos: adopted leftover SleepDisabled. Waiting for lid close — then the panel sleeps + keyboard backlight off. Keep the watch still holds the Mac awake."
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(
                engaged: true, leftover: true, onBattery: false, lidClosed: true, panelPowerMode: .displaySleep
            ),
            "Agrypnos: adopted leftover SleepDisabled. Lid closed. Panel sleeps + keyboard backlight off. Keep the watch still holds the Mac awake."
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(
                engaged: false, leftover: false, onBattery: false, lidClosed: false, panelPowerMode: .displaySleep
            ),
            AgrypnosCopy.menuTooltipOff
        )
        for blob in [
            open, closed,
            AgrypnosCopy.leftoverNotify(for: .displaySleep),
            AgrypnosCopy.menuTooltip(
                engaged: true, leftover: false, onBattery: true, lidClosed: false, panelPowerMode: .displaySleep
            ),
        ] {
            assertSleepPanelHonesty(blob)
        }
        assertFitsCaption(open)
        assertFitsCaption(closed)
        assertFitsCaption(AgrypnosCopy.leftoverCaption(floor: 100, lidClosed: false, panelPowerMode: .displaySleep))
        assertFitsCaption(AgrypnosCopy.leftoverCaption(floor: 100, lidClosed: true, panelPowerMode: .displaySleep))
    }

    private func assertSleepPanelHonesty(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let lower = text.lowercased()
        XCTAssertTrue(
            lower.contains("keep the watch still holds")
                || lower.contains("still holds the mac awake"),
            "Sleep panel copy must say Keep the watch still holds: \(text)",
            file: file,
            line: line
        )
        XCTAssertFalse(lower.contains("brightness floor"), "Sleep panel must not claim the floor: \(text)", file: file, line: line)
        for banned in [
            "mac asleep",
            "agents stopped",
            "job finished",
            "still thinking",
            "puts the computer to sleep",
            "watt",
            "screen off",
            "display asleep",
        ] {
            XCTAssertFalse(lower.contains(banned), "\(banned) in \(text)", file: file, line: line)
        }
    }

    private func assertFitsCaption(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let lines = CopyWrap.lineCount(text, columns: PopoverCopyLayout.innerColumns)
        XCTAssertLessThanOrEqual(lines, PopoverCopyLayout.captionMaxLines, "\(text) wraps to \(lines)", file: file, line: line)
    }
}
