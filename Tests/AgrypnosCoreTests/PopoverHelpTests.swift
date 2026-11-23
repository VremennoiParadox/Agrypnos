import XCTest
@testable import AgrypnosCore

final class PopoverHelpTests: XCTestCase {
    private let others: [PopoverCard] = [.autoArm, .settle, .terminalBusy, .notifEnable, .notifDiscord, .notifTelegram]

    /// Collapsed, every card still says what its control does in one or two plain lines.
    func testShortLinesArePlainAndShorterThanTheFullHelp() {
        for card in others {
            let short = PopoverHelp.short(card)
            XCTAssertFalse(short.isEmpty, "\(card)")
            XCTAssertLessThan(short.count, PopoverHelp.full(card).count, "\(card)")
            XCTAssertLessThanOrEqual(PopoverHelp.lines(short), 2, "\(card)")
            for banned in ["thinking", "finished", "job", "agent stopped"] {
                XCTAssertFalse(short.lowercased().contains(banned), "\(card): \(banned)")
            }
        }
        for option in DurationOption.presets + [.customMinutes(33)] {
            let short = PopoverHelp.durationShort(option)
            XCTAssertLessThanOrEqual(PopoverHelp.lines(short), 2)
            XCTAssertFalse(short.lowercased().contains("thermal"))
        }
    }

    /// Expanding swaps in today's full help, so every existing copy check still holds.
    func testExpandedShowsTheFullHelpAndCollapsedTheShortLine() {
        for card in others {
            XCTAssertEqual(PopoverHelp.text(card, expanded: true), PopoverHelp.full(card))
            XCTAssertEqual(PopoverHelp.text(card, expanded: false), PopoverHelp.short(card))
        }
        XCTAssertEqual(PopoverHelp.full(.settle), AgrypnosCopy.settleGraceHelp)
        XCTAssertEqual(PopoverHelp.full(.notifDiscord), AgrypnosCopy.notifDiscordHelp)
    }

    /// A card grows by exactly the extra help when its chevron opens it. Collapsed is the default.
    func testExpandingACardGrowsItByTheExtraHelpOnly() {
        let sections: [(PopoverSection, PopoverCard, KeyPath<PopoverStackLayout, PopoverSlot?>)] = [
            (.watch, .duration, \.duration), (.watch, .autoArm, \.autoArm),
            (.agents, .settle, \.settle), (.agents, .terminalBusy, \.terminalBusy),
            (.notif, .notifEnable, \.notifEnable), (.notif, .notifDiscord, \.notifDiscord),
            (.notif, .notifTelegram, \.notifTelegram),
        ]
        for (section, card, slot) in sections {
            let collapsed = PopoverStackLayout.make(section: section)[keyPath: slot]!.height
            let expanded = PopoverStackLayout.make(section: section, expandedHelp: [card])[keyPath: slot]!.height
            XCTAssertGreaterThan(expanded, collapsed, "\(card)")
            if card != .duration {
                XCTAssertEqual(expanded - collapsed,
                               PopoverHelp.height(card, expanded: true) - PopoverHelp.height(card, expanded: false), "\(card)")
            }
        }
    }

    func testOnlyTheListedCardsCollapse() {
        XCTAssertEqual(PopoverHelp.cards, [.duration, .autoArm, .settle, .terminalBusy, .notifEnable, .notifDiscord, .notifTelegram])
        XCTAssertFalse(PopoverHelp.cards.contains(.panelPower), "Power A/B caption stays visible")
    }
}
