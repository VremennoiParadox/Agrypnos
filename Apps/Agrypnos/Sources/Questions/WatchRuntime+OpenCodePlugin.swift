import Foundation
import Security
import Darwin
#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension WatchRuntime {
    var openCodeIntegrationCanBeRemoved: Bool {
        preferences.openCodePluginEnabled || (try? makeOpenCodeInstaller().hasInstallationArtifacts()) == true
    }
    func makeOpenCodeInstaller() throws -> OpenCodePluginInstaller {
        if let openCodePluginInstaller { return try openCodePluginInstaller() }
        guard let resource = Bundle.main.url(forResource: "agrypnos-opencode", withExtension: "js") else {
            throw OpenCodePluginSetupError.writeFailed
        }
        return OpenCodePluginInstaller(configRoot: OpenCodePluginInstaller.defaultConfigRoot,
            bridgeRoot: OpenCodePluginInstaller.defaultBridgeRoot, pluginData: try Data(contentsOf: resource))
    }
    private var openCodeSetupPrerequisite: String? {
        if questionSourcesTerminated || questionSourcesSuspended { return "OpenCode: forwarding is paused." }
        if !preferences.includedAgentKinds.contains(.openCode) { return "OpenCode: select it in Agents first." }
        let relay = questionRelaySettings()
        if relay.telegram?.isComplete != true && relay.discord?.isComplete != true {
            return "OpenCode: enable bot inbound and save its answering user ID."
        }
        return nil
    }
    private func setupFailed(_ text: String) -> Bool {
        openCodeSetupFailure = text; notify(text); delegate?.watchRuntimeDidChange(self); return false
    }
    func enableOpenCodeForwarding() async -> Bool {
        guard !openCodeSetupInProgress else { return false }
        if let reason = openCodeSetupPrerequisite { return setupFailed(reason) }
        if preferences.openCodePluginEnabled && preferences.forwardAgentQuestions && openCodePluginSource != nil { return true }
        openCodeSetupInProgress = true; openCodeSetupFailure = nil
        delegate?.watchRuntimeDidChange(self)
        defer { openCodeSetupInProgress = false; syncQuestionSources(); delegate?.watchRuntimeDidChange(self) }
        let revision = openCodeSetupRevision
        var installer: OpenCodePluginInstaller?
        var newlyInstalled = false
        do {
            let owned = try makeOpenCodeInstaller(); installer = owned
            newlyInstalled = (try? owned.isInstalled()) != true
            _ = try await Task.detached { try owned.install() }.value
            guard openCodeSetupRevision == revision else { throw SetupFailure(reason: "OpenCode: setup canceled because forwarding settings changed.") }
            if let reason = openCodeSetupPrerequisite { throw SetupFailure(reason: reason) }
            // Source/manifest must succeed before the saved preference claims forwarding is enabled.
            stopQuestionSources(); questionRelay.invalidateAll()
            try startOpenCodePlugin(installer: owned, relay: questionRelaySettings())
            engine.preferences.openCodePluginEnabled = true
            engine.preferences.forwardAgentQuestions = true
            openCodeRelaySettings = questionRelaySettings()
            store.save(engine.preferences); questionRelay.refreshSettings()
            return true
        } catch {
            stopQuestionSources()
            if newlyInstalled, let installer { try? installer.remove() }
            let reason: String
            if let canceled = error as? SetupFailure { reason = canceled.reason }
            else {
                switch error as? OpenCodePluginSetupError {
                case .unsafePath: reason = "OpenCode: setup refused an unsafe path, symlink, or file owner."
                case .foreignFile: reason = "OpenCode: an existing Agrypnos plugin or receipt was edited. Keep it or restore it before setup."
                case .configurationChanged: reason = "OpenCode: configuration changed during setup. Your save was kept; try Enable again."
                case .unsupportedConfiguration: reason = "OpenCode: tui.json must contain a JSON object with a plugin array. Your file was kept."
                default: reason = "OpenCode: couldn't write setup files or start the local connection. Check config permissions."
                }
            }
            return setupFailed(reason)
        }
    }
    private struct SetupFailure: Error { let reason: String }
    func disableOpenCodeForwarding() {
        openCodeSetupFailure = nil
        setForwardAgentQuestions(false)
        stopQuestionSources()
    }
    func removeOpenCodeForwarding() async -> Bool {
        guard !openCodeSetupInProgress else { return false }
        disableOpenCodeForwarding()
        openCodeSetupInProgress = true
        defer { openCodeSetupInProgress = false; syncQuestionSources(); delegate?.watchRuntimeDidChange(self) }
        do {
            let installer = try makeOpenCodeInstaller()
            try await Task.detached { try installer.remove() }.value
            engine.preferences.openCodePluginEnabled = false; store.save(engine.preferences)
            return true
        } catch { return setupFailed("OpenCode: couldn't remove the integration. Forwarding is off; edited or foreign files were kept.") }
    }
    func syncOpenCodePlugin(relay: QuestionRelaySettings) {
        if openCodePluginSource != nil, openCodeRelaySettings == relay { return }
        stopQuestionSources(); questionRelay.refreshSettings()
        do {
            let installer = try makeOpenCodeInstaller()
            guard try installer.isInstalled() else { throw OpenCodePluginSetupError.foreignFile }
            try startOpenCodePlugin(installer: installer, relay: relay)
            openCodeSetupFailure = nil
        } catch {
            openCodeSetupFailure = "OpenCode: integration unavailable. Enable again to repair setup, or use the manual connection."
        }
    }
    private func startOpenCodePlugin(installer: OpenCodePluginInstaller, relay: QuestionRelaySettings) throws {
        close(try OpenCodePrivateFiles.directory(installer.bridgeRoot, privateOnly: true))
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw OpenCodePluginSetupError.writeFailed }
        let token = bytes.map { String(format: "%02x", $0) }.joined(), generation = UUID()
        let socketRoot = URL(fileURLWithPath: "/private/tmp/agrypnos-bridge-" + generation.uuidString)
        let config = OpenCodeBridgeConfiguration(socketURL: socketRoot.appendingPathComponent("s.sock"),
            token: token, generation: generation)
        let source = OpenCodePluginQuestionSource(configuration: config, uptime: { [weak self] in self?.questionUptime() ?? 0 },
            receive: { [weak self] batch, submit, local in
                self?.questionRelay.receive(batch, submit: submit, returnLocal: local) ?? false
            }, resolved: { [weak self] key in
                self?.questionRelay.cancel(key: key); self?.questionRelayDidChange(.cleared(key))
            })
        source.stateChanged = { [weak self] _ in if let self { self.delegate?.watchRuntimeDidChange(self) } }
        do { try source.start() }
        catch { _ = rmdir(socketRoot.path); throw error }
        do {
            let manifest: [String: Any] = ["active": true, "protocolVersion": 1, "socketPath": config.socketURL.path,
                "token": token, "generation": generation.uuidString]
            try OpenCodePrivateFiles.write(JSONSerialization.data(withJSONObject: manifest), to: installer.bridgeRoot.appendingPathComponent("bridge.json"))
        } catch { source.stop(); _ = rmdir(socketRoot.path); throw error }
        openCodePluginSocketRoot = socketRoot
        openCodePluginBridgeRoot = installer.bridgeRoot; openCodePluginSource = source; openCodeRelaySettings = relay
    }
    func stopOpenCodePlugin() {
        let source = openCodePluginSource
        openCodePluginSource = nil
        // Revoke the listener synchronously, even if publishing inactive metadata fails.
        source?.stop()
        if let root = openCodePluginSocketRoot { _ = rmdir(root.path); openCodePluginSocketRoot = nil }
        if let root = openCodePluginBridgeRoot {
            try? OpenCodePrivateFiles.write(Data(#"{"active":false,"protocolVersion":1}"#.utf8), to: root.appendingPathComponent("bridge.json"))
            openCodePluginBridgeRoot = nil
        }
    }
}
