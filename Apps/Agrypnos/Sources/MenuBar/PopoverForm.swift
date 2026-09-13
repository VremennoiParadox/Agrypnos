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

    static func help(
        _ text: String,
        in card: NSView,
        y: CGFloat,
        x: CGFloat,
        width: CGFloat
    ) -> NSTextField {
        let field = LabelFactory.wrapping(
            text,
            font: .systemFont(ofSize: 12),
            color: .secondaryLabelColor,
            lines: PopoverCopyLayout.helpMaxLines
        )
        field.frame = NSRect(
            x: x,
            y: y,
            width: width,
            height: CGFloat(PopoverCopyLayout.helpHeightPoints)
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
}
