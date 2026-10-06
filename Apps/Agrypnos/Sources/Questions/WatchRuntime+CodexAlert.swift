import Foundation
import Darwin
#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

@MainActor
final class CodexAlertBox {
    var hooksURLOverride: URL?
    var socketURLOverride: URL?
    var setupFailure: String?
    var source: CodexAlertHookSource?
    var posted: [String] = []
    var suppressNetwork = false
}

extension WatchRuntime {
    private static let codexBoxes = NSMapTable<AnyObject, CodexAlertBox>.weakToStrongObjects()

    var codexHooksURLOverride: URL? {
        get { codexBox.hooksURLOverride }
        set { codexBox.hooksURLOverride = newValue }
    }
    var codexSocketURLOverride: URL? {
        get { codexBox.socketURLOverride }
        set { codexBox.socketURLOverride = newValue }
    }
    var codexPostedSentences: [String] { codexBox.posted }
    var codexSuppressNetwork: Bool {
        get { codexBox.suppressNetwork }
        set { codexBox.suppressNetwork = newValue }
    }

    var codexHooksURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/hooks.json")
    }

    var codexAlertCaption: String {
        if let failure = codexBox.setupFailure { return failure }
        if preferences.codexAlertEnabled {
            return "Added the hook. In Codex, run /hooks and trust it. Until then, no alert is sent."
        }
        return QuestionSetupChrome.codexHelp
    }

    private var codexBox: CodexAlertBox {
        if let existing = Self.codexBoxes.object(forKey: self) { return existing }
        let box = CodexAlertBox()
        Self.codexBoxes.setObject(box, forKey: self)
        return box
    }

    private func codexHasDestination() -> Bool {
        let secrets = readNotifSecrets()
        return !NotifIdlePostPolicy.destinations(
            discordWebhookURL: secrets.discordWebhookURL,
            telegramBotToken: secrets.telegramBotToken,
            telegramChatId: secrets.telegramChatId
        ).isEmpty
    }

    private func codexSetupFailed(_ text: String) -> Bool {
        codexBox.setupFailure = text
        notify(text)
        delegate?.watchRuntimeDidChange(self)
        return false
    }

    private func writeCodexHooks(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temp = directory.appendingPathComponent(".\(url.lastPathComponent).tmp")
        if FileManager.default.fileExists(atPath: temp.path) {
            try FileManager.default.removeItem(at: temp)
        }
        try data.write(to: temp, options: .atomic)
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: temp)
            } else {
                try FileManager.default.moveItem(at: temp, to: url)
            }
        } catch {
            try? FileManager.default.removeItem(at: temp)
            throw error
        }
    }

    func enableCodexAlerts() -> Bool {
        guard codexHasDestination() else {
            return codexSetupFailed("Save a Telegram chat or Discord webhook first.")
        }
        do {
            let executable = Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
            let quoted = executable.contains(" ") ? "\"\(executable)\"" : executable
            let command = quoted + " " + CodexAlertHook.flag
            let url = codexHooksURLOverride ?? codexHooksURL
            let existing = (try? Data(contentsOf: url)) ?? Data()
            let merged = try CodexAlertHook.enable(hooksJSON: existing, command: command)
            try writeCodexHooks(merged, to: url)
            engine.preferences.codexAlertEnabled = true
            codexBox.setupFailure = nil
            store.save(engine.preferences)
            syncCodexAlerts()
            delegate?.watchRuntimeDidChange(self)
            return true
        } catch {
            return codexSetupFailed("Codex: couldn't merge ~/.codex/hooks.json. Existing hooks were left as they were.")
        }
    }

    func disableCodexAlerts() {
        let url = codexHooksURLOverride ?? codexHooksURL
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                let existing = try Data(contentsOf: url)
                let stripped = try CodexAlertHook.disable(hooksJSON: existing)
                try writeCodexHooks(stripped, to: url)
            }
            stopCodexAlerts()
            engine.preferences.codexAlertEnabled = false
            codexBox.setupFailure = nil
            store.save(engine.preferences)
            delegate?.watchRuntimeDidChange(self)
        } catch {
            _ = codexSetupFailed("Codex: couldn't update ~/.codex/hooks.json. Existing hooks were left as they were.")
        }
    }

    func stopCodexAlerts() {
        codexBox.source?.stop()
        codexBox.source = nil
    }

    func syncCodexAlerts() {
        let want = !questionSourcesSuspended && !questionSourcesTerminated
            && preferences.codexAlertEnabled
            && codexHasDestination()
        if !want {
            stopCodexAlerts()
            return
        }
        if codexBox.source != nil { return }
        let source = CodexAlertHookSource(
            socketURL: codexSocketURLOverride ?? CodexAlertHookProcess.defaultSocketURL(),
            receive: { [weak self] data in
                guard let self, let notice = CodexAlertHook.notice(data) else { return }
                self.codexBox.posted.append(notice)
                guard !self.codexBox.suppressNetwork else { return }
                Task { await self.postCodexAlert(notice) }
            })
        do { try source.start(); codexBox.source = source }
        catch { codexBox.setupFailure = "Codex: couldn't listen for the waiting alert." }
    }

    func postCodexAlert(_ sentence: String) async {
        let secrets = readNotifSecrets()
        let channels = NotifIdlePostPolicy.destinations(
            discordWebhookURL: secrets.discordWebhookURL,
            telegramBotToken: secrets.telegramBotToken,
            telegramChatId: secrets.telegramChatId
        )
        var requests: [NotifOutboundRequest] = []
        if channels.contains(.discord),
           let url = secrets.discordWebhookURL,
           let request = NotifOutboundRequestFactory.discord(webhookURL: url, content: sentence) {
            requests.append(request)
        }
        if channels.contains(.telegram),
           let token = secrets.telegramBotToken,
           let chat = secrets.telegramChatId,
           let request = NotifOutboundRequestFactory.telegram(botToken: token, chatId: chat, text: sentence) {
            requests.append(request)
        }
        await withTaskGroup(of: Void.self) { group in
            for request in requests {
                group.addTask { await NotifIdlePoster.fire(request) }
            }
        }
    }
}

