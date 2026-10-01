import Foundation
import CryptoKit
import Darwin

struct OpenCodePluginInstaller {
    private struct Receipt: Codable {
        let path: String
        let hash: String
    }
    let configRoot: URL
    let bridgeRoot: URL
    let pluginData: Data
    // Tests can fail each write boundary without touching the user's configuration.
    var write: (Data, URL) throws -> Void = { try OpenCodePrivateFiles.write($0, to: $1) }
    var pluginURL: URL { configRoot.appendingPathComponent("agrypnos-opencode.js") }
    private var configURL: URL { configRoot.appendingPathComponent("tui.json") }
    private var receiptURL: URL { bridgeRoot.appendingPathComponent("installation.json") }

    static var defaultConfigRoot: URL {
        let environment = ProcessInfo.processInfo.environment
        if let xdg = environment["XDG_CONFIG_HOME"], xdg.hasPrefix("/") {
            return URL(fileURLWithPath: xdg).appendingPathComponent("opencode")
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/opencode")
    }
    static var defaultBridgeRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Agrypnos/opencode-bridge")
    }

    func install() throws -> URL {
        close(try OpenCodePrivateFiles.directory(configRoot))
        close(try OpenCodePrivateFiles.directory(bridgeRoot, privateOnly: true))
        let oldPlugin = try OpenCodePrivateFiles.read(pluginURL)
        let oldReceipt = try OpenCodePrivateFiles.read(receiptURL)
        let oldConfig = try OpenCodePrivateFiles.read(configURL)
        try checkOwnership(plugin: oldPlugin, receipt: oldReceipt)
        let config = try registration(oldConfig, adding: true)
        let receipt = try JSONEncoder().encode(Receipt(path: pluginURL.path, hash: digest(pluginData)))
        var changed: [(URL, Data?, Data)] = []
        do {
            for (url, old, new) in [(pluginURL, oldPlugin, pluginData), (configURL, oldConfig, config), (receiptURL, oldReceipt, receipt)] {
                if old == new { continue }
                try write(new, url)
                changed.append((url, old, new))
            }
        } catch {
            // Roll back only bytes this invocation wrote; don't erase a concurrent edit.
            for (url, old, new) in changed.reversed() where (try? OpenCodePrivateFiles.read(url)) == new {
                if let old { try? OpenCodePrivateFiles.write(old, to: url) }
                else { try? OpenCodePrivateFiles.remove(url) }
            }
            throw error
        }
        return pluginURL
    }

    func isInstalled() throws -> Bool {
        let receipt = try OpenCodePrivateFiles.read(receiptURL)
        let plugin = try OpenCodePrivateFiles.read(pluginURL)
        guard receipt != nil, plugin != nil else { return false }
        try checkOwnership(plugin: plugin, receipt: receipt)
        guard let config = try OpenCodePrivateFiles.read(configURL),
              let object = try JSONSerialization.jsonObject(with: config) as? [String: Any],
              let entries = object["plugin"] as? [Any] else { return false }
        return entries.contains { ($0 as? String) == pluginURL.absoluteString }
    }

    func remove() throws {
        close(try OpenCodePrivateFiles.directory(configRoot, create: false))
        close(try OpenCodePrivateFiles.directory(bridgeRoot, create: false, privateOnly: true))
        let plugin = try OpenCodePrivateFiles.read(pluginURL)
        let receipt = try OpenCodePrivateFiles.read(receiptURL)
        guard receipt != nil else {
            if plugin != nil { throw OpenCodePluginSetupError.foreignFile }
            return
        }
        try checkOwnership(plugin: plugin, receipt: receipt)
        let oldConfig = try OpenCodePrivateFiles.read(configURL)
        let config = try registration(oldConfig, adding: false)
        // Deregister first. A failed removal leaves forwarding disabled and the owned file recoverable.
        if oldConfig != config { try write(config, configURL) }
        try OpenCodePrivateFiles.remove(pluginURL)
        try OpenCodePrivateFiles.remove(receiptURL)
    }

    private func checkOwnership(plugin: Data?, receipt: Data?) throws {
        if let receipt {
            guard let owned = try? JSONDecoder().decode(Receipt.self, from: receipt), owned.path == pluginURL.path,
                  plugin == nil || digest(plugin!) == owned.hash else { throw OpenCodePluginSetupError.foreignFile }
        } else if plugin != nil { throw OpenCodePluginSetupError.foreignFile }
    }

    private func registration(_ data: Data?, adding: Bool) throws -> Data {
        var object: [String: Any] = [:]
        if let data {
            guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw OpenCodePluginSetupError.unsupportedConfiguration
            }
            object = parsed
        }
        // OpenCode also permits tuple entries; preserve them without interpreting their options.
        var entries = object["plugin"] as? [Any] ?? []
        if object["plugin"] != nil, !(object["plugin"] is [Any]) {
            throw OpenCodePluginSetupError.unsupportedConfiguration
        }
        entries.removeAll { ($0 as? String) == pluginURL.absoluteString }
        if adding { entries.append(pluginURL.absoluteString) }
        object["plugin"] = entries
        return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
