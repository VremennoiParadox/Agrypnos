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
}
