import XCTest
@testable import AgrypnosCore

final class PopoverSectionResizeTests: XCTestCase {
    func testEverySectionSwitchAnimatesHeightWithAppleEase() {
        for from in PopoverSection.allCases {
            for to in PopoverSection.allCases where from != to {
                let motion = PopoverSectionResize.make(from: from, to: to, animated: true)
                XCTAssertNotEqual(
                    motion.fromHeight,
                    motion.toHeight,
                    "\(from.title) and \(to.title) share a height — the popover would not move"
                )
                XCTAssertTrue(motion.animatesHeight, "\(from.title) → \(to.title)")
                XCTAssertEqual(motion.durationSeconds, PopoverSectionResize.standardDurationSeconds)
                XCTAssertEqual(motion.durationSeconds, 0.25)
                XCTAssertEqual(motion.timing, .easeInEaseOut)
                XCTAssertTrue(motion.allowsImplicitAnimation)
                XCTAssertEqual(motion.from, from)
                XCTAssertEqual(motion.to, to)
                XCTAssertEqual(
                    motion.fromHeight,
                    PopoverStackLayout.make(section: from).popoverHeight
                )
                XCTAssertEqual(
                    motion.toHeight,
                    PopoverStackLayout.make(section: to).popoverHeight
                )
            }
        }
        XCTAssertEqual(PopoverSection.allCases.count, 5)
    }

    func testSameSectionAndInitialLayoutDoNotAnimate() {
        let same = PopoverSectionResize.make(from: .watch, to: .watch, animated: true)
        XCTAssertFalse(same.animatesHeight)
        XCTAssertEqual(same.durationSeconds, 0)
        XCTAssertEqual(same.timing, .none)
        XCTAssertFalse(same.allowsImplicitAnimation)
        XCTAssertTrue(same.hidesOutgoingImmediately)
        XCTAssertEqual(same.documentHeightDuringMotion, same.toContentHeight)

        let initial = PopoverSectionResize.make(from: .power, to: .watch, animated: false)
        XCTAssertFalse(initial.animatesHeight)
        XCTAssertEqual(initial.durationSeconds, 0)
        XCTAssertEqual(initial.timing, .none)
        XCTAssertFalse(initial.allowsImplicitAnimation)
        XCTAssertTrue(initial.hidesOutgoingImmediately)
        XCTAssertEqual(initial.documentHeightDuringMotion, initial.toContentHeight)
    }

    func testSwitchHidesOutgoingImmediatelyAndSizesDocumentToDestination() {
        for from in PopoverSection.allCases {
            for to in PopoverSection.allCases {
                let motion = PopoverSectionResize.make(from: from, to: to, animated: true)
                let destination = PopoverStackLayout.make(section: to)
                XCTAssertTrue(
                    motion.hidesOutgoingImmediately,
                    "\(from.title) → \(to.title) would keep the old section painted"
                )
                XCTAssertEqual(
                    motion.documentHeightDuringMotion,
                    destination.contentHeight,
                    "\(from.title) → \(to.title) document must match destination, not the taller leftover"
                )
                XCTAssertEqual(motion.documentHeightDuringMotion, motion.toContentHeight)
                XCTAssertEqual(motion.incomingCards, to.cards)
                XCTAssertEqual(motion.outgoingCards, from.cards)
                if from != to {
                    XCTAssertTrue(Set(motion.outgoingCards).isDisjoint(with: motion.incomingCards))
                }
            }
        }
    }

    func testGrowAndShrinkBothHideOutgoingNow() {
        let watch = PopoverStackLayout.make(section: .watch)
        let power = PopoverStackLayout.make(section: .power)
        XCTAssertLessThan(watch.popoverHeight, power.popoverHeight)

        let grow = PopoverSectionResize.make(from: .watch, to: .power, animated: true)
        XCTAssertTrue(grow.animatesHeight)
        XCTAssertGreaterThan(grow.toHeight, grow.fromHeight)
        XCTAssertTrue(grow.hidesOutgoingImmediately)
        XCTAssertEqual(grow.documentHeightDuringMotion, power.contentHeight)

        let shrink = PopoverSectionResize.make(from: .power, to: .watch, animated: true)
        XCTAssertTrue(shrink.animatesHeight)
        XCTAssertLessThan(shrink.toHeight, shrink.fromHeight)
        XCTAssertTrue(shrink.hidesOutgoingImmediately)
        XCTAssertEqual(shrink.documentHeightDuringMotion, watch.contentHeight)
        XCTAssertLessThan(shrink.documentHeightDuringMotion, shrink.fromContentHeight)
    }

    func testMidEaseUsesLiveWindowHeightWithoutKeepingOutgoing() {
        let watch = PopoverStackLayout.make(section: .watch)
        let agents = PopoverStackLayout.make(section: .agents)
        let power = PopoverStackLayout.make(section: .power)
        XCTAssertLessThan(watch.popoverHeight, agents.popoverHeight)
        XCTAssertLessThan(agents.popoverHeight, power.popoverHeight)

        let rest = PopoverSectionResize.make(from: .watch, to: .agents, animated: true)
        XCTAssertTrue(rest.hidesOutgoingImmediately)
        XCTAssertEqual(rest.documentHeightDuringMotion, agents.contentHeight)

        let midEase = PopoverSectionResize.make(
            from: .watch,
            to: .agents,
            animated: true,
            currentHeight: power.popoverHeight
        )
        XCTAssertTrue(midEase.animatesHeight)
        XCTAssertEqual(midEase.fromHeight, watch.popoverHeight)
        XCTAssertEqual(midEase.toHeight, agents.popoverHeight)
        XCTAssertTrue(midEase.hidesOutgoingImmediately)
        XCTAssertEqual(midEase.documentHeightDuringMotion, agents.contentHeight)
        XCTAssertLessThan(midEase.toHeight, power.popoverHeight)
        XCTAssertNotEqual(midEase.toHeight, power.popoverHeight)
    }

    func testNotifDocumentKeepsFullContentHeightNotThe720Clip() {
        let notif = PopoverStackLayout.make(section: .notif)
        XCTAssertTrue(notif.needsScroll)
        XCTAssertEqual(notif.popoverHeight, PopoverStackLayout.maxVisibleHeight)
        XCTAssertGreaterThan(notif.contentHeight, notif.popoverHeight)

        let motion = PopoverSectionResize.make(from: .watch, to: .notif, animated: true)
        XCTAssertTrue(motion.hidesOutgoingImmediately)
        XCTAssertEqual(motion.documentHeightDuringMotion, notif.contentHeight)
        XCTAssertGreaterThan(motion.documentHeightDuringMotion, motion.toHeight)
        XCTAssertEqual(motion.toHeight, notif.popoverHeight)
    }

    func testIncomingAndOutgoingCardsAreTheSectionCardSets() {
        let motion = PopoverSectionResize.make(from: .watch, to: .agents, animated: true)
        XCTAssertEqual(motion.outgoingCards, PopoverSection.watch.cards)
        XCTAssertEqual(motion.incomingCards, PopoverSection.agents.cards)
        XCTAssertTrue(Set(motion.outgoingCards).isDisjoint(with: motion.incomingCards))
        XCTAssertFalse(motion.incomingCards.isEmpty)
        XCTAssertFalse(motion.outgoingCards.isEmpty)
    }
}
