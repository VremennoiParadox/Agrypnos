import AppKit

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension PopoverController {
    func addNotifEnableCard(
        _ card: CardView,
        contentW: CGFloat,
        ci: CGFloat,
        cw: CGFloat,
        swW: CGFloat,
        swH: CGFloat
    ) {
        addPrefTitle(AgrypnosCopy.notifEnabled, in: card, ci: ci, width: cw)
        _ = PopoverForm.help(
            AgrypnosCopy.notifEnabledHelp,
            in: card,
            y: CGFloat(PopoverStackLayout.notifEnableHelpY),
            x: ci,
            width: cw,
            lines: PopoverCopyLayout.notifEnableHelpMaxLines
        )
        notifSwitch = PopoverForm.switchControl(
            in: card,
            y: CGFloat(PopoverStackLayout.notifEnableSwitchY),
            contentW: contentW,
            ci: ci,
            swW: swW,
            swH: swH,
            target: self,
            action: #selector(notifToggled(_:))
        )
        notifSwitch.state = NotifEnableChrome.defaultEnabled ? .on : .off
        notifSwitch.setAccessibilityLabel(AgrypnosCopy.notifEnabled)
        notifSwitch.setAccessibilityHelp(AgrypnosCopy.notifEnabledHelp)
    }

    func addNotifDiscordCard(
        _ card: CardView,
        contentW: CGFloat,
        ci: CGFloat,
        cw: CGFloat,
        swW: CGFloat,
        swH: CGFloat
    ) {
        addPrefTitle(AgrypnosCopy.notifDiscord, in: card, ci: ci, width: cw)
        _ = PopoverForm.help(
            AgrypnosCopy.notifDiscordHelp,
            in: card,
            y: CGFloat(PopoverStackLayout.prefHelpY),
            x: ci,
            width: cw,
            lines: PopoverCopyLayout.notifDiscordHelpMaxLines
        )
        discordInboundTokenSecrets = PopoverForm.labeledSecretField(
            in: card,
            y: CGFloat(PopoverStackLayout.notifDiscordInboundTokenY),
            x: ci,
            width: cw,
            caption: AgrypnosCopy.notifDiscordInboundTokenShort,
            placeholder: AgrypnosCopy.notifDiscordInboundTokenPlaceholder,
            label: AgrypnosCopy.notifDiscordInboundToken,
            help: AgrypnosCopy.notifDiscordHelp,
            target: self,
            action: #selector(discordInboundTokenCommitted(_:)),
            delegate: self
        )
        discordInboundChannelSecrets = PopoverForm.labeledSecretField(
            in: card,
            y: CGFloat(PopoverStackLayout.notifDiscordInboundChannelY),
            x: ci,
            width: cw,
            caption: AgrypnosCopy.notifDiscordInboundChannelShort,
            placeholder: AgrypnosCopy.notifDiscordInboundChannelPlaceholder,
            label: AgrypnosCopy.notifDiscordInboundChannelId,
            help: AgrypnosCopy.notifDiscordHelp,
            target: self,
            action: #selector(discordInboundChannelCommitted(_:)),
            delegate: self
        )
        discordUserSecrets = PopoverForm.labeledSecretField(
            in: card,
            y: CGFloat(PopoverStackLayout.notifDiscordUserY),
            x: ci,
            width: cw,
            caption: AgrypnosCopy.notifDiscordUserId,
            placeholder: AgrypnosCopy.notifDiscordUserPlaceholder,
            label: AgrypnosCopy.notifDiscordUserId,
            help: AgrypnosCopy.notifDiscordHelp,
            target: self,
            action: #selector(discordUserCommitted(_:)),
            delegate: self
        )
        discordInboundSwitch = PopoverForm.switchRow(
            in: card,
            y: CGFloat(PopoverStackLayout.notifDiscordInboundSwitchY),
            title: AgrypnosCopy.notifDiscordInbound,
            contentW: contentW,
            ci: ci,
            cw: cw,
            swW: swW,
            swH: swH,
            target: self,
            action: #selector(discordInboundToggled(_:))
        )
        discordInboundSwitch.state = DiscordInboundChrome.defaultEnabled ? .on : .off
        discordInboundSwitch.setAccessibilityLabel(AgrypnosCopy.notifDiscordInbound)
        discordInboundSwitch.setAccessibilityHelp(AgrypnosCopy.notifDiscordHelp)
    }

    func addNotifTelegramCard(
        _ card: CardView,
        contentW: CGFloat,
        ci: CGFloat,
        cw: CGFloat,
        swW: CGFloat,
        swH: CGFloat
    ) {
        addPrefTitle(AgrypnosCopy.notifTelegram, in: card, ci: ci, width: cw)
        _ = PopoverForm.help(
            AgrypnosCopy.notifTelegramHelp,
            in: card,
            y: CGFloat(PopoverStackLayout.prefHelpY),
            x: ci,
            width: cw,
            lines: PopoverCopyLayout.notifTelegramHelpMaxLines
        )
        telegramTokenSecrets = PopoverForm.labeledSecretField(
            in: card,
            y: CGFloat(PopoverStackLayout.notifTelegramTokenY),
            x: ci,
            width: cw,
            caption: AgrypnosCopy.notifTelegramTokenShort,
            placeholder: AgrypnosCopy.notifTelegramTokenPlaceholder,
            label: AgrypnosCopy.notifTelegramToken,
            help: AgrypnosCopy.notifTelegramHelp,
            target: self,
            action: #selector(telegramTokenCommitted(_:)),
            delegate: self
        )
        telegramChatSecrets = PopoverForm.labeledSecretField(
            in: card,
            y: CGFloat(PopoverStackLayout.notifTelegramChatY),
            x: ci,
            width: cw,
            caption: AgrypnosCopy.notifTelegramChatShort,
            placeholder: AgrypnosCopy.notifTelegramChatPlaceholder,
            label: AgrypnosCopy.notifTelegramChatId,
            help: AgrypnosCopy.notifTelegramHelp,
            target: self,
            action: #selector(telegramChatCommitted(_:)),
            delegate: self
        )
        telegramUserSecrets = PopoverForm.labeledSecretField(
            in: card,
            y: CGFloat(PopoverStackLayout.notifTelegramUserY),
            x: ci,
            width: cw,
            caption: AgrypnosCopy.notifTelegramUserId,
            placeholder: AgrypnosCopy.notifTelegramUserPlaceholder,
            label: AgrypnosCopy.notifTelegramUserId,
            help: AgrypnosCopy.notifTelegramHelp,
            target: self,
            action: #selector(telegramUserCommitted(_:)),
            delegate: self
        )
        telegramInboundSwitch = PopoverForm.switchRow(
            in: card,
            y: CGFloat(PopoverStackLayout.notifTelegramInboundSwitchY),
            title: AgrypnosCopy.notifTelegramInbound,
            contentW: contentW,
            ci: ci,
            cw: cw,
            swW: swW,
            swH: swH,
            target: self,
            action: #selector(telegramInboundToggled(_:))
        )
        telegramInboundSwitch.state = TelegramInboundChrome.defaultEnabled ? .on : .off
        telegramInboundSwitch.setAccessibilityLabel(AgrypnosCopy.notifTelegramInbound)
        telegramInboundSwitch.setAccessibilityHelp(AgrypnosCopy.notifTelegramHelp)
    }

    func addNotifSetupCard(_ card: CardView, ci: CGFloat, cw: CGFloat) {
        _ = addCardButton(AgrypnosCopy.notifSetup, in: card, ci: ci, cw: cw, action: #selector(setupInstructionsTapped))
    }

    func addNotifClearCard(_ card: CardView, ci: CGFloat, cw: CGFloat) {
        notifClearButton = addCardButton(
            AgrypnosCopy.notifClear, in: card, ci: ci, cw: cw, action: #selector(clearNotifSecretsTapped)
        )
    }

    private func addCardButton(_ title: String, in card: CardView, ci: CGFloat, cw: CGFloat, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.setAccessibilityLabel(title)
        button.sizeToFit()
        let width = min(max(button.frame.width + 8, 120), cw)
        let height = max(button.frame.height, 24)
        let y = (CGFloat(PopoverStackLayout.loginCardHeight) - height) / 2
        button.frame = NSRect(x: ci, y: y, width: width, height: height)
        card.addSubview(button)
        return button
    }

    @objc func setupInstructionsTapped() {
        close()
        botGuide.show()
    }

    func refreshNotifChrome(runtime: WatchRuntime) {
        notifSwitch?.state = runtime.preferences.notifEnabled ? .on : .off
        telegramInboundSwitch?.state = runtime.preferences.telegramInboundEnabled ? .on : .off
        discordInboundSwitch?.state = runtime.preferences.discordInboundEnabled ? .on : .off
        refreshQuestionChrome(runtime: runtime)
    }

    func loadNotifSecretFields() {
        guard let runtime else { return }
        let secrets = runtime.notifSecrets()
        discordInboundTokenSecrets?.stringValue = secrets.discordBotToken ?? ""
        discordInboundChannelSecrets?.stringValue = secrets.discordChannelId ?? ""
        discordUserSecrets?.stringValue = secrets.discordQuestionUserId ?? ""
        telegramTokenSecrets?.stringValue = secrets.telegramBotToken ?? ""
        telegramChatSecrets?.stringValue = secrets.telegramChatId ?? ""
        telegramUserSecrets?.stringValue = secrets.telegramQuestionUserId ?? ""
    }

    func commitNotifFields() {
        flushSecretFieldEditor(discordInboundTokenSecrets?.field)
        flushSecretFieldEditor(discordInboundChannelSecrets?.field)
        flushSecretFieldEditor(discordUserSecrets?.field)
        flushSecretFieldEditor(telegramTokenSecrets?.field)
        flushSecretFieldEditor(telegramChatSecrets?.field)
        flushSecretFieldEditor(telegramUserSecrets?.field)
        if let discordInboundTokenSecrets { discordInboundTokenCommitted(discordInboundTokenSecrets.field) }
        if let discordInboundChannelSecrets { discordInboundChannelCommitted(discordInboundChannelSecrets.field) }
        if let discordUserSecrets { discordUserCommitted(discordUserSecrets.field) }
        if let telegramTokenSecrets { telegramTokenCommitted(telegramTokenSecrets.field) }
        if let telegramChatSecrets { telegramChatCommitted(telegramChatSecrets.field) }
        if let telegramUserSecrets { telegramUserCommitted(telegramUserSecrets.field) }
    }

    func flushSecretFieldEditor(_ field: NSTextField?) {
        guard let field, let editor = field.currentEditor() as? NSText else { return }
        field.stringValue = editor.string
    }

    @objc func notifToggled(_ sender: NSSwitch) {
        stopRecordingIfNeeded()
        runtime?.setNotifEnabled(sender.state == .on)
        refresh()
    }

    @objc func telegramInboundToggled(_ sender: NSSwitch) {
        stopRecordingIfNeeded()
        runtime?.setTelegramInboundEnabled(sender.state == .on)
        refresh()
    }

    @objc func discordInboundToggled(_ sender: NSSwitch) {
        stopRecordingIfNeeded()
        runtime?.setDiscordInboundEnabled(sender.state == .on)
        refresh()
    }

    @objc func discordInboundTokenCommitted(_ sender: NSTextField) {
        stopRecordingIfNeeded()
        flushSecretFieldEditor(sender)
        switch DiscordBotTokenChrome.commit(sender.stringValue) {
        case .persist(let token):
            let saved = runtime?.setNotifDiscordBotToken(token) ?? true
            discordInboundTokenSecrets.stringValue = token
            if !saved {
                UserNotify.post(AgrypnosCopy.notifSaveFailed)
            }
        case .clear:
            break
        case .reject:
            UserNotify.post(AgrypnosCopy.notifDiscordInboundTokenInvalid)
        }
    }

    @objc func discordInboundChannelCommitted(_ sender: NSTextField) {
        stopRecordingIfNeeded()
        flushSecretFieldEditor(sender)
        switch DiscordChannelIdChrome.commit(sender.stringValue) {
        case .persist(let id):
            let saved = runtime?.setNotifDiscordChannelId(id) ?? true
            discordInboundChannelSecrets.stringValue = id
            if !saved {
                UserNotify.post(AgrypnosCopy.notifSaveFailed)
            }
        case .clear:
            break
        case .reject:
            UserNotify.post(AgrypnosCopy.notifDiscordInboundChannelInvalid)
        }
    }

    @objc func telegramTokenCommitted(_ sender: NSTextField) {
        stopRecordingIfNeeded()
        flushSecretFieldEditor(sender)
        switch TelegramBotTokenChrome.commit(sender.stringValue) {
        case .persist(let token):
            let saved = runtime?.setNotifTelegramBotToken(token) ?? true
            telegramTokenSecrets.stringValue = token
            if !saved {
                UserNotify.post(AgrypnosCopy.notifSaveFailed)
            }
        case .clear:
            break // empty: keep the stored secret
        case .reject:
            UserNotify.post(AgrypnosCopy.notifTelegramTokenInvalid)
        }
    }

    @objc func discordUserCommitted(_ sender: NSTextField) {
        stopRecordingIfNeeded()
        flushSecretFieldEditor(sender)
        switch DiscordChannelIdChrome.commit(sender.stringValue) {
        case .persist(let id):
            let saved = runtime?.setNotifDiscordQuestionUserId(id) ?? true
            discordUserSecrets.stringValue = id
            if !saved {
                UserNotify.post(AgrypnosCopy.notifSaveFailed)
            }
        case .clear:
            break
        case .reject:
            UserNotify.post(AgrypnosCopy.notifDiscordUserInvalid)
        }
    }

    @objc func telegramUserCommitted(_ sender: NSTextField) {
        stopRecordingIfNeeded()
        flushSecretFieldEditor(sender)
        switch DiscordChannelIdChrome.commit(sender.stringValue) {
        case .persist(let id):
            let saved = runtime?.setNotifTelegramQuestionUserId(id) ?? true
            telegramUserSecrets.stringValue = id
            if !saved {
                UserNotify.post(AgrypnosCopy.notifSaveFailed)
            }
        case .clear:
            break
        case .reject:
            UserNotify.post(AgrypnosCopy.notifTelegramUserInvalid)
        }
    }

    @objc func telegramChatCommitted(_ sender: NSTextField) {
        stopRecordingIfNeeded()
        flushSecretFieldEditor(sender)
        switch TelegramChatIdChrome.commit(sender.stringValue) {
        case .persist(let id):
            let saved = runtime?.setNotifTelegramChatId(id) ?? true
            telegramChatSecrets.stringValue = id
            if !saved {
                UserNotify.post(AgrypnosCopy.notifSaveFailed)
            }
        case .clear:
            break // empty: keep the stored secret
        case .reject:
            UserNotify.post(AgrypnosCopy.notifTelegramChatInvalid)
        }
    }

    @objc func clearNotifSecretsTapped() {
        stopRecordingIfNeeded()
        popover.contentViewController?.view.window?.makeFirstResponder(nil)
        runtime?.clearNotifSecrets()
        discordInboundTokenSecrets?.stringValue = ""
        discordInboundChannelSecrets?.stringValue = ""
        discordUserSecrets?.stringValue = ""
        telegramTokenSecrets?.stringValue = ""
        telegramChatSecrets?.stringValue = ""
        telegramUserSecrets?.stringValue = ""
        refresh()
    }
}
