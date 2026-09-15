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
        discordField = PopoverForm.secretField(
            in: card,
            y: CGFloat(PopoverStackLayout.notifDiscordFieldY),
            x: ci,
            width: cw,
            placeholder: "",
            secure: true,
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
        telegramTokenField = PopoverForm.secretField(
            in: card,
            y: CGFloat(PopoverStackLayout.notifTelegramTokenY),
            x: ci,
            width: cw,
            placeholder: "",
            secure: true,
            label: AgrypnosCopy.notifTelegramToken,
            help: AgrypnosCopy.notifTelegramHelp,
            target: self,
            action: #selector(telegramTokenCommitted(_:)),
            delegate: self
        )
        telegramChatField = PopoverForm.secretField(
            in: card,
            y: CGFloat(PopoverStackLayout.notifTelegramChatY),
            x: ci,
            width: cw,
            placeholder: "",
            secure: false,
            label: AgrypnosCopy.notifTelegramChatId,
            help: AgrypnosCopy.notifTelegramHelp,
            target: self,
            action: #selector(telegramChatCommitted(_:)),
            delegate: self
        )
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
        let secrets = runtime.notifSecrets()
        if discordField?.currentEditor() == nil {
            discordField?.stringValue = secrets.discordWebhookURL ?? ""
        }
        if telegramTokenField?.currentEditor() == nil {
            telegramTokenField?.stringValue = secrets.telegramBotToken ?? ""
        }
        if telegramChatField?.currentEditor() == nil {
            telegramChatField?.stringValue = secrets.telegramChatId ?? ""
        }
        discordStatus?.stringValue = discordInvalid ? AgrypnosCopy.notifDiscordInvalid : ""
    }

    func commitNotifFields() {
        if let discordField { discordCommitted(discordField) }
        if let telegramTokenField { telegramTokenCommitted(telegramTokenField) }
        if let telegramChatField { telegramChatCommitted(telegramChatField) }
    }

    @objc func notifToggled(_ sender: NSSwitch) {
        stopRecordingIfNeeded()
        runtime?.setNotifEnabled(sender.state == .on)
        refresh()
    }

    @objc func discordCommitted(_ sender: NSTextField) {
        stopRecordingIfNeeded()
        switch NotifDiscordFieldChrome.commit(sender.stringValue) {
        case .persist, .clear:
            discordInvalid = false
            _ = runtime?.setNotifDiscordWebhookURL(sender.stringValue)
            restoreDiscordFieldFromStore()
        case .reject:
            discordInvalid = true
            restoreDiscordFieldFromStore()
        }
        discordStatus?.stringValue = discordInvalid ? AgrypnosCopy.notifDiscordInvalid : ""
    }

    @objc func telegramTokenCommitted(_ sender: NSTextField) {
        stopRecordingIfNeeded()
        runtime?.setNotifTelegramBotToken(sender.stringValue)
        if sender.currentEditor() == nil {
            sender.stringValue = runtime?.notifSecrets().telegramBotToken ?? ""
        }
    }

    @objc func telegramChatCommitted(_ sender: NSTextField) {
        stopRecordingIfNeeded()
        runtime?.setNotifTelegramChatId(sender.stringValue)
        if sender.currentEditor() == nil {
            sender.stringValue = runtime?.notifSecrets().telegramChatId ?? ""
        }
    }

    @objc func clearNotifSecretsTapped() {
        stopRecordingIfNeeded()
        runtime?.clearNotifSecrets()
        discordInvalid = false
        discordField?.stringValue = ""
        telegramTokenField?.stringValue = ""
        telegramChatField?.stringValue = ""
        discordStatus?.stringValue = ""
    }

    private func restoreDiscordFieldFromStore() {
        discordField?.stringValue = runtime?.notifSecrets().discordWebhookURL ?? ""
    }
}
