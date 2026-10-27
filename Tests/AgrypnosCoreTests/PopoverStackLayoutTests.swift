import XCTest
@testable import AgrypnosCore

final class PopoverStackLayoutTests: XCTestCase {
    func testCardsStackTopToBottomWithoutOverlap() {
        let watch = PopoverStackLayout.make(section: .watch)
        let power = PopoverStackLayout.make(section: .power)
        let agents = PopoverStackLayout.make(section: .agents)
        let notif = PopoverStackLayout.make(section: .notif)
        let general = PopoverStackLayout.make(section: .general)
        assertStacked(watch.stackedCards, firstY: PopoverStackLayout.firstCardY)
        assertStacked(power.stackedCards, firstY: PopoverStackLayout.firstCardY)
        assertStacked(agents.stackedCards, firstY: PopoverStackLayout.firstCardY)
        assertStacked(notif.stackedCards, firstY: PopoverStackLayout.firstCardY)
        assertStacked(general.stackedCards, firstY: PopoverStackLayout.firstCardY)
        XCTAssertEqual(notif.stackedCards.count, 6)
        XCTAssertEqual(watch.watch?.y, PopoverStackLayout.firstCardY)
        XCTAssertGreaterThanOrEqual(general.shortcutY!, general.login!.maxY)
        XCTAssertGreaterThanOrEqual(general.hotkeyHint!.y, general.shortcutY!)
        XCTAssertGreaterThanOrEqual(general.quitY!, general.hotkeyHint!.maxY)
        XCTAssertEqual(general.contentHeight, general.quitY! + PopoverStackLayout.quitReserve)
        XCTAssertEqual(
            watch.popoverHeight,
            min(watch.contentHeight, PopoverStackLayout.maxVisibleHeight)
        )
        XCTAssertEqual(watch.needsScroll, watch.contentHeight > watch.popoverHeight)
        XCTAssertLessThanOrEqual(watch.popoverHeight, PopoverStackLayout.maxVisibleHeight)
    }

    func testWatchCaptionSlotHoldsLeftoverBatteryWrap() {
        let off = PopoverStackLayout.make(section: .watch)
        let layout = PopoverStackLayout.make(section: .watch, showsWatchCaption: true)
        XCTAssertEqual(
            off.watch!.height,
            PopoverStackLayout.inset + 28 + PopoverStackLayout.inset
        )
        XCTAssertGreaterThanOrEqual(
            PopoverCopyLayout.captionMaxLines,
            CopyWrap.lineCount(
                AgrypnosCopy.leftoverCaption(floor: 100, lidClosed: false),
                columns: PopoverCopyLayout.innerColumns
            )
        )
        XCTAssertEqual(
            layout.watch!.height,
            PopoverStackLayout.inset + 28 + PopoverCopyLayout.captionHeightPoints + PopoverStackLayout.inset
        )
        XCTAssertEqual(
            PopoverCopyLayout.captionHeightPoints,
            PopoverCopyLayout.captionMaxLines * PopoverCopyLayout.lineHeightPoints
        )
    }

    func testHygieneSettleAndRampSlotsFitNativeControls() {
        let watch = PopoverStackLayout.make(section: .watch)
        let power = PopoverStackLayout.make(section: .power)
        let agents = PopoverStackLayout.make(section: .agents)
        let general = PopoverStackLayout.make(section: .general)
        XCTAssertGreaterThanOrEqual(
            power.hygiene!.height,
            2 * PopoverStackLayout.switchRowHeight
                + PopoverCopyLayout.helpHeightPoints
                + PopoverStackLayout.sliderBlockHeight
        )
        XCTAssertGreaterThanOrEqual(
            agents.settle!.height,
            PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.settleHelpHeightPoints
                + PopoverStackLayout.sliderBlockHeight
        )
        XCTAssertGreaterThanOrEqual(
            power.ramp!.height,
            PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.helpHeightPoints
                + PopoverStackLayout.segmentRowHeight
        )
        XCTAssertEqual(
            power.thermal!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.helpHeightPoints
                + PopoverStackLayout.switchRowHeight
                + PopoverStackLayout.inset
        )
        XCTAssertEqual(
            power.thermal!.height,
            PopoverStackLayout.prefControlY
                + PopoverStackLayout.switchRowHeight
                + PopoverStackLayout.inset
        )
        XCTAssertEqual(watch.duration!.height, 232)
        XCTAssertEqual(power.battery!.height, 88)
        XCTAssertEqual(general.login!.height, 44)
        XCTAssertEqual(general.hotkeyHint!.height, PopoverCopyLayout.hotkeyHintHeightPoints)
        XCTAssertFalse(watch.needsScroll)
        XCTAssertFalse(power.needsScroll)
        XCTAssertFalse(agents.needsScroll)
        XCTAssertFalse(general.needsScroll)
        XCTAssertEqual(watch.popoverHeight, watch.contentHeight)
        XCTAssertLessThan(watch.contentHeight, PopoverStackLayout.maxVisibleHeight)
    }

    func testLoginSwitchRowCentersTheLabelInTheLoginCard() {
        let layout = PopoverStackLayout.make(section: .general)
        XCTAssertEqual(layout.login!.height, PopoverStackLayout.loginCardHeight)
        let y = PopoverStackLayout.loginSwitchRowY
        let below = PopoverStackLayout.loginCardHeight - y - PopoverStackLayout.switchRowLabelHeight
        XCTAssertEqual(y, below)
    }

