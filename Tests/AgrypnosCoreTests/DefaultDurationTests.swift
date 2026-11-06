import XCTest
@testable import AgrypnosCore

final class DefaultDurationTests: XCTestCase {
    /// New installs start on Agents (human decision 2026-11-06), matching the README Quick start and Auto-on.
    func testNewInstallsStartOnAgents() {
        XCTAssertEqual(UserPreferences.default.duration, .untilAgentsSettle)
        XCTAssertEqual(UserPreferences().duration, .untilAgentsSettle)
        XCTAssertEqual(WatchEngine().preferences.duration, .untilAgentsSettle)
    }

    /// A saved preferences file keeps the How long the user picked.
    func testSavedHowLongSurvivesTheNewDefault() throws {
        var prefs = UserPreferences.default
        prefs.duration = .indefinite
        let loaded = try JSONDecoder().decode(UserPreferences.self, from: JSONEncoder().encode(prefs))
        XCTAssertEqual(loaded.duration, .indefinite)
    }
}
