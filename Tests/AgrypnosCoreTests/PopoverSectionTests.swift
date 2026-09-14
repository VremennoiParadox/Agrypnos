import XCTest
@testable import AgrypnosCore

final class PopoverSectionTests: XCTestCase {
    func testSegmentTitlesAreWatchPowerAgentsGeneral() {
        XCTAssertEqual(PopoverSection.titles, ["Watch", "Power", "Agents", "General"])
        XCTAssertEqual(PopoverSection.allCases.map(\.title), ["Watch", "Power", "Agents", "General"])
        XCTAssertEqual(PopoverSection.allCases.count, 4)
        XCTAssertEqual(PopoverSection.watch.title, "Watch")
        XCTAssertEqual(PopoverSection.power.title, "Power")
        XCTAssertEqual(PopoverSection.agents.title, "Agents")
        XCTAssertEqual(PopoverSection.general.title, "General")
    }

    func testDefaultOpenSectionIsWatch() {
        XCTAssertEqual(PopoverSection.default, .watch)
        XCTAssertEqual(PopoverSection.watch.rawValue, 0)
        XCTAssertEqual(PopoverStackLayout.make().section, .watch)
        XCTAssertEqual(PopoverSection(rawValue: 0), .watch)
        XCTAssertEqual(PopoverSection(rawValue: 1), .power)
        XCTAssertEqual(PopoverSection(rawValue: 2), .agents)
        XCTAssertEqual(PopoverSection(rawValue: 3), .general)
        XCTAssertNil(PopoverSection(rawValue: 4))
        XCTAssertNil(PopoverSection(rawValue: -1))
    }

    func testSwitcherOmitsNotifLicenceAndAbout() {
        let titles = PopoverSection.titles
        XCTAssertEqual(titles, ["Watch", "Power", "Agents", "General"])
        for banned in ["Notif", "Licence", "License", "About"] {
            XCTAssertFalse(titles.contains(banned), banned)
        }
        let joined = titles.joined(separator: " ").lowercased()
        XCTAssertFalse(joined.contains("notif"))
        XCTAssertFalse(joined.contains("licence"))
        XCTAssertFalse(joined.contains("license"))
        XCTAssertFalse(joined.contains("about"))
    }

    func testCardMapKeepsExistingControlsInTheFourSections() {
        XCTAssertEqual(PopoverSection.watch.cards, [.watch, .duration])
        XCTAssertEqual(PopoverSection.power.cards, [.hygiene, .battery, .ramp, .thermal])
        XCTAssertEqual(PopoverSection.agents.cards, [.settle])
        XCTAssertEqual(PopoverSection.general.cards, [.login])
        XCTAssertFalse(PopoverSection.agents.cards.contains(.watch))
        XCTAssertFalse(PopoverSection.power.cards.contains(.settle))
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

    func testWatchSectionShowsArmAndDurationOnly() {
        let layout = PopoverStackLayout.make(section: .watch)
        XCTAssertEqual(layout.section, .watch)
        XCTAssertEqual(layout.stackedCards.map(\.y), compactYs(layout.watch, layout.duration))
        XCTAssertEqual(layout.duration?.y, layout.watch!.maxY + PopoverStackLayout.cardGap)
        XCTAssertNil(layout.hygiene)
        XCTAssertNil(layout.battery)
        XCTAssertNil(layout.ramp)
        XCTAssertNil(layout.thermal)
        XCTAssertNil(layout.settle)
        XCTAssertNil(layout.login)
        XCTAssertNil(layout.shortcutY)
        XCTAssertNil(layout.hotkeyHint)
        XCTAssertNil(layout.quitY)
        XCTAssertEqual(layout.contentHeight, layout.duration!.maxY + PopoverStackLayout.pad)
    }

    func testPowerSectionShowsHygieneBatteryRampAndThermal() {
        let layout = PopoverStackLayout.make(section: .power)
        XCTAssertEqual(layout.section, .power)
        XCTAssertEqual(
            layout.stackedCards.map(\.y),
            compactYs(layout.hygiene, layout.battery, layout.ramp, layout.thermal)
        )
        XCTAssertEqual(layout.hygiene?.y, PopoverStackLayout.firstCardY)
        XCTAssertEqual(layout.battery?.y, layout.hygiene!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(layout.ramp?.y, layout.battery!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(layout.thermal?.y, layout.ramp!.maxY + PopoverStackLayout.cardGap)
        XCTAssertNil(layout.watch)
        XCTAssertNil(layout.duration)
        XCTAssertNil(layout.settle)
        XCTAssertNil(layout.login)
        XCTAssertNil(layout.quitY)
        XCTAssertEqual(layout.contentHeight, layout.thermal!.maxY + PopoverStackLayout.pad)
    }

    func testAgentsSectionShowsIdleWaitOnly() {
        let layout = PopoverStackLayout.make(section: .agents)
        XCTAssertEqual(layout.section, .agents)
        XCTAssertEqual(layout.stackedCards, [layout.settle!])
        XCTAssertEqual(layout.settle?.y, PopoverStackLayout.firstCardY)
        XCTAssertNil(layout.watch)
        XCTAssertNil(layout.duration)
        XCTAssertNil(layout.hygiene)
        XCTAssertNil(layout.battery)
        XCTAssertNil(layout.ramp)
        XCTAssertNil(layout.thermal)
        XCTAssertNil(layout.login)
        XCTAssertEqual(layout.contentHeight, layout.settle!.maxY + PopoverStackLayout.pad)
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
                layout.contentHeight,
                PopoverStackLayout.maxVisibleHeight,
                "\(section.title) still needs the 720pt clip"
            )
            XCTAssertFalse(layout.needsScroll, section.title)
            XCTAssertEqual(layout.popoverHeight, layout.contentHeight, section.title)
            XCTAssertGreaterThan(layout.contentHeight, layout.sectionSwitcher.maxY, section.title)
        }
        let watch = PopoverStackLayout.make(section: .watch).contentHeight
        let power = PopoverStackLayout.make(section: .power).contentHeight
        let agents = PopoverStackLayout.make(section: .agents).contentHeight
        let general = PopoverStackLayout.make(section: .general).contentHeight
        XCTAssertLessThan(agents, watch)
        XCTAssertLessThan(watch, power)
        XCTAssertLessThan(general, power)
    }

    private func compactYs(_ slots: PopoverSlot?...) -> [Int] {
        slots.compactMap { $0?.y }
    }
}
