import Foundation
import XCTest
@testable import AgrypnosCore

final class OpenCodeQuestionSettingsTests: XCTestCase {
    func testMissingPluginPreferenceDefaultsOff() throws {
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(UserPreferences(forwardAgentQuestions: true))) as! [String: Any]
        object.removeValue(forKey: "openCodePluginEnabled")
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(decoded.openCodePluginEnabled)
        XCTAssertTrue(decoded.forwardAgentQuestions)
        var enabled = decoded
        enabled.openCodePluginEnabled = true
        XCTAssertTrue(try JSONDecoder().decode(UserPreferences.self, from: JSONEncoder().encode(enabled)).openCodePluginEnabled)
    }
    // Dropping the nested connection or a pre-existing bot field would break setup.
    func testConnectionRoundTripPreservesExistingBotSecretsAndAnsweringUsers() throws {
        let connection = OpenCodeQuestionSettings(endpoint: "http://127.0.0.1:4096",
            directory: "/project", username: "opencode", password: "fixture")
        let payload = NotifSecretsPayload(telegramBotToken: "fixture-token", telegramChatId: "42",
            discordBotToken: "fixture-discord", discordChannelId: "123456789012345678",
            telegramQuestionUserId: "42", discordQuestionUserId: "223456789012345678",
            openCodeQuestions: connection)
        let data = try XCTUnwrap(NotifSecretsPayload.encode(payload))
        XCTAssertEqual(NotifSecretsPayload.decode(data), payload)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let saved = try XCTUnwrap(object["openCodeQuestions"] as? [String: String])
        XCTAssertEqual(saved["password"], "fixture")
        XCTAssertEqual(saved["directory"], "/project")
    }

    func testLegacySecretsHaveNoConnectionAndKeepTheirBotValues() throws {
        let payload = try XCTUnwrap(NotifSecretsPayload.decode(Data(
            #"{"telegramBotToken":"legacy-token","telegramChatId":"42","discordWebhookURL":"legacy-webhook"}"#.utf8)))
        XCTAssertNil(payload.openCodeQuestions)
        XCTAssertEqual(payload.telegramBotToken, "legacy-token")
        XCTAssertEqual(payload.telegramChatId, "42")
        XCTAssertEqual(payload.discordWebhookURL, "legacy-webhook")
    }

    func testMalformedConnectionDoesNotDiscardBotSecrets() throws {
        let payload = try XCTUnwrap(NotifSecretsPayload.decode(Data(
            #"{"telegramBotToken":"kept","openCodeQuestions":{"endpoint":42}}"#.utf8)))
        XCTAssertEqual(payload.telegramBotToken, "kept")
        XCTAssertNil(payload.openCodeQuestions)
    }

    func testRemovingConnectionPreservesTheBots() throws {
        var payload = NotifSecretsPayload(telegramBotToken: "kept", openCodeQuestions:
            OpenCodeQuestionSettings(endpoint: "http://127.0.0.1:4096", directory: "/project"))
        payload.openCodeQuestions = nil
        let decoded = try XCTUnwrap(NotifSecretsPayload.decode(XCTUnwrap(NotifSecretsPayload.encode(payload))))
        XCTAssertNil(decoded.openCodeQuestions)
        XCTAssertEqual(decoded.telegramBotToken, "kept")
    }
}
