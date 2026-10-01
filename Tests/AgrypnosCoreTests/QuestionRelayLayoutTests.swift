import XCTest
@testable import AgrypnosCore

final class QuestionRelayLayoutTests: XCTestCase {
    func testOneButtonLayoutKeepsManualFormCollapsed() {
        let compact = PopoverStackLayout.make(section: .notif)
        let manual = PopoverStackLayout.make(section: .notif, showManualOpenCodeConnection: true)
        XCTAssertNotNil(compact.pluginConnection)
        XCTAssertNil(compact.openCodeQuestions)
        XCTAssertNotNil(manual.openCodeQuestions)
        XCTAssertGreaterThan(manual.contentHeight, compact.contentHeight)
        XCTAssertNil(PopoverStackLayout.make(section: .watch).pluginConnection)
    }
    func testManualDisclosureKeepsDocumentLargeEnoughForEveryControl() {
        let layout = PopoverStackLayout.make(section: .notif, showManualOpenCodeConnection: true)
        let resize = PopoverSectionResize.make(from: .notif, to: .notif, animated: false,
            showManualOpenCodeConnection: true)
        XCTAssertEqual(resize.documentHeightDuringMotion, layout.contentHeight)
        XCTAssertGreaterThanOrEqual(resize.documentHeightDuringMotion, layout.notifClear!.maxY + 16)
    }
    func testQuestionSetupFitsItsCardsAndAppearsOnlyInNotif() throws {
        let layout = PopoverStackLayout.make(section: .notif, showManualOpenCodeConnection: true)
        let forwarding = try XCTUnwrap(layout.questionRelay)
        let connection = try XCTUnwrap(layout.openCodeQuestions)
        XCTAssertGreaterThanOrEqual(forwarding.height, QuestionSetupChrome.statusY + QuestionSetupChrome.statusHeight + 12)
        XCTAssertGreaterThanOrEqual(connection.height, QuestionSetupChrome.connectionButtonsY + 24 + 12)
        XCTAssertEqual(layout.pluginConnection?.y, forwarding.maxY + 10)
        XCTAssertEqual(connection.y, layout.pluginConnection!.maxY + 10)
        XCTAssertEqual(layout.notifSetup?.y, connection.maxY + 10)
        XCTAssertEqual(layout.contentHeight, layout.notifClear!.maxY + 16)
        for section in [PopoverSection.watch, .power, .agents, .general] {
            XCTAssertNil(PopoverStackLayout.make(section: section).questionRelay)
            XCTAssertNil(PopoverStackLayout.make(section: section).openCodeQuestions)
        }
    }
}