    private func assertStacked(_ cards: [PopoverSlot], firstY: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(cards.isEmpty, file: file, line: line)
        XCTAssertEqual(cards[0].y, firstY, file: file, line: line)
        for (index, card) in cards.enumerated() {
            XCTAssertGreaterThan(card.height, 0, "card \(index)", file: file, line: line)
            if index > 0 {
                XCTAssertEqual(
                    card.y,
                    cards[index - 1].maxY + PopoverStackLayout.cardGap,
                    "card \(index) smashed into the previous card",
                    file: file,
                    line: line
                )
            }
        }
    }

    func testSwitchControlSitsOnTheLabelMidline() {
        XCTAssertEqual(PopoverStackLayout.switchControlY(labelY: 11, switchHeight: 21), 11.5)
        XCTAssertEqual(PopoverStackLayout.switchControlY(labelY: 10, switchHeight: 22), 10)
        XCTAssertEqual(PopoverStackLayout.switchControlY(labelY: 11, switchHeight: 25), 9.5)
    }

    func testSettleHelpNeedsItsOwnSlotAndKeepsOtherHelpAtTwoLines() {
        let settleLines = CopyWrap.lineCount(
            AgrypnosCopy.settleGraceHelp,
            columns: PopoverCopyLayout.innerColumns
        )
        XCTAssertEqual(PopoverCopyLayout.helpMaxLines, 2)
        XCTAssertEqual(PopoverCopyLayout.helpHeightPoints, 2 * PopoverCopyLayout.lineHeightPoints)
        XCTAssertGreaterThan(settleLines, PopoverCopyLayout.helpMaxLines)
        XCTAssertEqual(settleLines, 8)
        XCTAssertEqual(PopoverCopyLayout.settleHelpMaxLines, 8)
        XCTAssertEqual(
            PopoverCopyLayout.settleHelpHeightPoints,
            8 * PopoverCopyLayout.lineHeightPoints
        )
        XCTAssertGreaterThanOrEqual(
            PopoverCopyLayout.settleHelpHeightPoints,
            settleLines * PopoverCopyLayout.lineHeightPoints
        )
        XCTAssertLessThanOrEqual(
            CopyWrap.lineCount(
                AgrypnosCopy.brightnessFloorHelp,
                columns: PopoverCopyLayout.innerColumns
            ),
            PopoverCopyLayout.helpMaxLines
        )
        XCTAssertLessThanOrEqual(
            CopyWrap.lineCount(
                AgrypnosCopy.lidOpenRampHelp,
                columns: PopoverCopyLayout.innerColumns
            ),
            PopoverCopyLayout.helpMaxLines
        )
        XCTAssertLessThanOrEqual(
            CopyWrap.lineCount(
                AgrypnosCopy.thermalAutoOffHelp,
                columns: PopoverCopyLayout.innerColumns
            ),
            PopoverCopyLayout.helpMaxLines
        )
        XCTAssertEqual(AgentSettleGraceChrome.minLabel, "1m 30s")
        XCTAssertNotEqual(AgentSettleGraceChrome.minLabel, "15s")
        XCTAssertEqual(AgentSettleGraceChrome.maxLabel, "10m")
    }

    func testSettleCardGrowsWithSettleHelpAndLeavesRampThermalOnTheTwoLineSlot() {
        let agents = PopoverStackLayout.make(section: .agents)
        let power = PopoverStackLayout.make(section: .power)
        XCTAssertEqual(
            agents.settle!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.settleHelpHeightPoints
                + PopoverStackLayout.sliderBlockHeight
                + PopoverStackLayout.inset
        )
        XCTAssertGreaterThan(
            PopoverCopyLayout.settleHelpHeightPoints,
            PopoverCopyLayout.helpHeightPoints
        )
        XCTAssertEqual(
            PopoverStackLayout.settleControlY,
            PopoverStackLayout.prefHelpY + PopoverCopyLayout.settleHelpHeightPoints
        )
        XCTAssertEqual(
            PopoverStackLayout.settleMinMaxY,
            PopoverStackLayout.settleControlY + 24
        )
        XCTAssertGreaterThan(
            PopoverStackLayout.settleControlY,
            PopoverStackLayout.prefControlY
        )
        XCTAssertEqual(
            PopoverStackLayout.prefControlY,
            PopoverStackLayout.prefHelpY + PopoverCopyLayout.helpHeightPoints
        )
        XCTAssertEqual(
            power.ramp!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.helpHeightPoints
                + PopoverStackLayout.segmentRowHeight
                + PopoverStackLayout.inset
        )
        XCTAssertEqual(
            power.thermal!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.helpHeightPoints
                + PopoverStackLayout.switchRowHeight
                + PopoverStackLayout.inset
        )
        XCTAssertFalse(agents.needsScroll)
        XCTAssertLessThan(agents.contentHeight, PopoverStackLayout.maxVisibleHeight)
    }

    func testTimeValueSlotFitsOneMinuteThirty() {
        let needed = "1m 30s".count * 9 + 8
        XCTAssertGreaterThan(
            PopoverCopyLayout.timeValueWidthPoints,
            PopoverCopyLayout.percentValueWidthPoints
        )
        XCTAssertGreaterThanOrEqual(PopoverCopyLayout.timeValueWidthPoints, needed)
    }
}
