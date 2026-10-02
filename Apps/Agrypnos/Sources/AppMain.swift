import AppKit

final class AppHolder {
    static let shared = AppHolder()
    var delegate: AppDelegate?
}

@main
enum AgrypnosApp {
    @MainActor
    static func main() {
        if ClaudeQuestionHookProcess.runIfRequested() { return }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        AppHolder.shared.delegate = delegate
        app.delegate = delegate
        app.run()
    }
}
