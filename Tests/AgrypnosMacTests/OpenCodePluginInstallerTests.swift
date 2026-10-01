import Foundation
import XCTest
@testable import AgrypnosMac

final class OpenCodePluginInstallerTests: XCTestCase {
    func testInstallationRegistersGloballyAndRemovalPreservesOtherSettings() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let config = root.appendingPathComponent("config")
        let other = Data(#"{"plugin":["other-plugin"],"theme":"custom"}"#.utf8)
        try other.write(to: config.appendingPathComponent("tui.json"))
        let comments = Data("// Keep my configuration\n{}".utf8)
        try comments.write(to: config.appendingPathComponent("tui.jsonc"))
        let installer = OpenCodePluginInstaller(configRoot: config,
            bridgeRoot: root.appendingPathComponent("bridge"), pluginData: Data("fixture".utf8))
        let plugin = try installer.install()
        XCTAssertEqual(try installer.install(), plugin)
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: config.appendingPathComponent("tui.json"))) as! [String: Any]
        XCTAssertEqual(object["theme"] as? String, "custom")
        XCTAssertEqual(object["plugin"] as? [String], ["other-plugin", plugin.absoluteString])
        XCTAssertEqual(try Data(contentsOf: config.appendingPathComponent("tui.jsonc")), comments)
        try installer.remove()
        let removed = try JSONSerialization.jsonObject(with: Data(contentsOf: config.appendingPathComponent("tui.json"))) as! [String: Any]
        XCTAssertEqual(removed["plugin"] as? [String], ["other-plugin"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: plugin.path))
    }

    func testModifiedPluginAndSymlinkAreRejectedWithoutDeletingThem() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let installer = OpenCodePluginInstaller(configRoot: root.appendingPathComponent("config"),
            bridgeRoot: root.appendingPathComponent("bridge"), pluginData: Data("fixture".utf8))
        let plugin = try installer.install()
        try Data("user changed".utf8).write(to: plugin)
        XCTAssertThrowsError(try installer.install())
        XCTAssertThrowsError(try installer.remove())
        XCTAssertEqual(try String(contentsOf: plugin), "user changed")
        try FileManager.default.removeItem(at: plugin)
        try FileManager.default.createSymbolicLink(at: plugin, withDestinationURL: root.appendingPathComponent("config/tui.json"))
        XCTAssertThrowsError(try installer.install())
    }

    func testUnsupportedConfigFailsBeforeWritingPlugin() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let config = root.appendingPathComponent("config")
        try Data("// not plain JSON".utf8).write(to: config.appendingPathComponent("tui.json"))
        let installer = OpenCodePluginInstaller(configRoot: config,
            bridgeRoot: root.appendingPathComponent("bridge"), pluginData: Data("fixture".utf8))
        XCTAssertThrowsError(try installer.install())
        XCTAssertEqual(try String(contentsOf: config.appendingPathComponent("tui.json")), "// not plain JSON")
    }

    func testEveryWriteFailureRollsBackOwnedArtifacts() throws {
        for boundary in 1...3 {
            let root = try fixture()
            defer { try? FileManager.default.removeItem(at: root) }
            let config = root.appendingPathComponent("config/tui.json")
            let original = Data(#"{"theme":"mine"}"#.utf8)
            try original.write(to: config)
            var installer = OpenCodePluginInstaller(configRoot: root.appendingPathComponent("config"),
                bridgeRoot: root.appendingPathComponent("bridge"), pluginData: Data("fixture".utf8))
            var count = 0
            installer.write = { data, url in
                count += 1
                if count == boundary { throw OpenCodePluginSetupError.writeFailed }
                try OpenCodePrivateFiles.write(data, to: url)
            }
            XCTAssertThrowsError(try installer.install())
            XCTAssertEqual(try Data(contentsOf: config), original)
            XCTAssertFalse(FileManager.default.fileExists(atPath: installer.pluginURL.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("bridge/installation.json").path))
        }
    }

    func testPrivateModesAndSymlinkedParent() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let bridge = root.appendingPathComponent("bridge")
        let installer = OpenCodePluginInstaller(configRoot: root.appendingPathComponent("config"),
            bridgeRoot: bridge, pluginData: Data("fixture".utf8))
        let plugin = try installer.install()
        for (url, expected) in [(bridge, 0o700), (plugin, 0o600), (bridge.appendingPathComponent("installation.json"), 0o600)] {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue, expected)
        }
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root.appendingPathComponent("config"))
        XCTAssertThrowsError(try OpenCodePluginInstaller(configRoot: link, bridgeRoot: bridge,
            pluginData: Data("fixture".utf8)).install())
    }

    private func fixture() throws -> URL {
        let root = URL(fileURLWithPath: "/private/tmp/agrypnos-installer-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("config"), withIntermediateDirectories: true)
        return root
    }
}
