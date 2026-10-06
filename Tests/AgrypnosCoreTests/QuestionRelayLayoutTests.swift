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
            PopoverStackLayout.includeForwardingButtonY,
            PopoverStackLayout.includeSwitchY(index: AgentKind.allCases.count)
        )
        XCTAssertEqual(
            tools.agentInclude!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.helpHeightPoints
                + AgentKind.allCases.count * PopoverStackLayout.switchRowHeight
                + PopoverStackLayout.switchRowHeight
                + PopoverStackLayout.inset
        )
        XCTAssertEqual(
            PopoverStackLayout.includeForwardingButtonY + PopoverStackLayout.switchRowHeight
                + PopoverStackLayout.inset,
            tools.agentInclude!.height
        )
    }

    func testQuestionCardsMoveToAgentsButtonAndLeaveNotif() throws {
        XCTAssertEqual(
            PopoverSection.notif.cards,
            [
                .notifSetup,
                .notifEnable, .notifDiscord, .notifDiscordInbound, .notifTelegram, .notifTelegramInbound,
                .notifClear,
            ]
        )
        XCTAssertEqual(
            PopoverSection.agents.cards(showQuestionForwarding: true),
            [.questionForwardingBack, .questionRelay, .pluginConnection, .claudeHook, .openCodeQuestions]
        )
        XCTAssertEqual(PopoverSection.agents.cards, [.agentInclude, .settle, .terminalBusy])
        XCTAssertFalse(PopoverSection.agents.cards(showQuestionForwarding: true).contains(.agentInclude))

        let notif = PopoverStackLayout.make(section: .notif, showManualOpenCodeConnection: true)
        XCTAssertNil(notif.questionRelay)
        XCTAssertNil(notif.pluginConnection)
        XCTAssertNil(notif.claudeHook)
        XCTAssertNil(notif.openCodeQuestions)
        XCTAssertNil(notif.questionForwardingBack)
        XCTAssertEqual(notif.notifSetup?.y, PopoverStackLayout.firstCardY)
        XCTAssertEqual(notif.notifEnable?.y, notif.notifSetup!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(notif.stackedCards.count, 7)
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
            section: .agents,
            showQuestionForwarding: true,
            showManualOpenCodeConnection: true
        )
        let back = try XCTUnwrap(layout.questionForwardingBack)
        let forwarding = try XCTUnwrap(layout.questionRelay)
        let connection = try XCTUnwrap(layout.openCodeQuestions)
        XCTAssertEqual(back.y, PopoverStackLayout.firstCardY)
        XCTAssertEqual(back.height, PopoverStackLayout.loginCardHeight)
        XCTAssertEqual(forwarding.y, back.maxY + PopoverStackLayout.cardGap)
        XCTAssertGreaterThanOrEqual(forwarding.height, QuestionSetupChrome.statusY + QuestionSetupChrome.statusHeight + 12)
        XCTAssertEqual(layout.pluginConnection?.y, forwarding.maxY + 10)
        XCTAssertEqual(layout.claudeHook?.y, layout.pluginConnection!.maxY + 10)
        XCTAssertGreaterThanOrEqual(layout.claudeHook!.height, QuestionSetupChrome.claudeStatusY + 32 + 12)
        XCTAssertEqual(connection.y, layout.claudeHook!.maxY + 10)
        XCTAssertGreaterThanOrEqual(connection.height, QuestionSetupChrome.connectionButtonsY + 24 + 12)
        XCTAssertEqual(layout.contentHeight, connection.maxY + PopoverStackLayout.pad)
        XCTAssertNil(layout.agentInclude)
        XCTAssertNil(layout.settle)
        XCTAssertNil(layout.terminalBusy)
        XCTAssertNil(layout.notifSetup)
        for section in [PopoverSection.watch, .power, .notif, .general] {
            XCTAssertNil(PopoverStackLayout.make(section: section).questionRelay)
            XCTAssertNil(PopoverStackLayout.make(section: section).openCodeQuestions)
            XCTAssertNil(PopoverStackLayout.make(section: section).claudeHook)
            XCTAssertNil(PopoverStackLayout.make(section: section).questionForwardingBack)
        }
    }

    func testOneButtonLayoutKeepsManualFormCollapsedInAgents() {
        let compact = PopoverStackLayout.make(section: .agents, showQuestionForwarding: true)
        let manual = PopoverStackLayout.make(
            section: .agents,
            showQuestionForwarding: true,
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

    func testAgentsQuestionPaneAnimatesHeightLikeSectionSwitch() {
        let tools = PopoverStackLayout.make(section: .agents)
        let questions = PopoverStackLayout.make(section: .agents, showQuestionForwarding: true)
        XCTAssertNotEqual(tools.popoverHeight, questions.popoverHeight)
        let reduce = PopoverSectionResize.make(
            from: .agents,
            to: .agents,
            animated: false,
            currentHeight: tools.popoverHeight,
            showQuestionForwarding: true
        )
        XCTAssertFalse(reduce.animatesHeight)
        XCTAssertEqual(reduce.durationSeconds, 0)
        XCTAssertEqual(reduce.timing, .none)
        let motion = PopoverSectionResize.make(
            from: .agents,
            to: .agents,
            animated: true,
            currentHeight: tools.popoverHeight,
            showQuestionForwarding: true
        )
        XCTAssertTrue(motion.animatesHeight)
        XCTAssertEqual(motion.durationSeconds, PopoverSectionResize.standardDurationSeconds)
        XCTAssertEqual(motion.durationSeconds, 0.25)
        XCTAssertEqual(motion.timing, .easeInEaseOut)
        XCTAssertTrue(motion.hidesOutgoingImmediately)
        XCTAssertEqual(motion.documentHeightDuringMotion, questions.contentHeight)
        XCTAssertEqual(motion.toHeight, questions.popoverHeight)
        let back = PopoverSectionResize.make(
            from: .agents,
            to: .agents,
            animated: true,
            currentHeight: questions.popoverHeight,
            showQuestionForwarding: false
        )
        XCTAssertTrue(back.animatesHeight)
        XCTAssertEqual(back.timing, .easeInEaseOut)
        XCTAssertTrue(back.hidesOutgoingImmediately)
        XCTAssertEqual(back.documentHeightDuringMotion, tools.contentHeight)
    }

    func testManualDisclosureKeepsDocumentLargeEnoughForEveryControl() {
        let layout = PopoverStackLayout.make(
            section: .agents,
            showQuestionForwarding: true,
            showManualOpenCodeConnection: true
        )
        let resize = PopoverSectionResize.make(
            from: .agents,
            to: .agents,
            animated: false,
            showQuestionForwarding: true,
            showManualOpenCodeConnection: true
        )
        XCTAssertEqual(resize.documentHeightDuringMotion, layout.contentHeight)
        XCTAssertGreaterThanOrEqual(resize.documentHeightDuringMotion, layout.openCodeQuestions!.maxY + 16)
    }
}
