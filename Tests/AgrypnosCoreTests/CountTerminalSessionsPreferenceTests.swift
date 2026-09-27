import XCTest
@testable import AgrypnosCore

final class CountTerminalSessionsPreferenceTests: XCTestCase {
    func testDefaultIsOffAndMissingKeyDecodesOff() throws {
        XCTAssertFalse(UserPreferences.default.countTerminalSessionsAsBusy)
        XCTAssertFalse(UserPreferences().countTerminalSessionsAsBusy)

        let encoded = try JSONEncoder().encode(UserPreferences.default)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["countTerminalSessionsAsBusy"] as? Bool, false)
        let loaded = try JSONDecoder().decode(UserPreferences.self, from: encoded)
        XCTAssertFalse(loaded.countTerminalSessionsAsBusy)

        let json = """
        {"batteryFloorPercent":15,"duration":"indefinite","keyboardBacklightOff":true,"applyBrightnessFloor":true,"brightnessFloorPercent":15,"agentSettleGrace":120,"sessionFreshness":45,"lidOpenRampSeconds":2,"hotkey":{"keyCode":0,"option":true,"command":true,"shift":false,"control":false}}
        """
        let missing = try JSONDecoder().decode(UserPreferences.self, from: Data(json.utf8))
        XCTAssertFalse(missing.countTerminalSessionsAsBusy)
    }

    func testOnRoundTripsAndStaysABool() throws {
        let on = UserPreferences(countTerminalSessionsAsBusy: true)
        XCTAssertTrue(on.countTerminalSessionsAsBusy)
        let data = try JSONEncoder().encode(on)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["countTerminalSessionsAsBusy"] as? Bool, true)
        let loaded = try JSONDecoder().decode(UserPreferences.self, from: data)
        XCTAssertTrue(loaded.countTerminalSessionsAsBusy)

        let off = UserPreferences(countTerminalSessionsAsBusy: false)
        XCTAssertFalse(try JSONDecoder().decode(UserPreferences.self, from: JSONEncoder().encode(off)).countTerminalSessionsAsBusy)
    }

    func testAgentsToggleCopyIsPlainDefaultOffHonesty() {
        XCTAssertEqual(AgrypnosCopy.countTerminalSessions, "Count terminal sessions as busy")
        XCTAssertEqual(
            AgrypnosCopy.countTerminalSessionsHelp,
            "Terminal session files can keep the watch on if this is on. Default off so a noisy terminal doesn’t hold wake."
        )
        let blob = [
            AgrypnosCopy.countTerminalSessions,
            AgrypnosCopy.countTerminalSessionsHelp,
        ].joined(separator: "\n").lowercased()
        for banned in [
            "still thinking",
            "agent finished",
            "we track every",
            "subagents",
            "think-detection",
            "job finished",
        ] {
            XCTAssertFalse(blob.contains(banned), "banned phrase in terminal-busy copy: \(banned)")
        }
        XCTAssertLessThanOrEqual(
            CopyWrap.lineCount(AgrypnosCopy.countTerminalSessions, columns: PopoverCopyLayout.innerColumns),
            1
        )
        XCTAssertEqual(
            CopyWrap.lineCount(
                AgrypnosCopy.countTerminalSessionsHelp,
                columns: PopoverCopyLayout.innerColumns
            ),
            4
        )
        XCTAssertEqual(PopoverCopyLayout.countTerminalSessionsHelpMaxLines, 4)
        XCTAssertLessThanOrEqual(
            CopyWrap.lineCount(
                AgrypnosCopy.countTerminalSessionsHelp,
                columns: PopoverCopyLayout.innerColumns
            ),
            PopoverCopyLayout.countTerminalSessionsHelpMaxLines
        )
        XCTAssertEqual(
            PopoverCopyLayout.countTerminalSessionsHelpHeightPoints,
            PopoverCopyLayout.countTerminalSessionsHelpMaxLines * PopoverCopyLayout.lineHeightPoints
        )
    }

    func testAgentsSectionPutsTheToggleAfterIdleWait() {
        XCTAssertEqual(
            PopoverSection.agents.cards,
            [.agentInclude, .settle, .terminalBusy]
        )
        XCTAssertEqual(PopoverSection.agents.cards.last, .terminalBusy)
        XCTAssertFalse(PopoverSection.watch.cards.contains(.terminalBusy))
        XCTAssertFalse(PopoverSection.power.cards.contains(.terminalBusy))
        XCTAssertFalse(PopoverSection.notif.cards.contains(.terminalBusy))
        XCTAssertFalse(PopoverSection.general.cards.contains(.terminalBusy))

        let layout = PopoverStackLayout.make(section: .agents)
        XCTAssertEqual(
            layout.stackedCards,
            [layout.agentInclude!, layout.settle!, layout.terminalBusy!]
        )
        XCTAssertEqual(layout.settle?.y, layout.agentInclude!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(layout.terminalBusy?.y, layout.settle!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(
            layout.terminalBusy!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.countTerminalSessionsHelpHeightPoints
                + PopoverStackLayout.switchRowHeight
                + PopoverStackLayout.inset
        )
        XCTAssertEqual(layout.contentHeight, layout.terminalBusy!.maxY + PopoverStackLayout.pad)
        XCTAssertLessThanOrEqual(layout.contentHeight, PopoverStackLayout.maxVisibleHeight)
        XCTAssertFalse(layout.needsScroll)
        XCTAssertEqual(layout.popoverHeight, layout.contentHeight)
        XCTAssertEqual(
            PopoverStackLayout.terminalBusyControlY,
            PopoverStackLayout.prefHelpY + PopoverCopyLayout.countTerminalSessionsHelpHeightPoints
        )
        XCTAssertNil(PopoverStackLayout.make(section: .watch).terminalBusy)
        XCTAssertNil(PopoverStackLayout.make(section: .power).terminalBusy)
        XCTAssertNil(PopoverStackLayout.make(section: .notif).terminalBusy)
        XCTAssertNil(PopoverStackLayout.make(section: .general).terminalBusy)
    }
}
