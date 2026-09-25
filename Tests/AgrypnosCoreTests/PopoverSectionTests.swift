import XCTest
@testable import AgrypnosCore

final class PopoverSectionTests: XCTestCase {
    func testSegmentTitlesAreWatchPowerAgentsNotifGeneral() {
        XCTAssertEqual(PopoverSection.titles, ["Watch", "Power", "Agents", "Notif", "General"])
        XCTAssertEqual(
            PopoverSection.allCases.map(\.title),
            ["Watch", "Power", "Agents", "Notif", "General"]
        )
        XCTAssertEqual(PopoverSection.allCases.count, 5)
        XCTAssertEqual(PopoverSection.watch.title, "Watch")
        XCTAssertEqual(PopoverSection.power.title, "Power")
        XCTAssertEqual(PopoverSection.agents.title, "Agents")
        XCTAssertEqual(PopoverSection.notif.title, "Notif")
        XCTAssertEqual(PopoverSection.general.title, "General")
    }

    func testDefaultOpenSectionIsWatch() {
        XCTAssertEqual(PopoverSection.default, .watch)
        XCTAssertEqual(PopoverSection.watch.rawValue, 0)
        XCTAssertEqual(PopoverStackLayout.make().section, .watch)
        XCTAssertEqual(PopoverSection(rawValue: 0), .watch)
        XCTAssertEqual(PopoverSection(rawValue: 1), .power)
        XCTAssertEqual(PopoverSection(rawValue: 2), .agents)
        XCTAssertEqual(PopoverSection(rawValue: 3), .notif)
        XCTAssertEqual(PopoverSection(rawValue: 4), .general)
        XCTAssertNil(PopoverSection(rawValue: 5))
        XCTAssertNil(PopoverSection(rawValue: -1))
    }

    func testSwitcherIncludesNotifAndOmitsLicenceAndAbout() {
        let titles = PopoverSection.titles
        XCTAssertEqual(titles, ["Watch", "Power", "Agents", "Notif", "General"])
        XCTAssertEqual(titles.firstIndex(of: "Notif"), titles.firstIndex(of: "Agents").map { $0 + 1 })
        XCTAssertEqual(titles.firstIndex(of: "General"), titles.firstIndex(of: "Notif").map { $0 + 1 })
        for banned in ["Licence", "License", "About"] {
            XCTAssertFalse(titles.contains(banned), banned)
        }
        let joined = titles.joined(separator: " ").lowercased()
        XCTAssertFalse(joined.contains("licence"))
        XCTAssertFalse(joined.contains("license"))
        XCTAssertFalse(joined.contains("about"))
    }

    func testCardMapKeepsExistingControlsAndFillsNotif() {
        XCTAssertEqual(PopoverSection.watch.cards, [.watch, .duration, .lastWatchEnd])
        XCTAssertEqual(PopoverSection.power.cards, [.panelPower, .hygiene, .battery, .ramp, .thermal])
        XCTAssertTrue(PopoverSection.power.cards.contains(.thermal))
        XCTAssertEqual(PopoverSection.power.cards.first, .panelPower)
        XCTAssertEqual(PopoverSection.power.cards.last, .thermal)
        XCTAssertEqual(PopoverSection.agents.cards, [.agentInclude, .settle])
        XCTAssertEqual(PopoverSection.agents.cards.first, .agentInclude)
        XCTAssertEqual(PopoverSection.agents.cards.last, .settle)
        XCTAssertEqual(
            PopoverSection.notif.cards,
            [
                .notifEnable,
                .notifDiscord,
                .notifTelegram,
                .notifTelegramInbound,
                .notifSetup,
                .notifClear,
            ]
        )
        XCTAssertEqual(PopoverSection.general.cards, [.login])
        XCTAssertFalse(PopoverSection.agents.cards.contains(.watch))
        XCTAssertFalse(PopoverSection.power.cards.contains(.settle))
        XCTAssertFalse(PopoverSection.power.cards.contains(.agentInclude))
        XCTAssertFalse(PopoverSection.watch.cards.contains(.agentInclude))
        XCTAssertFalse(PopoverSection.notif.cards.contains(.agentInclude))
        XCTAssertFalse(PopoverSection.notif.cards.isEmpty)
    }
}

final class PopoverSectionLayoutTests: XCTestCase {
    func testSwitcherSitsAboveTheFirstCard() {
        let layout = PopoverStackLayout.make()
        XCTAssertEqual(layout.sectionSwitcher.y, PopoverStackLayout.sectionSwitcherY)
        XCTAssertEqual(layout.sectionSwitcher.height, PopoverStackLayout.sectionSwitcherHeight)
        XCTAssertEqual(
            layout.watch?.y,
            layout.sectionSwitcher.maxY + PopoverStackLayout.cardGap
        )
        XCTAssertEqual(
            PopoverStackLayout.firstCardY,
            PopoverStackLayout.sectionSwitcherY
                + PopoverStackLayout.sectionSwitcherHeight
                + PopoverStackLayout.cardGap
        )
    }

