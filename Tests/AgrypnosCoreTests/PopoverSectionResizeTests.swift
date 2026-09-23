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
        XCTAssertFalse(same.clipsOutgoingUntilComplete)
        XCTAssertTrue(same.hidesOutgoingImmediately)

        let initial = PopoverSectionResize.make(from: .power, to: .watch, animated: false)
        XCTAssertFalse(initial.animatesHeight)
        XCTAssertEqual(initial.durationSeconds, 0)
        XCTAssertEqual(initial.timing, .none)
        XCTAssertFalse(initial.allowsImplicitAnimation)
        XCTAssertTrue(initial.hidesOutgoingImmediately)
    }

    func testShrinkClipsOutgoingUntilCompleteGrowHidesOutgoingNow() {
        let watch = PopoverStackLayout.make(section: .watch)
        let power = PopoverStackLayout.make(section: .power)
        XCTAssertLessThan(watch.popoverHeight, power.popoverHeight)

        let grow = PopoverSectionResize.make(from: .watch, to: .power, animated: true)
        XCTAssertTrue(grow.animatesHeight)
        XCTAssertGreaterThan(grow.toHeight, grow.fromHeight)
        XCTAssertFalse(grow.clipsOutgoingUntilComplete)
        XCTAssertTrue(grow.hidesOutgoingImmediately)
        XCTAssertEqual(grow.documentHeightDuringMotion, grow.toContentHeight)
        XCTAssertEqual(grow.toContentHeight, power.contentHeight)

        let shrink = PopoverSectionResize.make(from: .power, to: .watch, animated: true)
        XCTAssertTrue(shrink.animatesHeight)
        XCTAssertLessThan(shrink.toHeight, shrink.fromHeight)
        XCTAssertTrue(shrink.clipsOutgoingUntilComplete)
        XCTAssertFalse(shrink.hidesOutgoingImmediately)
        XCTAssertEqual(
            shrink.documentHeightDuringMotion,
            max(shrink.fromContentHeight, shrink.toContentHeight)
        )
        XCTAssertEqual(shrink.fromContentHeight, power.contentHeight)
        XCTAssertEqual(shrink.toContentHeight, watch.contentHeight)
    }

    func testIncomingAndOutgoingCardsAreTheSectionCardSets() {
        let motion = PopoverSectionResize.make(from: .watch, to: .agents, animated: true)
        XCTAssertEqual(motion.outgoingCards, PopoverSection.watch.cards)
        XCTAssertEqual(motion.incomingCards, PopoverSection.agents.cards)
        XCTAssertTrue(Set(motion.outgoingCards).isDisjoint(with: motion.incomingCards))
        XCTAssertFalse(motion.incomingCards.isEmpty)
        XCTAssertFalse(motion.outgoingCards.isEmpty)
    }

    func testShrinkKeepsOutgoingContentUntilTheWindowCatchesUp() {
        for from in PopoverSection.allCases {
            for to in PopoverSection.allCases {
                let motion = PopoverSectionResize.make(from: from, to: to, animated: true)
                XCTAssertEqual(
                    motion.clipsOutgoingUntilComplete,
                    motion.animatesHeight && motion.toHeight < motion.fromHeight,
                    "\(from.title) → \(to.title)"
                )
                XCTAssertEqual(motion.hidesOutgoingImmediately, !motion.clipsOutgoingUntilComplete)
                if motion.clipsOutgoingUntilComplete {
                    XCTAssertGreaterThanOrEqual(
                        motion.documentHeightDuringMotion,
                        motion.fromContentHeight,
                        "\(from.title) → \(to.title) would drop outgoing cards before the window shrinks"
                    )
                }
            }
        }
    }
}
