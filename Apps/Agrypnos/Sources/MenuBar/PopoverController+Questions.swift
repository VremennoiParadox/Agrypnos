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
        if showQuestionNotifications {
            commitQuestionUserFields()
        }
        showQuestionNotifications.toggle()
        applySection(.notif)
        if showQuestionNotifications {
            loadQuestionFields()
        }
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
            y: CGFloat(QuestionSetupChrome.helpY), x: ci, width: cw, lines: 4)
        telegramQuestionUser = PopoverForm.labeledSecretField(in: card,
            y: CGFloat(QuestionSetupChrome.telegramUserY), x: ci, width: cw, caption: "Telegram",
            placeholder: "Your user ID", label: "Telegram answering user ID",
            help: "Only this Telegram user may answer forwarded questions. Find message.from.id in getUpdates.",
            target: self, action: #selector(questionUserCommitted(_:)), delegate: self)
        discordQuestionUser = PopoverForm.labeledSecretField(in: card,
            y: CGFloat(QuestionSetupChrome.discordUserY), x: ci, width: cw, caption: "Discord",
            placeholder: "Your user ID", label: "Discord answering user ID",
            help: "Only this Discord user may answer forwarded questions. Enable Developer Mode, then Copy User ID.",
            target: self, action: #selector(questionUserCommitted(_:)), delegate: self)
        _ = PopoverForm.help(QuestionSetupChrome.policy, in: card,
            y: CGFloat(QuestionSetupChrome.policyY), x: ci, width: cw, lines: 5)
        questionConnectionStatus = PopoverForm.help("", in: card,
            y: CGFloat(QuestionSetupChrome.statusY), x: ci, width: cw, lines: 4)
    }

    func loadQuestionFields() {
        guard let runtime else { return }
        let secrets = runtime.notifSecrets()
        telegramQuestionUser?.stringValue = secrets.telegramQuestionUserId ?? ""
        discordQuestionUser?.stringValue = secrets.discordQuestionUserId ?? ""
    }

    func refreshQuestionChrome(runtime: WatchRuntime) {
        forwardQuestionsSwitch?.state = runtime.preferences.forwardAgentQuestions ? .on : .off
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

    func commitQuestionUserFields() {
        for row in [telegramQuestionUser, discordQuestionUser] {
            if let row { questionUserCommitted(row.field) }
        }
    }

    @objc func questionUserCommitted(_ sender: NSTextField) {
        flushSecretFieldEditor(sender)
        let value = NotifSecretsPayload.present(sender.stringValue)
        let telegram = telegramQuestionUser?.contains(sender) == true
        if let value {
            let valid = value.utf8.allSatisfy { (48...57).contains($0) }
                && (telegram ? (Int64(value) ?? 0) > 0 : (UInt64(value) ?? 0) > 0)
            guard valid else { UserNotify.post("Enter a numeric answering user ID."); return }
        }
        let saved = telegram ? runtime?.setNotifTelegramQuestionUserId(value)
            : runtime?.setNotifDiscordQuestionUserId(value)
        if saved == false { UserNotify.post(AgrypnosCopy.notifSaveFailed) }
        refresh()
    }

    @objc func forwardQuestionsToggled(_ sender: NSSwitch) {
        stopRecordingIfNeeded()
        let on = sender.state == .on
        commitNotifFields()
        runtime?.setForwardAgentQuestions(on)
        refresh()
    }
}
