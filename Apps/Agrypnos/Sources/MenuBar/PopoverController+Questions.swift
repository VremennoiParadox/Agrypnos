import AppKit

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension PopoverController {
    func addQuestionNotificationsCard(_ card: CardView, ci: CGFloat, cw: CGFloat) {
        questionNotificationsButton = NSButton(
            title: QuestionSetupChrome.disclosureTitle,
            target: self,
            action: #selector(toggleQuestionNotifications)
        )
        questionNotificationsButton.bezelStyle = .rounded
        questionNotificationsButton.controlSize = .regular
        questionNotificationsButton.setAccessibilityLabel(QuestionSetupChrome.disclosureTitle)
        questionNotificationsButton.sizeToFit()
        let height = max(questionNotificationsButton.frame.height, 24)
        let width = min(max(questionNotificationsButton.frame.width + 8, 120), cw - 56)
        let y = (CGFloat(PopoverStackLayout.loginCardHeight) - height) / 2
        questionNotificationsButton.frame = NSRect(x: ci, y: y, width: width, height: height)
        card.addSubview(questionNotificationsButton)

        let beta = LabelFactory.make(
            QuestionSetupChrome.beta,
            font: .systemFont(ofSize: 11, weight: .semibold),
            color: .systemOrange
        )
        beta.sizeToFit()
        let betaY = y + (height - beta.frame.height) / 2
        beta.frame.origin = NSPoint(x: questionNotificationsButton.frame.maxX + 8, y: betaY)
        beta.setAccessibilityLabel(QuestionSetupChrome.beta)
        card.addSubview(beta)
        questionNotificationsBeta = beta
    }

    @objc func toggleQuestionNotifications() {
        stopRecordingIfNeeded()
        showQuestionNotifications.toggle()
        applySection(.notif)
        refresh()
    }

    func addQuestionInfoButton(in card: CardView, ci: CGFloat, cw: CGFloat, action: Selector) {
        let image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "Setup instructions")
        let button = NSButton(image: image ?? NSImage(), target: self, action: action)
        button.bezelStyle = .smallSquare
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.setAccessibilityLabel("Setup instructions")
        button.frame = NSRect(
            x: ci + cw - 20,
            y: CGFloat(PopoverStackLayout.prefTitleY),
            width: 20,
            height: 18
        )
        card.addSubview(button)
    }

    @objc func showOpenCodeQuestionSetup() { toolGuide.show(.openCode) }
    @objc func showClaudeQuestionSetup() { toolGuide.show(.claudeCode) }
    @objc func showCodexQuestionSetup() { toolGuide.show(.codex) }

    func addCodexAlertCard(_ card: CardView, ci: CGFloat, cw: CGFloat) {
        addPrefTitle("Codex alerts", in: card, ci: ci, width: cw - 24)
        addQuestionInfoButton(in: card, ci: ci, cw: cw, action: #selector(showCodexQuestionSetup))
        _ = PopoverForm.help(
            QuestionSetupChrome.codexHelp,
            in: card,
            y: CGFloat(QuestionSetupChrome.hookHelpY),
            x: ci,
            width: cw,
            lines: QuestionSetupChrome.codexHelpMaxLines
        )
        codexEnableButton = setupCodexButton(
            QuestionSetupChrome.codexEnableTitle,
            action: #selector(enableCodexAlerts),
            in: card,
            x: ci,
            y: CGFloat(QuestionSetupChrome.codexEnableY)
        )
        codexDisableButton = setupCodexButton(
            "Disable",
            action: #selector(disableCodexAlerts),
            in: card,
            x: ci,
            y: CGFloat(QuestionSetupChrome.codexDisableY)
        )
        codexDisableButton.setAccessibilityLabel("Disable Codex alerts")
        codexEnableButton.setAccessibilityHelp(QuestionSetupChrome.codexHelp)
        codexAlertStatus = PopoverForm.help(
            "",
            in: card,
            y: CGFloat(QuestionSetupChrome.codexStatusY),
            x: ci,
            width: cw,
            lines: 2
        )
    }

    private func setupCodexButton(_ title: String, action: Selector, in card: CardView, x: CGFloat, y: CGFloat) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.sizeToFit()
        button.frame.origin = NSPoint(x: x, y: y)
        card.addSubview(button)
        return button
    }

    @objc func enableCodexAlerts() {
        stopRecordingIfNeeded()
        commitNotifFields()
        _ = runtime?.enableCodexAlerts()
        refresh()
    }

    @objc func disableCodexAlerts() {
        runtime?.disableCodexAlerts()
        refresh()
    }

    func addCursorQuestionNoteCard(_ card: CardView, ci: CGFloat, cw: CGFloat) {
        let note = LabelFactory.wrapping(
            QuestionSetupChrome.cursorNote,
            font: .systemFont(ofSize: 12),
            color: .secondaryLabelColor,
            lines: QuestionSetupChrome.cursorNoteMaxLines
        )
        let inset = CGFloat(PopoverStackLayout.inset)
        note.preferredMaxLayoutWidth = cw
        note.frame = NSRect(
            x: ci,
            y: inset,
            width: cw,
            height: CGFloat(QuestionSetupChrome.cursorNoteCardHeight) - inset * 2
        )
        card.addSubview(note)
    }

    func addQuestionRelayCard(_ card: CardView, contentW: CGFloat, ci: CGFloat, cw: CGFloat,
                              swW: CGFloat, swH: CGFloat) {
        forwardQuestionsSwitch = PopoverForm.switchRow(in: card, y: ci,
            title: QuestionSetupChrome.title, contentW: contentW, ci: ci, cw: cw,
            swW: swW, swH: swH, target: self, action: #selector(forwardQuestionsToggled(_:)))
        forwardQuestionsSwitch.setAccessibilityLabel(QuestionSetupChrome.title)
        forwardQuestionsSwitch.setAccessibilityHelp(QuestionSetupChrome.help + " " + QuestionSetupChrome.policy)
        _ = PopoverForm.help(QuestionSetupChrome.help, in: card,
            y: CGFloat(QuestionSetupChrome.helpY), x: ci, width: cw, lines: QuestionSetupChrome.helpMaxLines)
        let policy = PopoverForm.help(QuestionSetupChrome.policy, in: card,
            y: CGFloat(QuestionSetupChrome.policyY), x: ci, width: cw, lines: QuestionSetupChrome.policyMaxLines)
        emphasize(["Discord", "Telegram"], in: policy)
        questionConnectionStatus = PopoverForm.help("", in: card,
            y: CGFloat(QuestionSetupChrome.statusY), x: ci, width: cw, lines: 4)
    }

    func refreshQuestionChrome(runtime: WatchRuntime) {
        let ready = runtime.questionBotReady
        forwardQuestionsSwitch?.isEnabled = ready
        forwardQuestionsSwitch?.state = ready && runtime.preferences.forwardAgentQuestions ? .on : .off
        questionConnectionStatus?.stringValue = runtime.openCodeQuestionCaption
        let active = runtime.preferences.openCodePluginEnabled && runtime.preferences.forwardAgentQuestions
        openCodeEnableButton?.isEnabled = !runtime.openCodeSetupInProgress && !active
        openCodeDisableButton?.isEnabled = !runtime.openCodeSetupInProgress && active
        openCodeRemoveButton?.isEnabled = !runtime.openCodeSetupInProgress && runtime.openCodeIntegrationCanBeRemoved
        claudeHookStatus?.stringValue = runtime.claudeQuestionCaption
        let claudeOn = runtime.preferences.claudeQuestionHookEnabled && runtime.preferences.forwardAgentQuestions
        claudeEnableButton?.isEnabled = !claudeOn
        claudeDisableButton?.isEnabled = runtime.preferences.claudeQuestionHookEnabled
        let codexOn = runtime.preferences.codexAlertEnabled
        codexEnableButton?.isEnabled = !codexOn
        codexDisableButton?.isEnabled = codexOn
        codexAlertStatus?.stringValue = runtime.codexAlertCaption
    }

    @objc func forwardQuestionsToggled(_ sender: NSSwitch) {
        stopRecordingIfNeeded()
        commitNotifFields()
        guard runtime?.questionBotReady == true else {
            sender.state = .off
            UserNotify.post(QuestionSetupChrome.needsBot)
            return
        }
        runtime?.setForwardAgentQuestions(sender.state == .on)
        refresh()
    }

    private func emphasize(_ words: [String], in field: NSTextField) {
        let text = field.stringValue
        let size = field.font?.pointSize ?? 12
        let wrap = NSMutableParagraphStyle()
        wrap.lineBreakMode = .byWordWrapping
        let marked = NSMutableAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: size),
            .foregroundColor: field.textColor ?? .secondaryLabelColor,
            .paragraphStyle: wrap
        ])
        let strong: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        for word in words {
            var start = text.startIndex
            while let found = text.range(of: word, range: start..<text.endIndex) {
                marked.addAttributes(strong, range: NSRange(found, in: text))
                start = found.upperBound
            }
        }
        field.attributedStringValue = marked
    }
}