@MainActor
final class CodexAlertHookSource {
    typealias Receive = @MainActor (Data) -> Void
    private let socketURL: URL
    private let receive: Receive
    private var listener: DispatchSourceRead?
    private var bound = false

    init(socketURL: URL, receive: @escaping Receive) {
        self.socketURL = socketURL
        self.receive = receive
    }

    func start() throws {
        close(try OpenCodePrivateFiles.directory(socketURL.deletingLastPathComponent(), privateOnly: true))
        var info = stat()
        if lstat(socketURL.path, &info) == 0 {
            guard (info.st_mode & S_IFMT) == S_IFSOCK, info.st_uid == getuid() else {
                throw CodexAlertHook.Error.unsupportedHooks
            }
            unlink(socketURL.path)
        }
        var address = sockaddr_un()
        let path = Array(socketURL.path.utf8) + [0]
        guard path.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            throw CodexAlertHook.Error.unsupportedHooks
        }
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: path) }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw CodexAlertHook.Error.unsupportedHooks }
        var ok = false
        defer { if !ok { close(fd); if bound { unlink(socketURL.path); bound = false } } }
        let bindOK = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindOK == 0 else { throw CodexAlertHook.Error.unsupportedHooks }
        bound = true
        guard chmod(socketURL.path, 0o600) == 0, listen(fd, 8) == 0 else {
            throw CodexAlertHook.Error.unsupportedHooks
        }
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        source.setEventHandler { [weak self] in self?.accept(fd) }
        source.setCancelHandler { close(fd) }
        listener = source
        source.resume()
        ok = true
    }

    private func accept(_ listenerFD: Int32) {
        let client = Darwin.accept(listenerFD, nil, nil)
        guard client >= 0 else { return }
        var uid = uid_t(), gid = gid_t()
        guard getpeereid(client, &uid, &gid) == 0, uid == getuid() else { close(client); return }
        Task { @MainActor in await self.serve(client) }
    }

    private func serve(_ fd: Int32) async {
        defer { close(fd) }
        var stdin = Data()
        var buffer = [UInt8](repeating: 0, count: 8192)
        while true {
            let n = Darwin.read(fd, &buffer, buffer.count)
            if n == 0 { break }
            guard n > 0 else { return }
            stdin.append(buffer, count: n)
            guard stdin.count <= 256 * 1024 else { return }
        }
        receive(stdin)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        if bound { unlink(socketURL.path); bound = false }
    }
}
