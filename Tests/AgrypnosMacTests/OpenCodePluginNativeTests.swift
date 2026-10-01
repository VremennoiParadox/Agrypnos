import Foundation
import XCTest
import AgrypnosCore
@testable import AgrypnosMac

@MainActor
final class OpenCodePluginNativeTests: XCTestCase {
    func testProductionPluginRepliesThroughRealSocketToOriginalOpenCodeChat() async throws {
        guard FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/opencode") else {
            throw XCTSkip("OpenCode 1.18.32 native smoke needs the installed binary")
        }
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = URL(fileURLWithPath: "/private/tmp/ag-native-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let configuration = OpenCodeBridgeConfiguration(socketURL: root.appendingPathComponent("s.sock"),
            token: String(repeating: "a", count: 64), generation: UUID())
        let acknowledged = expectation(description: "original native answer acknowledged")
        var batches: [QuestionBatch] = [], deliveries: [QuestionDelivery] = []
        let source = OpenCodePluginQuestionSource(configuration: configuration, uptime: { ProcessInfo.processInfo.systemUptime },
            receive: { batch, submit, _ in
                batches.append(batch)
                Task {
                    let delivery = await submit(QuestionAnswer(key: batch.key,
                        selections: [.init(questionID: "q0", optionIDs: ["o1"])]))
                    deliveries.append(delivery); acknowledged.fulfill()
                }
                return true
            }, resolved: { _ in }, resultTimeout: 10)
        try source.start(); defer { source.stop() }
        let manifest = root.appendingPathComponent("bridge.json")
        try OpenCodePrivateFiles.write(JSONSerialization.data(withJSONObject: ["active": true, "protocolVersion": 1,
            "socketPath": configuration.socketURL.path, "token": configuration.token,
            "generation": configuration.generation.uuidString]), to: manifest)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [repo.appendingPathComponent("Scripts/probes/opencode-tui-fixture.py").path, "bridge", manifest.path]
        let output = Pipe(); process.standardOutput = output; process.standardError = output
        let ended = expectation(description: "native conversation continued")
        process.terminationHandler = { _ in ended.fulfill() }
        try process.run()
        defer { if process.isRunning { process.terminate() } }
        await fulfillment(of: [acknowledged, ended], timeout: 65)
        let log = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        XCTAssertEqual(process.terminationStatus, 0, log)
        XCTAssertEqual(deliveries, [.accepted])
        XCTAssertEqual(batches.count, 1)
        XCTAssertTrue(log.contains("\"markerCount\": 1"), log)
        XCTAssertTrue(log.contains("\"disposed\": true"), log)
        XCTAssertTrue(log.contains(batches.first?.key.sessionID ?? "missing"), log)
    }
}
