import XCTest
@testable import AgrypnosCore

final class QuestionRelayLayoutTests: XCTestCase {
    func testForwardingSettingsReuseOpenCodeCopyAndSitUnderBusyTools() {
        XCTAssertEqual(QuestionSetupChrome.title, "Forward agent questions")
        XCTAssertEqual(QuestionSetupChrome.enableTitle, "Enable OpenCode forwarding")
        XCTAssertEqual(QuestionSetupChrome.claudeEnableTitle, "Enable Claude Code forwarding")
        XCTAssertEqual(AgrypnosCopy.agentInclude, "Which tools count as busy.")
        XCTAssertFalse(QuestionSetupChrome.title.lowercased().contains("extra"))
        XCTAssertFalse(AgrypnosCopy.agentInclude.lowercased().contains("extra"))
        let tools = PopoverStackLayout.make(section: .agents)
        XCTAssertEqual(
            tools.agentInclude!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.helpHeightPoints
                + AgentKind.allCases.count * PopoverStackLayout.switchRowHeight
                + PopoverStackLayout.inset
        )
    }

    func testQuestionCardsStayOffAgentsAndClosedNotifHidesThem() throws {
        XCTAssertEqual(PopoverSection.agents.cards, [.agentInclude, .settle, .terminalBusy])
        XCTAssertEqual(
            PopoverSection.agents.cards(showQuestionNotifications: true),
            [.agentInclude, .settle, .terminalBusy]
        )
        let notif = PopoverStackLayout.make(section: .notif, showManualOpenCodeConnection: true)
        XCTAssertNotNil(notif.questionNotifications)
        XCTAssertNil(notif.questionRelay)
        XCTAssertNil(notif.pluginConnection)
        XCTAssertNil(notif.claudeHook)
        XCTAssertNil(notif.openCodeQuestions)
        XCTAssertNil(notif.codexAlert)
        XCTAssertNil(notif.cursorQuestionNote)
        XCTAssertNil(notif.questionForwardingBack)
        XCTAssertEqual(notif.notifSetup?.y, PopoverStackLayout.firstCardY)
        XCTAssertEqual(notif.notifEnable?.y, notif.notifSetup!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(notif.stackedCards.count, 8)
        XCTAssertEqual(notif.contentHeight, notif.notifClear!.maxY + PopoverStackLayout.pad)

        let tools = PopoverStackLayout.make(section: .agents)
        XCTAssertNotNil(tools.agentInclude)
        XCTAssertNotNil(tools.settle)
        XCTAssertNotNil(tools.terminalBusy)
        XCTAssertNil(tools.questionRelay)
        XCTAssertNil(tools.pluginConnection)
        XCTAssertNil(tools.claudeHook)
        XCTAssertNil(tools.openCodeQuestions)
        XCTAssertNil(tools.questionForwardingBack)

        let layout = PopoverStackLayout.make(
            section: .notif,
            showQuestionNotifications: true,
            showManualOpenCodeConnection: true
        )
        let forwarding = try XCTUnwrap(layout.questionRelay)
        let connection = try XCTUnwrap(layout.openCodeQuestions)
        XCTAssertEqual(layout.questionNotifications?.y, layout.notifTelegramInbound!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(forwarding.y, layout.questionNotifications!.maxY + PopoverStackLayout.cardGap)
        XCTAssertGreaterThanOrEqual(forwarding.height, QuestionSetupChrome.statusY + QuestionSetupChrome.statusHeight + 12)
        XCTAssertEqual(layout.pluginConnection?.y, forwarding.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(connection.y, layout.pluginConnection!.maxY + PopoverStackLayout.cardGap)
        XCTAssertGreaterThanOrEqual(connection.height, QuestionSetupChrome.connectionButtonsY + 24 + 12)
        XCTAssertEqual(layout.claudeHook?.y, connection.maxY + PopoverStackLayout.cardGap)
        XCTAssertGreaterThanOrEqual(layout.claudeHook!.height, QuestionSetupChrome.claudeStatusY + 32 + 12)
        XCTAssertEqual(layout.codexAlert?.y, layout.claudeHook!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(layout.cursorQuestionNote?.y, layout.codexAlert!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(layout.contentHeight, layout.notifClear!.maxY + PopoverStackLayout.pad)
        XCTAssertNil(layout.questionForwardingBack)
        XCTAssertNil(layout.agentInclude)
        for section in [PopoverSection.watch, .power, .agents, .general] {
            XCTAssertNil(PopoverStackLayout.make(section: section).questionRelay)
            XCTAssertNil(PopoverStackLayout.make(section: section).openCodeQuestions)
            XCTAssertNil(PopoverStackLayout.make(section: section).claudeHook)
            XCTAssertNil(PopoverStackLayout.make(section: section).questionForwardingBack)
        }
    }

    func testOneButtonLayoutKeepsManualFormCollapsedUntilOpened() {
        let compact = PopoverStackLayout.make(section: .notif, showQuestionNotifications: true)
        let manual = PopoverStackLayout.make(
            section: .notif,
            showQuestionNotifications: true,
            showManualOpenCodeConnection: true
        )
        XCTAssertNotNil(compact.pluginConnection)
        XCTAssertNotNil(compact.claudeHook)
        XCTAssertNil(compact.openCodeQuestions)
        XCTAssertNotNil(manual.openCodeQuestions)
        XCTAssertGreaterThan(manual.contentHeight, compact.contentHeight)
        XCTAssertNil(PopoverStackLayout.make(section: .watch).pluginConnection)
        XCTAssertNil(PopoverStackLayout.make(section: .notif).pluginConnection)
    }

    func testQuestionDisclosureAnimatesHeightLikeSectionSwitch() {
        let closed = PopoverStackLayout.make(section: .notif)
        let open = PopoverStackLayout.make(section: .notif, showQuestionNotifications: true)
        XCTAssertGreaterThan(open.contentHeight, closed.contentHeight)
        let reduce = PopoverSectionResize.make(
            from: .notif,
            to: .notif,
            animated: false,
            currentHeight: closed.popoverHeight,
            showQuestionNotifications: true
        )
        XCTAssertFalse(reduce.animatesHeight)
        XCTAssertEqual(reduce.durationSeconds, 0)
        XCTAssertEqual(reduce.timing, .none)
        XCTAssertEqual(reduce.documentHeightDuringMotion, open.contentHeight)
        let motion = PopoverSectionResize.make(
            from: .notif,
            to: .notif,
            animated: true,
            currentHeight: min(400, closed.popoverHeight - 1),
            showQuestionNotifications: true
        )
        XCTAssertTrue(motion.animatesHeight)
        XCTAssertEqual(motion.durationSeconds, PopoverSectionResize.standardDurationSeconds)
        XCTAssertEqual(motion.durationSeconds, 0.25)
        XCTAssertEqual(motion.timing, .easeInEaseOut)
        XCTAssertTrue(motion.hidesOutgoingImmediately)
        XCTAssertEqual(motion.documentHeightDuringMotion, open.contentHeight)
        XCTAssertEqual(motion.toHeight, open.popoverHeight)
        XCTAssertEqual(motion.scrollIntent, .preserve)
        let back = PopoverSectionResize.make(
            from: .notif,
            to: .notif,
            animated: true,
            currentHeight: open.popoverHeight,
            showQuestionNotifications: false
        )
        XCTAssertTrue(back.hidesOutgoingImmediately)
        XCTAssertEqual(back.documentHeightDuringMotion, closed.contentHeight)
        XCTAssertEqual(back.toHeight, closed.popoverHeight)
        XCTAssertEqual(back.timing, back.animatesHeight ? PopoverSectionResize.Timing.easeInEaseOut : .none)
    }

    func testManualDisclosureKeepsDocumentLargeEnoughForEveryControl() {
        let layout = PopoverStackLayout.make(
            section: .notif,
            showQuestionNotifications: true,
            showManualOpenCodeConnection: true
        )
        let resize = PopoverSectionResize.make(
            from: .notif,
            to: .notif,
            animated: false,
            showQuestionNotifications: true,
            showManualOpenCodeConnection: true
        )
        XCTAssertEqual(resize.documentHeightDuringMotion, layout.contentHeight)
        XCTAssertGreaterThanOrEqual(resize.documentHeightDuringMotion, layout.openCodeQuestions!.maxY + 16)
    }
}
