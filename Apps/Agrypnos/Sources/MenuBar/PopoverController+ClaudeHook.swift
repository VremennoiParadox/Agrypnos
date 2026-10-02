import AppKit
#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension PopoverController {
    func addClaudeHookCard(_ card: CardView, ci: CGFloat, cw: CGFloat) {
        addPrefTitle("Claude Code forwarding", in: card, ci: ci, width: cw)
        _ = PopoverForm.help(QuestionSetupChrome.claudeHelp, in: card, y: 36, x: ci, width: cw, lines: 3)
        claudeEnableButton = setupClaudeButton(QuestionSetupChrome.claudeEnableTitle,
            action: #selector(enableClaudeHook), in: card, x: ci, y: 88)
        claudeDisableButton = setupClaudeButton("Disable", action: #selector(disableClaudeHook), in: card, x: ci, y: 116)
        claudeDisableButton.setAccessibilityLabel("Disable Claude Code forwarding")
        claudeEnableButton.setAccessibilityHelp(QuestionSetupChrome.claudeHelp)
        claudeHookStatus = PopoverForm.help("", in: card, y: 144, x: ci, width: cw, lines: 2)
    }
    private func setupClaudeButton(_ title: String, action: Selector, in card: CardView, x: CGFloat, y: CGFloat) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded; button.controlSize = .small; button.sizeToFit()
        button.frame.origin = NSPoint(x: x, y: y); card.addSubview(button); return button
    }
    @objc func enableClaudeHook() {
        stopRecordingIfNeeded(); commitNotifFields()
        Task { [weak self] in
            guard let self, let runtime else { return }
            _ = await runtime.enableClaudeQuestionHook(); refresh()
        }
    }
    @objc func disableClaudeHook() { runtime?.disableClaudeQuestionHook(); refresh() }
}
