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

    func addNotifDiscordCard(_ card: CardView, ci: CGFloat, cw: CGFloat) {
        addPrefTitle(AgrypnosCopy.notifDiscord, in: card, ci: ci, width: cw)
        _ = PopoverForm.help(
            AgrypnosCopy.notifDiscordHelp,
            in: card,
            y: CGFloat(PopoverStackLayout.prefHelpY),
            x: ci,
            width: cw
        )
        discordSecrets = PopoverForm.secretField(
            in: card,
            y: CGFloat(PopoverStackLayout.notifDiscordFieldY),
            x: ci,
            width: cw,
            placeholder: AgrypnosCopy.notifDiscordPlaceholder,
            label: AgrypnosCopy.notifDiscord,
            help: AgrypnosCopy.notifDiscordHelp,
            target: self,
            action: #selector(discordCommitted(_:)),
            delegate: self
        )
        discordStatus = LabelFactory.wrapping(
            "",
            font: .systemFont(ofSize: 12),
            color: .labelColor,
            lines: PopoverCopyLayout.notifDiscordStatusMaxLines
        )
        discordStatus.frame = NSRect(
            x: ci,
            y: CGFloat(PopoverStackLayout.notifDiscordStatusY),
            width: cw,
            height: CGFloat(PopoverCopyLayout.notifDiscordStatusHeightPoints)
        )
        discordStatus.preferredMaxLayoutWidth = cw
        card.addSubview(discordStatus)
    }

    func addNotifDiscordInboundCard(
        _ card: CardView,
        contentW: CGFloat,
        ci: CGFloat,
        cw: CGFloat,
        swW: CGFloat,
        swH: CGFloat
    ) {
        addPrefTitle(AgrypnosCopy.notifDiscordInbound, in: card, ci: ci, width: cw)
        _ = PopoverForm.help(
            AgrypnosCopy.notifDiscordInboundHelp,
            in: card,
            y: CGFloat(PopoverStackLayout.prefHelpY),
            x: ci,
            width: cw,
            lines: PopoverCopyLayout.notifDiscordInboundHelpMaxLines
        )
        discordInboundTokenSecrets = PopoverForm.labeledSecretField(
            in: card,
            y: CGFloat(PopoverStackLayout.notifDiscordInboundTokenY),
            x: ci,
            width: cw,
            caption: AgrypnosCopy.notifDiscordInboundTokenShort,
            placeholder: AgrypnosCopy.notifDiscordInboundTokenPlaceholder,
            label: AgrypnosCopy.notifDiscordInboundToken,
            help: AgrypnosCopy.notifDiscordInboundHelp,
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
            help: AgrypnosCopy.notifDiscordInboundHelp,
            target: self,
            action: #selector(discordInboundChannelCommitted(_:)),
            delegate: self
        )
        discordInboundSwitch = PopoverForm.switchControl(
            in: card,
            y: CGFloat(PopoverStackLayout.notifDiscordInboundSwitchY),
            contentW: contentW,
            ci: ci,
            swW: swW,
            swH: swH,
            target: self,
            action: #selector(discordInboundToggled(_:))
        )
        discordInboundSwitch.state = DiscordInboundChrome.defaultEnabled ? .on : .off
        discordInboundSwitch.setAccessibilityLabel(AgrypnosCopy.notifDiscordInbound)
        discordInboundSwitch.setAccessibilityHelp(AgrypnosCopy.notifDiscordInboundHelp)
    }

    func addNotifTelegramCard(_ card: CardView, ci: CGFloat, cw: CGFloat) {
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
    }

    func addNotifTelegramInboundCard(
        _ card: CardView,
        contentW: CGFloat,
        ci: CGFloat,
        cw: CGFloat,
        swW: CGFloat,
        swH: CGFloat
    ) {
        addPrefTitle(AgrypnosCopy.notifTelegramInbound, in: card, ci: ci, width: cw)
        _ = PopoverForm.help(
            AgrypnosCopy.notifTelegramInboundHelp,
            in: card,
            y: CGFloat(PopoverStackLayout.prefHelpY),
            x: ci,
            width: cw,
            lines: PopoverCopyLayout.notifTelegramInboundHelpMaxLines
        )
        telegramInboundSwitch = PopoverForm.switchControl(
            in: card,
            y: CGFloat(PopoverStackLayout.notifTelegramInboundSwitchY),
            contentW: contentW,
            ci: ci,
            swW: swW,
            swH: swH,
            target: self,
            action: #selector(telegramInboundToggled(_:))
        )
        telegramInboundSwitch.state = TelegramInboundChrome.defaultEnabled ? .on : .off
        telegramInboundSwitch.setAccessibilityLabel(AgrypnosCopy.notifTelegramInbound)
        telegramInboundSwitch.setAccessibilityHelp(AgrypnosCopy.notifTelegramInboundHelp)
    }

    func addNotifSetupCard(_ card: CardView, ci: CGFloat, cw: CGFloat) {
        addPrefTitle(AgrypnosCopy.notifSetup, in: card, ci: ci, width: cw)
        _ = PopoverForm.help(
            AgrypnosCopy.notifSetupHelp,
            in: card,
            y: CGFloat(PopoverStackLayout.notifSetupHelpY),
            x: ci,
            width: cw,
            lines: PopoverCopyLayout.notifSetupHelpMaxLines
        )
    }

    func addNotifClearCard(_ card: CardView, ci: CGFloat, cw: CGFloat) {
        let button = NSButton(
            title: AgrypnosCopy.notifClear,
            target: self,
            action: #selector(clearNotifSecretsTapped)
        )
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.setAccessibilityLabel(AgrypnosCopy.notifClear)
        button.sizeToFit()
        let width = min(max(button.frame.width + 8, 120), cw)
        let height = max(button.frame.height, 24)
        let y = (CGFloat(PopoverStackLayout.loginCardHeight) - height) / 2
        button.frame = NSRect(x: ci, y: y, width: width, height: height)
        card.addSubview(button)
        notifClearButton = button
    }

    func refreshNotifChrome(runtime: WatchRuntime) {
        notifSwitch?.state = runtime.preferences.notifEnabled ? .on : .off
        telegramInboundSwitch?.state = runtime.preferences.telegramInboundEnabled ? .on : .off
        discordInboundSwitch?.state = runtime.preferences.discordInboundEnabled ? .on : .off
        discordStatus?.stringValue = discordInvalid ? AgrypnosCopy.notifDiscordInvalid : ""
    }

    func loadNotifSecretFields() {
        guard let runtime else { return }
        let secrets = runtime.notifSecrets()
        discordSecrets?.stringValue = secrets.discordWebhookURL ?? ""
        discordInboundTokenSecrets?.stringValue = secrets.discordBotToken ?? ""
        discordInboundChannelSecrets?.stringValue = secrets.discordChannelId ?? ""
        telegramTokenSecrets?.stringValue = secrets.telegramBotToken ?? ""
        telegramChatSecrets?.stringValue = secrets.telegramChatId ?? ""
        discordInvalid = false
        discordStatus?.stringValue = ""
    }

    func commitNotifFields() {
        flushSecretFieldEditor(discordSecrets?.field)
        flushSecretFieldEditor(discordInboundTokenSecrets?.field)
        flushSecretFieldEditor(discordInboundChannelSecrets?.field)
        flushSecretFieldEditor(telegramTokenSecrets?.field)
        flushSecretFieldEditor(telegramChatSecrets?.field)
        if let discordSecrets { discordCommitted(discordSecrets.field) }
        if let discordInboundTokenSecrets { discordInboundTokenCommitted(discordInboundTokenSecrets.field) }
        if let discordInboundChannelSecrets { discordInboundChannelCommitted(discordInboundChannelSecrets.field) }
        if let telegramTokenSecrets { telegramTokenCommitted(telegramTokenSecrets.field) }
        if let telegramChatSecrets { telegramChatCommitted(telegramChatSecrets.field) }
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

    @objc func discordCommitted(_ sender: NSTextField) {
        stopRecordingIfNeeded()
        flushSecretFieldEditor(sender)
        switch NotifDiscordFieldChrome.commit(sender.stringValue) {
        case .persist(let url):
            discordInvalid = false
            let saved = runtime?.setNotifDiscordWebhookURL(url) ?? true
            discordSecrets.stringValue = url
            if !saved {
                UserNotify.post(AgrypnosCopy.notifSaveFailed)
            }
        case .clear:
            break // empty: keep the stored secret
        case .reject:
            discordInvalid = true
            UserNotify.post(AgrypnosCopy.notifDiscordInvalid)
        }
        discordStatus?.stringValue = discordInvalid ? AgrypnosCopy.notifDiscordInvalid : ""
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
        runtime?.clearNotifSecrets()
        discordInvalid = false
        discordSecrets?.stringValue = ""
        discordInboundTokenSecrets?.stringValue = ""
        discordInboundChannelSecrets?.stringValue = ""
        telegramTokenSecrets?.stringValue = ""
        telegramChatSecrets?.stringValue = ""
        discordStatus?.stringValue = ""
    }
}
