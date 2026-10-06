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

    func addCodexAlertCard(_ card: CardView, ci: CGFloat, cw: CGFloat) {
        addPrefTitle("Codex alerts", in: card, ci: ci, width: cw)
        _ = PopoverForm.help(QuestionSetupChrome.codexHelp, in: card, y: 36, x: ci, width: cw, lines: 4)
    }

    func addCursorQuestionNoteCard(_ card: CardView, ci: CGFloat, cw: CGFloat) {
        let note = LabelFactory.wrapping(
            QuestionSetupChrome.cursorNote,
            font: .systemFont(ofSize: 12),
            color: .secondaryLabelColor,
            lines: 2
        )
        let height = max(note.intrinsicContentSize.height, 22)
        let y = (CGFloat(PopoverStackLayout.loginCardHeight) - height) / 2
        note.frame = NSRect(x: ci, y: y, width: cw, height: height)
        note.preferredMaxLayoutWidth = cw
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

    func addOpenCodeQuestionsCard(_ card: CardView, ci: CGFloat, cw: CGFloat) {
        addPrefTitle(QuestionSetupChrome.connectionTitle, in: card, ci: ci, width: cw)
        _ = PopoverForm.help(QuestionSetupChrome.connectionHelp, in: card, y: 36, x: ci, width: cw, lines: 3)
        openCodeEndpoint = addConnectionField("Server", y: QuestionSetupChrome.endpointY,
            placeholder: "http://127.0.0.1:4096", in: card, ci: ci, cw: cw)
        openCodeDirectory = addConnectionField("Directory", y: QuestionSetupChrome.directoryY,
            placeholder: "/absolute/project/path", in: card, ci: ci, cw: cw)
        openCodeUsername = addConnectionField("User", y: QuestionSetupChrome.usernameY,
            placeholder: "opencode", in: card, ci: ci, cw: cw)
        openCodePassword = PopoverForm.labeledSecretField(in: card,
            y: CGFloat(QuestionSetupChrome.passwordY), x: ci, width: cw, caption: "Password",
            placeholder: "Optional", label: "OpenCode server password",
            help: "The server's OPENCODE_SERVER_PASSWORD. It stays on this Mac.",
            target: self, action: #selector(connectionFieldEnded(_:)), delegate: self)
        let save = NSButton(title: "Save connection", target: self, action: #selector(saveOpenCodeConnection))
        let remove = NSButton(title: "Remove", target: self, action: #selector(removeOpenCodeConnection))
        for button in [save, remove] {
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.sizeToFit()
            card.addSubview(button)
        }
        save.frame.origin = NSPoint(x: ci, y: CGFloat(QuestionSetupChrome.connectionButtonsY))
        remove.frame.origin = NSPoint(x: ci + save.frame.width + 8, y: save.frame.minY)
        _ = PopoverForm.help("New questions only. Existing pending questions stay on Mac after app restart or sleep.",
            in: card, y: 240, x: ci, width: cw, lines: 3)
    }

    private func addConnectionField(_ caption: String, y: Int, placeholder: String,
                                    in card: CardView, ci: CGFloat, cw: CGFloat) -> NSTextField {
        let label = LabelFactory.make(caption, font: .systemFont(ofSize: 13), color: .labelColor)
        let labelW = CGFloat(PopoverCopyLayout.secretFieldLabelWidthPoints)
        label.frame = NSRect(x: ci, y: CGFloat(y), width: labelW, height: 22)
        card.addSubview(label)
        let field = PopoverTextField(string: "")
        field.font = .systemFont(ofSize: 13)
        field.bezelStyle = .roundedBezel
        field.placeholderString = placeholder
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.delegate = self
        field.frame = NSRect(x: ci + labelW + 8, y: CGFloat(y), width: cw - labelW - 8, height: 24)
        field.setAccessibilityLabel("OpenCode " + caption)
        field.setAccessibilityHelp(placeholder)
        card.addSubview(field)
        return field
    }

    func loadQuestionFields() {
        guard let runtime else { return }
        let secrets = runtime.notifSecrets()
        telegramQuestionUser?.stringValue = secrets.telegramQuestionUserId ?? ""
        discordQuestionUser?.stringValue = secrets.discordQuestionUserId ?? ""
        openCodeEndpoint?.stringValue = secrets.openCodeQuestions?.endpoint ?? ""
        openCodeDirectory?.stringValue = secrets.openCodeQuestions?.directory ?? ""
        openCodeUsername?.stringValue = secrets.openCodeQuestions?.username ?? "opencode"
        openCodePassword?.stringValue = secrets.openCodeQuestions?.password ?? ""
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

    @objc func connectionFieldEnded(_ sender: NSTextField) { flushSecretFieldEditor(sender) }

    @objc func forwardQuestionsToggled(_ sender: NSSwitch) {
        stopRecordingIfNeeded()
        let on = sender.state == .on
        commitNotifFields()
        runtime?.setForwardAgentQuestions(on)
        refresh()
    }

    @objc func saveOpenCodeConnection() {
        stopRecordingIfNeeded()
        for field in [openCodeEndpoint, openCodeDirectory, openCodeUsername, openCodePassword?.field] {
            flushSecretFieldEditor(field)
        }
        let settings = OpenCodeQuestionSettings(endpoint: openCodeEndpoint.stringValue,
            directory: openCodeDirectory.stringValue, username: openCodeUsername.stringValue,
            password: openCodePassword.stringValue)
        guard (try? OpenCodeQuestionConfiguration(settings)) != nil else {
            UserNotify.post("Use http://127.0.0.1:PORT, an absolute project directory, and a valid server username.")
            return
        }
        if runtime?.setOpenCodeQuestionSettings(settings) == false { UserNotify.post(AgrypnosCopy.notifSaveFailed) }
        refresh()
    }

    @objc func removeOpenCodeConnection() {
        popover.contentViewController?.view.window?.makeFirstResponder(nil)
        if runtime?.setOpenCodeQuestionSettings(nil) == false { UserNotify.post(AgrypnosCopy.notifSaveFailed); return }
        loadQuestionFields()
        refresh()
    }
}
