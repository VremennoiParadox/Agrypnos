import AppKit
#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension PopoverController {
    func addOpenCodePluginCard(_ card: CardView, ci: CGFloat, cw: CGFloat) {
        addPrefTitle("OpenCode forwarding", in: card, ci: ci, width: cw - 24)
        addQuestionInfoButton(in: card, ci: ci, cw: cw, action: #selector(showOpenCodeQuestionSetup))
        _ = PopoverForm.help(QuestionSetupChrome.pluginHelp, in: card, y: 36, x: ci, width: cw, lines: 3)
        openCodeEnableButton = setupButton(QuestionSetupChrome.enableTitle, action: #selector(enableOpenCodePlugin), in: card, x: ci, y: 88)
        openCodeDisableButton = setupButton("Disable", action: #selector(disableOpenCodePlugin), in: card, x: ci, y: 116)
        openCodeDisableButton.setAccessibilityLabel("Disable OpenCode forwarding")
        openCodeRemoveButton = setupButton("Remove integration", action: #selector(removeOpenCodePlugin), in: card,
            x: ci + openCodeDisableButton.frame.width + 8, y: 116)
        openCodeRemoveButton.setAccessibilityLabel("Remove OpenCode integration")
        openCodeManualButton = setupButton("Manual server connection…", action: #selector(toggleManualOpenCode), in: card, x: ci, y: 144)
        openCodeEnableButton.setAccessibilityHelp(QuestionSetupChrome.pluginHelp)
    }
    private func setupButton(_ title: String, action: Selector, in card: CardView, x: CGFloat, y: CGFloat) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded; button.controlSize = .small; button.sizeToFit()
        button.frame.origin = NSPoint(x: x, y: y); card.addSubview(button); return button
    }
    @objc func enableOpenCodePlugin() {
        stopRecordingIfNeeded(); commitNotifFields()
        Task { [weak self] in
            guard let self, let runtime else { return }
            _ = await runtime.enableOpenCodeForwarding(); refresh()
        }
    }
    @objc func disableOpenCodePlugin() { runtime?.disableOpenCodeForwarding(); refresh() }
    @objc func removeOpenCodePlugin() {
        Task { [weak self] in
            guard let self, let runtime else { return }
            _ = await runtime.removeOpenCodeForwarding(); refresh()
        }
    }
    @objc func toggleManualOpenCode() {
        showManualOpenCodeConnection.toggle()
        openCodeManualButton.title = showManualOpenCodeConnection ? "Hide manual connection" : "Manual server connection…"
        applySection(currentSection)
    }
}