    func testWatchSectionShowsArmDurationAndLastEnd() {
        let layout = PopoverStackLayout.make(section: .watch)
        XCTAssertEqual(layout.stackedCards.map(\.y), compactYs(layout.watch, layout.duration, layout.lastWatchEnd))
        XCTAssertEqual(layout.lastWatchEnd?.y, layout.duration!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(
            layout.lastWatchEnd?.height,
            PopoverStackLayout.inset + PopoverCopyLayout.lastWatchEndHeightPoints + PopoverStackLayout.inset
        )
        XCTAssertNil(layout.hygiene)
        XCTAssertEqual(layout.contentHeight, layout.lastWatchEnd!.maxY + PopoverStackLayout.pad)
        XCTAssertFalse(layout.needsScroll)
    }

    func testPowerSectionShowsHygieneBatteryRampAndThermal() {
        let layout = PopoverStackLayout.make(section: .power)
        XCTAssertEqual(layout.section, .power)
        XCTAssertEqual(
            layout.stackedCards.map(\.y),
            compactYs(layout.panelPower, layout.hygiene, layout.battery, layout.ramp, layout.thermal)
        )
        XCTAssertEqual(layout.panelPower?.y, PopoverStackLayout.firstCardY)
        XCTAssertEqual(layout.hygiene?.y, layout.panelPower!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(layout.battery?.y, layout.hygiene!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(layout.ramp?.y, layout.battery!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(layout.thermal?.y, layout.ramp!.maxY + PopoverStackLayout.cardGap)
        XCTAssertNil(layout.watch)
        XCTAssertNil(layout.duration)
        XCTAssertNil(layout.settle)
        XCTAssertNil(layout.agentInclude)
        XCTAssertNil(layout.login)
        XCTAssertNil(layout.quitY)
        XCTAssertEqual(layout.contentHeight, layout.thermal!.maxY + PopoverStackLayout.pad)
    }

    func testAgentsSectionShowsIncludeThenIdleWait() {
        let layout = PopoverStackLayout.make(section: .agents)
        XCTAssertEqual(layout.section, .agents)
        XCTAssertEqual(layout.stackedCards, [layout.agentInclude!, layout.settle!])
        XCTAssertEqual(layout.agentInclude?.y, PopoverStackLayout.firstCardY)
        XCTAssertEqual(layout.settle?.y, layout.agentInclude!.maxY + PopoverStackLayout.cardGap)
        XCTAssertNil(layout.watch)
        XCTAssertNil(layout.duration)
        XCTAssertNil(layout.hygiene)
        XCTAssertNil(layout.battery)
        XCTAssertNil(layout.ramp)
        XCTAssertNil(layout.thermal)
        XCTAssertNil(layout.login)
        XCTAssertEqual(layout.contentHeight, layout.settle!.maxY + PopoverStackLayout.pad)
        XCTAssertFalse(layout.needsScroll)
        XCTAssertLessThan(layout.contentHeight, PopoverStackLayout.maxVisibleHeight)
    }

    func testAgentIncludeCardFitsFourSwitchesAndHelp() {
        let layout = PopoverStackLayout.make(section: .agents)
        XCTAssertEqual(AgentKind.allCases.count, 4)
        XCTAssertEqual(AgentIncludeChrome.titles, ["Cursor", "Claude Code", "Codex", "OpenCode"])
        XCTAssertEqual(
            layout.agentInclude!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.helpHeightPoints
                + AgentKind.allCases.count * PopoverStackLayout.switchRowHeight
                + PopoverStackLayout.inset
        )
        XCTAssertEqual(PopoverStackLayout.includeSwitchY(index: 0), PopoverStackLayout.prefControlY)
        XCTAssertEqual(
            PopoverStackLayout.includeSwitchY(index: 3),
            PopoverStackLayout.prefControlY + 3 * PopoverStackLayout.switchRowHeight
        )
        XCTAssertEqual(
            PopoverStackLayout.includeSwitchY(index: 3) + PopoverStackLayout.switchRowHeight
                + PopoverStackLayout.inset,
            layout.agentInclude!.height
        )
        XCTAssertLessThanOrEqual(
            CopyWrap.lineCount(AgrypnosCopy.agentIncludeHelp, columns: PopoverCopyLayout.innerColumns),
            PopoverCopyLayout.helpMaxLines
        )
        XCTAssertLessThanOrEqual(
            CopyWrap.lineCount(AgrypnosCopy.agentInclude, columns: PopoverCopyLayout.innerColumns),
            1
        )
        XCTAssertEqual(AgrypnosCopy.agentInclude, "Which tools count as busy.")
        XCTAssertEqual(
            AgrypnosCopy.agentIncludeHelp,
            "Only selected tools count as busy. Keep at least one on."
        )
        XCTAssertFalse(AgrypnosCopy.agentInclude.lowercased().contains("we track every"))
        XCTAssertFalse(AgrypnosCopy.agentIncludeHelp.lowercased().contains("every ai"))
        XCTAssertFalse(AgrypnosCopy.agentIncludeHelp.lowercased().contains("still thinking"))
        XCTAssertNil(PopoverStackLayout.make(section: .watch).agentInclude)
        XCTAssertNil(PopoverStackLayout.make(section: .power).agentInclude)
        XCTAssertNil(PopoverStackLayout.make(section: .notif).agentInclude)
        XCTAssertNil(PopoverStackLayout.make(section: .general).agentInclude)
    }

    func testNotifSectionShowsEnableDiscordTelegramInboundSetupAndClear() {
        let layout = PopoverStackLayout.make(section: .notif)
        XCTAssertEqual(layout.section, .notif)
        XCTAssertEqual(layout.stackedCards.count, 6)
        XCTAssertEqual(layout.notifEnable?.y, PopoverStackLayout.firstCardY)
        XCTAssertNil(layout.watch)
        XCTAssertNil(layout.duration)
        XCTAssertNil(layout.hygiene)
        XCTAssertNil(layout.battery)
        XCTAssertNil(layout.ramp)
        XCTAssertNil(layout.thermal)
        XCTAssertNil(layout.settle)
        XCTAssertNil(layout.agentInclude)
        XCTAssertNil(layout.login)
        XCTAssertNil(layout.shortcutY)
        XCTAssertNil(layout.quitY)
        XCTAssertEqual(layout.contentHeight, layout.notifClear!.maxY + PopoverStackLayout.pad)
        XCTAssertEqual(
            layout.popoverHeight,
            min(layout.contentHeight, PopoverStackLayout.maxVisibleHeight)
        )
        XCTAssertEqual(layout.needsScroll, layout.contentHeight > layout.popoverHeight)
    }

    func testGeneralSectionShowsLoginHotkeyAndQuit() {
        let layout = PopoverStackLayout.make(section: .general)
        XCTAssertEqual(layout.section, .general)
        XCTAssertEqual(layout.stackedCards, [layout.login!])
        XCTAssertEqual(layout.login?.y, PopoverStackLayout.firstCardY)
        XCTAssertNil(layout.watch)
        XCTAssertNil(layout.hygiene)
        XCTAssertNil(layout.thermal)
        XCTAssertNil(layout.settle)
        XCTAssertNil(layout.agentInclude)
        XCTAssertEqual(layout.shortcutY, layout.login!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(layout.hotkeyHint?.y, layout.shortcutY! + 26)
        XCTAssertEqual(layout.quitY, layout.hotkeyHint!.maxY + 10)
        XCTAssertEqual(layout.contentHeight, layout.quitY! + PopoverStackLayout.quitReserve)
    }

    func testEachSectionFitsWithoutTheOldFullStackScroll() {
        for section in PopoverSection.allCases {
            let layout = PopoverStackLayout.make(section: section)
            XCTAssertEqual(layout.section, section)
            XCTAssertLessThanOrEqual(
                layout.popoverHeight,
                PopoverStackLayout.maxVisibleHeight,
                "\(section.title) popover taller than the 720pt clip"
            )
            XCTAssertGreaterThan(layout.contentHeight, layout.sectionSwitcher.maxY, section.title)
            XCTAssertEqual(
                layout.popoverHeight,
                min(layout.contentHeight, PopoverStackLayout.maxVisibleHeight),
                section.title
            )
            if section == .notif {
                XCTAssertEqual(layout.needsScroll, layout.contentHeight > layout.popoverHeight)
                continue
            }
            XCTAssertLessThanOrEqual(
                layout.contentHeight,
                PopoverStackLayout.maxVisibleHeight,
                "\(section.title) still needs the 720pt clip"
            )
            XCTAssertFalse(layout.needsScroll, section.title)
            XCTAssertEqual(layout.popoverHeight, layout.contentHeight, section.title)
        }
        let watch = PopoverStackLayout.make(section: .watch).contentHeight
        let power = PopoverStackLayout.make(section: .power).contentHeight
        let agents = PopoverStackLayout.make(section: .agents).contentHeight
        let general = PopoverStackLayout.make(section: .general).contentHeight
        XCTAssertGreaterThan(agents, watch)
        XCTAssertLessThan(agents, power)
        XCTAssertLessThan(watch, power)
        XCTAssertLessThan(general, power)
    }

    private func compactYs(_ slots: PopoverSlot?...) -> [Int] {
        slots.compactMap { $0?.y }
    }
}
