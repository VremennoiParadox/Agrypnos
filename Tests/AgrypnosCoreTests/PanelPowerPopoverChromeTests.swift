import XCTest
@testable import AgrypnosCore

final class PanelPowerPopoverChromeTests: XCTestCase {
    func testPowerCardsLeadWithThePanelPicker() {
        XCTAssertEqual(
            PopoverSection.power.cards,
            [.panelPower, .hygiene, .battery, .ramp, .thermal]
        )
        XCTAssertEqual(PopoverSection.power.cards.first, .panelPower)
        XCTAssertEqual(PopoverSection.power.cards.last, .thermal)
        XCTAssertFalse(PopoverSection.watch.cards.contains(.panelPower))
        XCTAssertFalse(PopoverSection.agents.cards.contains(.panelPower))
        XCTAssertFalse(PopoverSection.notif.cards.contains(.panelPower))
        XCTAssertFalse(PopoverSection.general.cards.contains(.panelPower))
    }

    func testPowerAShowsPickerCaptionRampAndHugsWithoutScroll() {
        let layout = PopoverStackLayout.make(section: .power, panelPowerMode: .floor)
        XCTAssertEqual(
            PopoverStackLayout.make(section: .power).stackedCards.map(\.y),
            layout.stackedCards.map(\.y)
        )
        XCTAssertEqual(
            layout.stackedCards.map(\.y),
            compactYs(layout.panelPower, layout.hygiene, layout.battery, layout.ramp, layout.thermal)
        )
        XCTAssertEqual(layout.panelPower?.y, PopoverStackLayout.firstCardY)
        XCTAssertEqual(layout.hygiene?.y, layout.panelPower!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(layout.battery?.y, layout.hygiene!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(layout.ramp?.y, layout.battery!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(layout.thermal?.y, layout.ramp!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(
            layout.panelPower!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.segmentRowHeight
                + PopoverCopyLayout.panelPowerCaptionHeightPoints
                + PopoverStackLayout.inset
        )
        XCTAssertEqual(layout.contentHeight, layout.thermal!.maxY + PopoverStackLayout.pad)
        XCTAssertLessThanOrEqual(layout.contentHeight, PopoverStackLayout.maxVisibleHeight)
        XCTAssertFalse(layout.needsScroll)
        XCTAssertEqual(layout.popoverHeight, layout.contentHeight)
    }

    func testPowerBHidesRampShowsHelpAndStaysUnderTheClip() {
        let dim = PopoverStackLayout.make(section: .power, panelPowerMode: .floor)
        let sleep = PopoverStackLayout.make(section: .power, panelPowerMode: .displaySleep)
        XCTAssertNil(sleep.ramp)
        XCTAssertNotNil(sleep.panelPower)
        XCTAssertEqual(
            sleep.stackedCards.map(\.y),
            compactYs(sleep.panelPower, sleep.hygiene, sleep.battery, sleep.thermal)
        )
        XCTAssertEqual(sleep.panelPower?.y, PopoverStackLayout.firstCardY)
        XCTAssertEqual(sleep.hygiene?.y, sleep.panelPower!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(sleep.battery?.y, sleep.hygiene!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(sleep.thermal?.y, sleep.battery!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(
            sleep.panelPower!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.segmentRowHeight
                + PopoverCopyLayout.panelPowerCaptionHeightPoints
                + PopoverCopyLayout.panelPowerHelpHeightPoints
                + PopoverStackLayout.inset
        )
        XCTAssertGreaterThan(sleep.panelPower!.height, dim.panelPower!.height)
        XCTAssertLessThan(sleep.contentHeight, dim.contentHeight)
        XCTAssertEqual(sleep.contentHeight, sleep.thermal!.maxY + PopoverStackLayout.pad)
        XCTAssertLessThanOrEqual(sleep.contentHeight, PopoverStackLayout.maxVisibleHeight)
        XCTAssertFalse(sleep.needsScroll)
        XCTAssertTrue(PanelPowerChrome.showsLidOpenRamp(.floor))
        XCTAssertFalse(PanelPowerChrome.showsLidOpenRamp(.displaySleep))
    }

    func testPickerCopyUsesCoreChromeAndStaysHonest() {
        XCTAssertEqual(PanelPowerChrome.titles, ["Dim panel", "Sleep panel"])
        XCTAssertEqual(PanelPowerChrome.selectedSegment(mode: .floor), 0)
        XCTAssertEqual(PanelPowerChrome.mode(selectingSegment: 0), .floor)
        XCTAssertEqual(PanelPowerChrome.mode(selectingSegment: 1), .displaySleep)
        XCTAssertEqual(
            PanelPowerChrome.caption(.floor),
            "Brightness floor on confirmed lid close + lid-open ramp. Panel stays on, dimmed."
        )
        XCTAssertEqual(
            PanelPowerChrome.caption(.displaySleep),
            "Panel sleeps on confirmed lid close. Keep the watch still holds the Mac awake."
        )
        XCTAssertEqual(
            PanelPowerChrome.help(.displaySleep),
            "Confirmed lid close sleeps the panel. Keep the watch still holds the Mac awake. Brightness return is hidden because it only applies after the floor path."
        )
        XCTAssertFalse(PanelPowerChrome.caption(.floor).lowercased().contains("display asleep"))
        XCTAssertFalse(PanelPowerChrome.caption(.floor).lowercased().contains("screen off"))
        XCTAssertTrue(PanelPowerChrome.help(.displaySleep).lowercased().contains("hidden"))
        XCTAssertTrue(PanelPowerChrome.help(.displaySleep).lowercased().contains("floor path"))
        let banned = [
            "mac asleep",
            "agents stopped",
            "job finished",
            "still thinking",
            "puts the computer to sleep",
            "watt",
        ]
        for blob in [
            PanelPowerChrome.caption(.floor),
            PanelPowerChrome.caption(.displaySleep),
            PanelPowerChrome.help(.floor),
            PanelPowerChrome.help(.displaySleep),
        ] {
            let lower = blob.lowercased()
            for phrase in banned {
                XCTAssertFalse(lower.contains(phrase), "\(phrase) in \(blob)")
            }
        }
        XCTAssertEqual(
            CopyWrap.lineCount(PanelPowerChrome.caption(.floor), columns: PopoverCopyLayout.innerColumns),
            3
        )
        XCTAssertEqual(
            CopyWrap.lineCount(PanelPowerChrome.caption(.displaySleep), columns: PopoverCopyLayout.innerColumns),
            3
        )
        XCTAssertEqual(
            CopyWrap.lineCount(PanelPowerChrome.help(.displaySleep), columns: PopoverCopyLayout.innerColumns),
            5
        )
        XCTAssertEqual(PopoverCopyLayout.panelPowerCaptionMaxLines, 3)
        XCTAssertEqual(PopoverCopyLayout.panelPowerHelpMaxLines, 5)
        XCTAssertLessThanOrEqual(
            CopyWrap.lineCount(PanelPowerChrome.caption(.floor), columns: PopoverCopyLayout.innerColumns),
            PopoverCopyLayout.panelPowerCaptionMaxLines
        )
        XCTAssertLessThanOrEqual(
            CopyWrap.lineCount(PanelPowerChrome.help(.displaySleep), columns: PopoverCopyLayout.innerColumns),
            PopoverCopyLayout.panelPowerHelpMaxLines
        )
        XCTAssertEqual(PopoverStackLayout.panelPowerControlY, PopoverStackLayout.prefTitleY)
        XCTAssertEqual(
            PopoverStackLayout.panelPowerCaptionY,
            PopoverStackLayout.panelPowerControlY + PopoverStackLayout.segmentRowHeight
        )
        XCTAssertEqual(
            PopoverStackLayout.panelPowerHelpY,
            PopoverStackLayout.panelPowerCaptionY + PopoverCopyLayout.panelPowerCaptionHeightPoints
        )
    }

    func testSwitchingAToBAnimatesHeightFromTheLiveWindow() {
        let dim = PopoverStackLayout.make(section: .power, panelPowerMode: .floor)
        let sleep = PopoverStackLayout.make(section: .power, panelPowerMode: .displaySleep)
        XCTAssertNotEqual(dim.popoverHeight, sleep.popoverHeight)
        let motion = PopoverSectionResize.make(
            from: .power,
            to: .power,
            animated: true,
            currentHeight: dim.popoverHeight,
            panelPowerMode: .displaySleep
        )
        XCTAssertTrue(motion.animatesHeight)
        XCTAssertEqual(motion.durationSeconds, 0.25)
        XCTAssertEqual(motion.timing, .easeInEaseOut)
        XCTAssertEqual(motion.toHeight, sleep.popoverHeight)
        XCTAssertEqual(motion.documentHeightDuringMotion, sleep.contentHeight)
        let back = PopoverSectionResize.make(
            from: .power,
            to: .power,
            animated: true,
            currentHeight: sleep.popoverHeight,
            panelPowerMode: .floor
        )
        XCTAssertTrue(back.animatesHeight)
        XCTAssertEqual(back.toHeight, dim.popoverHeight)
        XCTAssertEqual(back.documentHeightDuringMotion, dim.contentHeight)
    }

    func testBrightnessFloorHelpNamesDimPanelNotSleepPanel() {
        XCTAssertEqual(
            AgrypnosCopy.brightnessFloorHelp,
            "Dim panel: when the lid closes, brightness drops to this percent."
        )
        let lower = AgrypnosCopy.brightnessFloorHelp.lowercased()
        XCTAssertTrue(lower.contains("dim panel"))
        XCTAssertTrue(lower.contains("percent"))
        XCTAssertFalse(lower.contains("display asleep"))
        XCTAssertFalse(lower.contains("sleep panel"))
        XCTAssertLessThanOrEqual(
            CopyWrap.lineCount(
                AgrypnosCopy.brightnessFloorHelp,
                columns: PopoverCopyLayout.innerColumns
            ),
            PopoverCopyLayout.helpMaxLines
        )
    }

    private func compactYs(_ slots: PopoverSlot?...) -> [Int] {
        slots.compactMap { $0?.y }
    }
}
