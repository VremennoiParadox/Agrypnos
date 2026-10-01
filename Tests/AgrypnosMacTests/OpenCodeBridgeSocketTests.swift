import Foundation
import Darwin
import XCTest
import AgrypnosCore
@testable import AgrypnosMac

@MainActor
final class OpenCodeBridgeSocketTests: XCTestCase {
    func testAuthenticatedConnectionReceivesFragmentsAndStopRemovesSocket() async throws {
        let config = fixture()
        defer { try? FileManager.default.removeItem(at: config.socketURL.deletingLastPathComponent()) }
        let helloReceived = expectation(description: "hello")
        let askedReceived = expectation(description: "asked")
        let disconnected = expectation(description: "disconnected")
        var connection: OpenCodeBridgeConnectionID?
        let bridge = OpenCodeBridgeSocket(configuration: config, receive: { id, message in
            if case .hello = message { connection = id; helloReceived.fulfill() }
            if case .asked = message { askedReceived.fulfill() }
        }, disconnected: { _ in disconnected.fulfill() })
        try bridge.start()
        let client = try connect(config.socketURL); defer { close(client) }
        let hello = try OpenCodeBridgeMessage.hello(protocolVersion: 1, token: config.token, instanceID: UUID(),
            generation: config.generation, hostVersion: "1.18.32", directory: "/project", projectLabel: nil).encodedFrame()
        for byte in hello { _ = Darwin.write(client, [byte], 1) }
        await fulfillment(of: [helloReceived], timeout: 2)
        XCTAssertNotNil(connection)
        let asked = try OpenCodeBridgeMessage.asked(original: Data("{}".utf8)).encodedFrame()
        asked.withUnsafeBytes { _ = Darwin.write(client, $0.baseAddress!, $0.count) }
        await fulfillment(of: [askedReceived], timeout: 2)
        let attrs = try FileManager.default.attributesOfItem(atPath: config.socketURL.path)
        XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        bridge.stop()
        await fulfillment(of: [disconnected], timeout: 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: config.socketURL.path))
        let sent = await bridge.send(.ready(generation: config.generation), to: connection!)
        XCTAssertFalse(sent)
    }

    func testWrongCredentialAndDuplicateHelloDisconnect() async throws {
        for wrong in [true, false] {
            let config = fixture()
            defer { try? FileManager.default.removeItem(at: config.socketURL.deletingLastPathComponent()) }
            let closed = expectation(description: "closed")
            var allocated = 0
            let bridge = OpenCodeBridgeSocket(configuration: config, receive: { _, message in
                if case .asked = message { allocated += 1 }
            }, disconnected: { _ in closed.fulfill() })
            try bridge.start(); defer { bridge.stop() }
            let client = try connect(config.socketURL); defer { close(client) }
            let hello = try OpenCodeBridgeMessage.hello(protocolVersion: 1, token: wrong ? "wrong" : config.token,
                instanceID: UUID(), generation: config.generation, hostVersion: "1.18.32", directory: "/project", projectLabel: nil).encodedFrame()
            let frames = hello + hello + (try OpenCodeBridgeMessage.asked(original: Data("{}".utf8)).encodedFrame())
            frames.withUnsafeBytes { _ = Darwin.write(client, $0.baseAddress!, $0.count) }
            await fulfillment(of: [closed], timeout: 2)
            XCTAssertEqual(allocated, 0)
        }
    }

    func testIncompleteHelloClosesAndExistingFileIsPreserved() async throws {
        let config = fixture()
        defer { try? FileManager.default.removeItem(at: config.socketURL.deletingLastPathComponent()) }
        let closed = expectation(description: "closed")
        let bridge = OpenCodeBridgeSocket(configuration: config, receive: { _, _ in XCTFail("unauthenticated") },
            disconnected: { _ in closed.fulfill() })
        try bridge.start(); defer { bridge.stop() }
        let client = try connect(config.socketURL); defer { close(client) }
        await fulfillment(of: [closed], timeout: 3)
        bridge.stop()
        try Data("foreign".utf8).write(to: config.socketURL)
        XCTAssertThrowsError(try bridge.start())
        XCTAssertEqual(try String(contentsOf: config.socketURL), "foreign")
    }
    private func fixture() -> OpenCodeBridgeConfiguration {
        OpenCodeBridgeConfiguration(socketURL: URL(fileURLWithPath: "/private/tmp/ag-ipc-" + UUID().uuidString + "/s.sock"),
            token: String(repeating: "a", count: 64), generation: UUID())
    }
    private func connect(_ url: URL) throws -> Int32 {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        var address = sockaddr_un(); address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(url.path.utf8) + [0]
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard result == 0 else { close(fd); throw OpenCodePluginSetupError.writeFailed }
        return fd
    }
}
