import AppKit

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

@MainActor
enum PopoverForm {
    static var percentValueWidth: CGFloat { CGFloat(PopoverCopyLayout.percentValueWidthPoints) }
    static var timeValueWidth: CGFloat { CGFloat(PopoverCopyLayout.timeValueWidthPoints) }

    static func card(in root: NSView, slot: PopoverSlot, pad: CGFloat, width: CGFloat) -> CardView {
        let view = CardView(frame: NSRect(
            x: pad,
            y: CGFloat(slot.y),
            width: width,
            height: CGFloat(slot.height)
        ))
        view.wantsLayer = true
        root.addSubview(view)
        return view
    }

    static func apply(_ view: NSView, slot: PopoverSlot?, pad: CGFloat, width: CGFloat) {
        guard let slot else {
            view.isHidden = true
            return
        }
        view.isHidden = false
        view.frame = NSRect(
            x: pad,
            y: CGFloat(slot.y),
            width: width,
            height: CGFloat(slot.height)
        )
    }

    static func switchControl(
        in card: NSView,
        y: CGFloat,
        contentW: CGFloat,
        ci: CGFloat,
        swW: CGFloat,
        swH: CGFloat,
        target: AnyObject,
        action: Selector
    ) -> NSSwitch {
        let toggle = NSSwitch()
        toggle.target = target
        toggle.action = action
        toggle.frame = NSRect(
            x: contentW - ci - swW,
            y: CGFloat(PopoverStackLayout.switchControlY(labelY: Double(y), switchHeight: Double(swH))),
            width: swW,
            height: swH
        )
        card.addSubview(toggle)
        return toggle
    }

    static func switchRow(
        in card: NSView,
        y: CGFloat,
        title: String,
        contentW: CGFloat,
        ci: CGFloat,
        cw: CGFloat,
        swW: CGFloat,
        swH: CGFloat,
        target: AnyObject,
        action: Selector,
        trailing: CGFloat = 0
    ) -> NSSwitch {
        let label = LabelFactory.make(title, font: .systemFont(ofSize: 13), color: .labelColor)
        let labelH = CGFloat(PopoverStackLayout.switchRowLabelHeight)
        label.frame = NSRect(x: ci, y: y, width: cw - swW - 8 - trailing, height: labelH)
        card.addSubview(label)
        return switchControl(
            in: card,
            y: y,
            contentW: contentW,
            ci: ci,
            swW: swW,
            swH: swH,
            target: target,
            action: action
        )
    }

    static func help(
        _ text: String,
        in card: NSView,
        y: CGFloat,
        x: CGFloat,
        width: CGFloat,
        lines: Int = PopoverCopyLayout.helpMaxLines
    ) -> NSTextField {
        let field = LabelFactory.wrapping(
            text,
            font: .systemFont(ofSize: 12),
            color: .secondaryLabelColor,
            lines: lines
        )
        field.frame = NSRect(
            x: x,
            y: y,
            width: width,
            height: CGFloat(lines * PopoverCopyLayout.lineHeightPoints)
        )
        field.preferredMaxLayoutWidth = width
        card.addSubview(field)
        return field
    }

    static func valueLabel(
        in card: NSView,
        y: CGFloat,
        contentW: CGFloat,
        ci: CGFloat,
        text: String,
        width: CGFloat = CGFloat(PopoverCopyLayout.percentValueWidthPoints),
        besideSwitch swW: CGFloat? = nil
    ) -> NSTextField {
        let field = LabelFactory.make(
            text,
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: .secondaryLabelColor
        )
        field.alignment = .right
        let x: CGFloat
        if let swW {
            x = contentW - ci - swW - 8 - width
        } else {
            x = contentW - ci - width
        }
        field.frame = NSRect(x: x, y: y, width: width, height: 18)
        card.addSubview(field)
        return field
    }

    static func slider(
        in card: NSView,
        sliderY: CGFloat,
        minMaxY: CGFloat,
        ci: CGFloat,
        cw: CGFloat,
        contentW: CGFloat,
        minValue: Double,
        maxValue: Double,
        value: Double,
        minLabel: String,
        maxLabel: String,
        target: AnyObject,
        action: Selector
    ) -> NSSlider {
        let slider = NSSlider(
            value: value,
            minValue: minValue,
            maxValue: maxValue,
            target: target,
            action: action
        )
        slider.isContinuous = true
        slider.frame = NSRect(x: ci, y: sliderY, width: cw, height: 20)
        card.addSubview(slider)
        let minHint = LabelFactory.make(minLabel, font: .systemFont(ofSize: 10), color: .tertiaryLabelColor)
        minHint.frame = NSRect(x: ci, y: minMaxY, width: 40, height: 13)
        card.addSubview(minHint)
        let maxHint = LabelFactory.make(maxLabel, font: .systemFont(ofSize: 10), color: .tertiaryLabelColor)
        maxHint.alignment = .right
        maxHint.frame = NSRect(x: contentW - ci - 40, y: minMaxY, width: 40, height: 13)
        card.addSubview(maxHint)
        return slider
    }

    static func secretField(
        in card: NSView,
        y: CGFloat,
        x: CGFloat,
        width: CGFloat,
        placeholder: String,
        label: String,
        help: String,
        target: AnyObject,
        action: Selector,
        delegate: NSTextFieldDelegate
    ) -> SecretRevealRow {
        let row = SecretRevealRow(
            frame: NSRect(x: x, y: y, width: width, height: 24),
            placeholder: placeholder,
            label: label,
            help: help,
            target: target,
            action: action,
            delegate: delegate
        )
        card.addSubview(row)
        return row
    }

