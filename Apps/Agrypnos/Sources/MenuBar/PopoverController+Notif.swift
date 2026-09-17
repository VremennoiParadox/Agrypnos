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
        telegramTokenField = PopoverForm.labeledSecretField(
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
        telegramChatField = PopoverForm.labeledSecretField(
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
        discordStatus?.stringValue = discordInvalid ? AgrypnosCopy.notifDiscordInvalid : ""
    }

    func loadNotifSecretFields() {
        guard let runtime else { return }
        let secrets = runtime.notifSecrets()
        discordField?.stringValue = secrets.discordWebhookURL ?? ""
        telegramTokenField?.stringValue = secrets.telegramBotToken ?? ""
        telegramChatField?.stringValue = secrets.telegramChatId ?? ""
        discordInvalid = false
        discordStatus?.stringValue = ""
    }

    func commitNotifFields() {
        flushSecretFieldEditor(discordField)
        flushSecretFieldEditor(telegramTokenField)
        flushSecretFieldEditor(telegramChatField)
        if let discordField { discordCommitted(discordField) }
        if let telegramTokenField { telegramTokenCommitted(telegramTokenField) }
        if let telegramChatField { telegramChatCommitted(telegramChatField) }
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

    @objc func discordCommitted(_ sender: NSTextField) {
        stopRecordingIfNeeded()
        flushSecretFieldEditor(sender)
        switch NotifSecretLeaveChrome.storeAction(NotifDiscordFieldChrome.commit(sender.stringValue)) {
        case .persist(let url):
            discordInvalid = false
            let saved = runtime?.setNotifDiscordWebhookURL(url) ?? true
            sender.stringValue = url
            if !saved {
                UserNotify.post(AgrypnosCopy.notifSaveFailed)
            }
        case .skip:
            break
        case .reject:
            discordInvalid = true
            UserNotify.post(AgrypnosCopy.notifDiscordInvalid)
        }
        discordStatus?.stringValue = discordInvalid ? AgrypnosCopy.notifDiscordInvalid : ""
    }

    @objc func telegramTokenCommitted(_ sender: NSTextField) {
        stopRecordingIfNeeded()
        flushSecretFieldEditor(sender)
        switch NotifSecretLeaveChrome.storeAction(TelegramBotTokenChrome.commit(sender.stringValue)) {
        case .persist(let token):
            let saved = runtime?.setNotifTelegramBotToken(token) ?? true
            sender.stringValue = token
            if !saved {
                UserNotify.post(AgrypnosCopy.notifSaveFailed)
            }
        case .skip:
            break
        case .reject:
            UserNotify.post(AgrypnosCopy.notifTelegramTokenInvalid)
        }
    }

    @objc func telegramChatCommitted(_ sender: NSTextField) {
        stopRecordingIfNeeded()
        flushSecretFieldEditor(sender)
        switch NotifSecretLeaveChrome.storeAction(TelegramChatIdChrome.commit(sender.stringValue)) {
        case .persist(let id):
            let saved = runtime?.setNotifTelegramChatId(id) ?? true
            sender.stringValue = id
            if !saved {
                UserNotify.post(AgrypnosCopy.notifSaveFailed)
            }
        case .skip:
            break
        case .reject:
            UserNotify.post(AgrypnosCopy.notifTelegramChatInvalid)
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
}
