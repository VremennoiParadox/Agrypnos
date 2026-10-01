import Foundation
import XCTest
@testable import AgrypnosCore

final class OpenCodeBridgeMessageTests: XCTestCase {
    func testFragmentedUnicodeAndCoalescedFrames() throws {
        let generation = UUID()
        let hello = OpenCodeBridgeMessage.hello(protocolVersion: 1, token: "secret", instanceID: UUID(),
            generation: generation, hostVersion: "1.18.32", directory: "/tmp/项目", projectLabel: "项目")
        let frame = try hello.encodedFrame()
        var decoder = OpenCodeBridgeFrameDecoder()
        for byte in frame.dropLast() { XCTAssertTrue(try decoder.append(Data([byte])).isEmpty) }
        XCTAssertEqual(try decoder.append(Data([10])), [hello])
        let ready = OpenCodeBridgeMessage.ready(generation: generation)
        XCTAssertEqual(try decoder.append(ready.encodedFrame() + ready.encodedFrame()), [ready, ready])
    }
    func testRejectsMalformedOversizedAndUnknownFields() throws {
        for text in [#"{"type":"ready"}"#, #"{"type":"unknown"}"#,
            #"{"type":"ready","generation":"bad"}"#, #"{"type":"local","sessionID":"s","requestID":"q","extra":true}"#] {
            var decoder = OpenCodeBridgeFrameDecoder()
            XCTAssertThrowsError(try decoder.append(Data((text + "\n").utf8)))
        }
        var decoder = OpenCodeBridgeFrameDecoder()
        XCTAssertThrowsError(try decoder.append(Data(repeating: 65, count: 262144)))
        var invalid = OpenCodeBridgeFrameDecoder()
        XCTAssertThrowsError(try invalid.append(Data([255, 10])))
    }
    func testOriginalIsEmbeddedJSONAndOnlyNativeDeliveriesAllowed() throws {
        let original = Data(#"{"id":"que_abc","sessionID":"s","questions":[]}"#.utf8)
        let message = OpenCodeBridgeMessage.asked(original: original)
        let object = try JSONSerialization.jsonObject(with: message.encodedFrame()) as! [String: Any]
        XCTAssertNotNil(object["original"] as? [String: Any])
        var decoder = OpenCodeBridgeFrameDecoder()
        XCTAssertEqual(try decoder.append(message.encodedFrame()), [message])
        XCTAssertThrowsError(try OpenCodeBridgeMessage.result(attemptID: UUID(), delivery: .returnedToHook).encodedFrame())
    }
}