    static func labeledSecretField(
        in card: NSView,
        y: CGFloat,
        x: CGFloat,
        width: CGFloat,
        caption: String,
        placeholder: String,
        label: String,
        help: String,
        target: AnyObject,
        action: Selector,
        delegate: NSTextFieldDelegate
    ) -> SecretRevealRow {
        let labelW = CGFloat(PopoverCopyLayout.secretFieldLabelWidthPoints)
        let captionField = LabelFactory.make(caption, font: .systemFont(ofSize: 13), color: .labelColor)
        captionField.frame = NSRect(
            x: x,
            y: y,
            width: labelW,
            height: CGFloat(PopoverStackLayout.switchRowLabelHeight)
        )
        card.addSubview(captionField)
        return secretField(
            in: card,
            y: y,
            x: x + labelW + 8,
            width: max(width - labelW - 8, 80),
            placeholder: placeholder,
            label: label,
            help: help,
            target: target,
            action: action,
            delegate: delegate
        )
    }
}

/// Dots by default. Eye button swaps in a plain field so the user can check a paste.
@MainActor
final class SecretRevealRow: NSView {
    private let secureField = PopoverSecureTextField(string: "")
    private let plainField = PopoverTextField(string: "")
    private let revealButton = NSButton(title: "", target: nil, action: nil)
    private let fieldLabel: String
    private var isRevealed = false

    override var isFlipped: Bool { true }

    var field: NSTextField { isRevealed ? plainField : secureField }

    var stringValue: String {
        get { field.stringValue }
        set {
            secureField.stringValue = newValue
            plainField.stringValue = newValue
        }
    }

    func contains(_ field: NSTextField) -> Bool {
        field === secureField || field === plainField
    }

    init(
        frame: NSRect,
        placeholder: String,
        label: String,
        help: String,
        target: AnyObject,
        action: Selector,
        delegate: NSTextFieldDelegate
    ) {
        fieldLabel = label
        super.init(frame: frame)
        configure(
            secureField,
            placeholder: placeholder,
            label: label,
            help: help,
            target: target,
            action: action,
            delegate: delegate
        )
        configure(
            plainField,
            placeholder: placeholder,
            label: label,
            help: help,
            target: target,
            action: action,
            delegate: delegate
        )
        let fieldW = CGFloat(SecretRevealChrome.fieldWidth(total: Int(frame.width.rounded(.down))))
        let fieldFrame = NSRect(x: 0, y: 0, width: fieldW, height: frame.height)
        secureField.frame = fieldFrame
        plainField.frame = fieldFrame
        plainField.isHidden = true
        addSubview(secureField)
        addSubview(plainField)

        revealButton.target = self
        revealButton.action = #selector(toggleReveal)
        revealButton.bezelStyle = .inline
        revealButton.isBordered = false
        revealButton.imagePosition = .imageOnly
        revealButton.frame = NSRect(
            x: fieldW + CGFloat(SecretRevealChrome.gapPoints),
            y: 0,
            width: CGFloat(SecretRevealChrome.buttonWidthPoints),
            height: frame.height
        )
        applyRevealChrome()
        addSubview(revealButton)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    @objc private func toggleReveal() {
        let editing = field.currentEditor() != nil
        if let editor = field.currentEditor() as? NSText {
            field.stringValue = editor.string
        }
        let value = field.stringValue
        field.isHidden = true
        isRevealed = SecretRevealChrome.nextRevealed(isRevealed)
        stringValue = value
        field.isHidden = false
        applyRevealChrome()
        if editing {
            window?.makeFirstResponder(field)
        }
    }

    private func applyRevealChrome() {
        let access = AgrypnosCopy.revealAccess(label: fieldLabel, revealed: isRevealed)
        let name = SecretRevealChrome.symbolName(revealed: isRevealed)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: access)
        image?.isTemplate = true
        revealButton.image = image
        revealButton.contentTintColor = .secondaryLabelColor
        revealButton.setAccessibilityLabel(access)
        revealButton.toolTip = access
    }

    private func configure(
        _ field: NSTextField,
        placeholder: String,
        label: String,
        help: String,
        target: AnyObject,
        action: Selector,
        delegate: NSTextFieldDelegate
    ) {
        field.placeholderString = placeholder
        field.font = .systemFont(ofSize: 13)
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.isEditable = true
        field.isSelectable = true
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.delegate = delegate
        field.target = target
        field.action = action
        field.cell?.sendsActionOnEndEditing = true
        field.setAccessibilityLabel(label)
        field.setAccessibilityHelp(help)
    }
}

/// Accessory apps often fail to make the popover key. Clicking a field
/// activates Agrypnos so Cmd+V can reach the field editor. Smart quotes
/// stay off so pasted tokens and webhook URLs are not rewritten.
final class PopoverTextField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKey()
        let ok = super.becomeFirstResponder()
        disarmSmartQuotes(in: currentEditor() as? NSTextView)
        return ok
    }
}

final class PopoverSecureTextField: NSSecureTextField {
    override func becomeFirstResponder() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKey()
        let ok = super.becomeFirstResponder()
        disarmSmartQuotes(in: currentEditor() as? NSTextView)
        return ok
    }
}

private func disarmSmartQuotes(in editor: NSTextView?) {
    guard let editor else { return }
    editor.isAutomaticQuoteSubstitutionEnabled = false
    editor.isAutomaticDashSubstitutionEnabled = false
    editor.isAutomaticTextReplacementEnabled = false
    editor.isAutomaticSpellingCorrectionEnabled = false
    editor.isContinuousSpellCheckingEnabled = false
    editor.allowsUndo = true
}
