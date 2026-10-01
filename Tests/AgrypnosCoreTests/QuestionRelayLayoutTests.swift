import XCTest
@testable import AgrypnosCore

final class QuestionRelayLayoutTests: XCTestCase {
    func testQuestionSetupFitsItsCardsAndAppearsOnlyInNotif() throws {
        let layout = PopoverStackLayout.make(section: .notif)
        let forwarding = try XCTUnwrap(layout.questionRelay)
        let connection = try XCTUnwrap(layout.openCodeQuestions)
        XCTAssertGreaterThanOrEqual(forwarding.height, QuestionSetupChrome.statusY + QuestionSetupChrome.statusHeight + 12)
        XCTAssertGreaterThanOrEqual(connection.height, QuestionSetupChrome.connectionButtonsY + 24 + 12)
        XCTAssertEqual(connection.y, forwarding.maxY + 10)
        XCTAssertEqual(layout.notifSetup?.y, connection.maxY + 10)
        XCTAssertEqual(layout.contentHeight, layout.notifClear!.maxY + 16)
        for section in [PopoverSection.watch, .power, .agents, .general] {
            XCTAssertNil(PopoverStackLayout.make(section: section).questionRelay)
            XCTAssertNil(PopoverStackLayout.make(section: section).openCodeQuestions)
        }
    }
}
