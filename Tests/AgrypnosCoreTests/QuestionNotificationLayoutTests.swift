import XCTest
@testable import AgrypnosCore

final class QuestionNotificationLayoutTests: XCTestCase {
    func testDisclosureSitsUnderTelegramInboundAndAgentsStaysTheBusyList() {
        XCTAssertEqual(QuestionSetupChrome.disclosureTitle, "Question notifications")
        XCTAssertEqual(QuestionSetupChrome.beta, "BETA")
        XCTAssertEqual(
            PopoverSection.agents.cards(showQuestionNotifications: true),
            [.agentInclude, .settle, .terminalBusy]
        )
        XCTAssertEqual(
            PopoverSection.notif.cards(showQuestionNotifications: false),
            [
                .notifSetup,
                .notifEnable, .notifDiscord, .notifDiscordInbound, .notifTelegram, .notifTelegramInbound,
                .questionNotifications,
                .notifClear,
            ]
        )
        let open = PopoverSection.notif.cards(showQuestionNotifications: true)
        let inbound = open.firstIndex(of: .notifTelegramInbound)!
        XCTAssertEqual(open[inbound + 1], .questionNotifications)
        XCTAssertEqual(
            Array(open[(inbound + 2)...]),
            [.questionRelay, .pluginConnection, .claudeHook, .codexAlert, .cursorQuestionNote, .notifClear]
        )
        let layout = PopoverStackLayout.make(section: .notif, showQuestionNotifications: true)
        XCTAssertEqual(
            layout.questionNotifications?.y,
            layout.notifTelegramInbound!.maxY + PopoverStackLayout.cardGap
        )
        XCTAssertEqual(layout.cursorQuestionNote?.y, layout.codexAlert!.maxY + PopoverStackLayout.cardGap)
        XCTAssertNil(layout.questionForwardingBack)
        let agents = PopoverStackLayout.make(section: .agents)
        XCTAssertEqual(
            agents.agentInclude!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.helpHeightPoints
                + AgentKind.allCases.count * PopoverStackLayout.switchRowHeight
                + PopoverStackLayout.inset
        )
    }

    func testDisclosureKeepsScrollInsteadOfJumpingToTop() {
        let open = PopoverSectionResize.make(
            from: .notif,
            to: .notif,
            animated: true,
            currentHeight: 400,
            showQuestionNotifications: true
        )
        XCTAssertEqual(open.scrollIntent, .preserve)
        XCTAssertEqual(open.timing, .easeInEaseOut)
        XCTAssertEqual(open.durationSeconds, 0.25)

        let close = PopoverSectionResize.make(
            from: .notif,
            to: .notif,
            animated: true,
            currentHeight: PopoverStackLayout.make(
                section: .notif,
                showQuestionNotifications: true
            ).popoverHeight,
            showQuestionNotifications: false
        )
        XCTAssertEqual(close.scrollIntent, .preserve)

        let reduce = PopoverSectionResize.make(
            from: .notif,
            to: .notif,
            animated: false,
            showQuestionNotifications: true
        )
        XCTAssertEqual(reduce.scrollIntent, .preserve)
        XCTAssertEqual(reduce.timing, .none)

        XCTAssertEqual(
            PopoverSectionResize.make(from: .watch, to: .notif, animated: true).scrollIntent,
            .resetToTop
        )
        XCTAssertEqual(
            PopoverSectionResize.make(from: .notif, to: .agents, animated: true).scrollIntent,
            .resetToTop
        )
    }

    func testCodexAlertAndCursorNoteHugTheirCopy() {
        let helpLines = CopyWrap.lineCount(
            QuestionSetupChrome.codexHelp,
            columns: PopoverCopyLayout.innerColumns
        )
        XCTAssertGreaterThan(helpLines, 2)
        let helpHeight = helpLines * PopoverCopyLayout.lineHeightPoints
        let enableY = QuestionSetupChrome.hookHelpY + helpHeight
        let disableY = enableY + QuestionSetupChrome.hookButtonRowHeight
        let statusY = disableY + QuestionSetupChrome.hookButtonRowHeight
        let codexNeeded = statusY + QuestionSetupChrome.hookStatusHeight + PopoverStackLayout.inset
        XCTAssertGreaterThanOrEqual(QuestionSetupChrome.codexEnableY, enableY)
        XCTAssertGreaterThanOrEqual(QuestionSetupChrome.codexDisableY, disableY)
        XCTAssertGreaterThanOrEqual(QuestionSetupChrome.codexStatusY, statusY)
        XCTAssertGreaterThanOrEqual(QuestionSetupChrome.codexCardHeight, codexNeeded)

        let noteLines = CopyWrap.lineCount(
            QuestionSetupChrome.cursorNote,
            columns: PopoverCopyLayout.innerColumns
        )
        XCTAssertGreaterThan(noteLines, 2)
        let noteNeeded =
            PopoverStackLayout.inset
            + noteLines * PopoverCopyLayout.lineHeightPoints
            + PopoverStackLayout.inset
        XCTAssertGreaterThanOrEqual(QuestionSetupChrome.cursorNoteCardHeight, noteNeeded)

        let layout = PopoverStackLayout.make(section: .notif, showQuestionNotifications: true)
        XCTAssertEqual(layout.codexAlert?.height, QuestionSetupChrome.codexCardHeight)
        XCTAssertEqual(layout.cursorQuestionNote?.height, QuestionSetupChrome.cursorNoteCardHeight)
        XCTAssertEqual(QuestionSetupChrome.codexCardHeight, 232)
        XCTAssertEqual(QuestionSetupChrome.cursorNoteCardHeight, 72)
        XCTAssertGreaterThan(layout.codexAlert!.height, QuestionSetupChrome.claudeCardHeight)
        XCTAssertGreaterThan(layout.cursorQuestionNote!.height, PopoverStackLayout.loginCardHeight)
        XCTAssertEqual(layout.cursorQuestionNote?.y, layout.codexAlert!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(layout.popoverHeight, min(layout.contentHeight, PopoverStackLayout.maxVisibleHeight))
        XCTAssertEqual(layout.needsScroll, layout.contentHeight > layout.popoverHeight)

        let closed = PopoverStackLayout.make(section: .notif)
        XCTAssertEqual(closed.contentHeight, 1054)
        XCTAssertEqual(layout.contentHeight, 2088)
        XCTAssertGreaterThan(layout.contentHeight, closed.contentHeight)
        XCTAssertEqual(closed.popoverHeight, PopoverStackLayout.maxVisibleHeight)
        XCTAssertEqual(layout.popoverHeight, PopoverStackLayout.maxVisibleHeight)
        XCTAssertTrue(closed.needsScroll)
        XCTAssertTrue(layout.needsScroll)
    }
}
