import AppKit

enum AgrypnosPalette {
    static let indigo = NSColor(srgbRed: 0.42, green: 0.38, blue: 0.92, alpha: 1)
    static let gold = NSColor(srgbRed: 0.90, green: 0.74, blue: 0.38, alpha: 1)
}

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// Clip view must match the flipped document. A stock NSClipView shows Quit first.
final class FlippedClipView: NSClipView {
    override var isFlipped: Bool { true }

    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var bounds = super.constrainBoundsRect(proposedBounds)
        guard let documentView else { return bounds }
        if bounds.height > documentView.frame.height {
            bounds.origin.y = 0
        }
        return bounds
    }
}

final class GlassView: NSVisualEffectView {
    override var isFlipped: Bool { true }
}

final class CardView: NSView {
    var active = false {
        didSet { if active != oldValue { needsDisplay = true } }
    }

    override var isFlipped: Bool { true }
    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if active {
            layer?.backgroundColor = AgrypnosPalette.indigo.withAlphaComponent(dark ? 0.22 : 0.12).cgColor
            layer?.borderColor = AgrypnosPalette.indigo.withAlphaComponent(dark ? 0.65 : 0.4).cgColor
        } else {
            layer?.backgroundColor = (dark ? NSColor.white.withAlphaComponent(0.06) : NSColor.black.withAlphaComponent(0.045)).cgColor
            layer?.borderColor = (dark ? NSColor.white.withAlphaComponent(0.08) : NSColor.black.withAlphaComponent(0.06)).cgColor
        }
        layer?.borderWidth = 1
        layer?.cornerRadius = 11
        layer?.cornerCurve = .continuous
    }
}

enum AgrypnosGlyph {
    case off
    case on
    case armed
    case busy
}

enum GlyphFactory {
    static func image(_ glyph: AgrypnosGlyph, color: NSColor? = nil) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium).applying(.init(scale: .medium))
        let name: String
        switch glyph {
        case .off: name = "eye.slash"
        case .on, .armed: name = "eye"
        case .busy: name = "eye.fill"
        }
        let base = NSImage(systemSymbolName: name, accessibilityDescription: "Agrypnos")?
            .withSymbolConfiguration(config)
            ?? NSImage()
        // SF symbols have different intrinsic heights. A shared canvas keeps
        // the status-bar host window from changing height with the watch state.
        let size = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)?.size ?? base.size
        let rect = NSRect(x: (size.width - base.size.width) / 2,
                          y: (size.height - base.size.height) / 2,
                          width: base.size.width, height: base.size.height)
        let composed = NSImage(size: size, flipped: false) { _ in
            base.draw(in: rect)
            if glyph == .armed {
                NSColor.black.setFill()
                let d = max(base.size.height * 0.24, 3.5)
                NSBezierPath(ovalIn: NSRect(x: rect.maxX - d, y: rect.maxY - d,
                                           width: d, height: d)).fill()
            }
            if let color {
                color.setFill()
                NSRect(origin: .zero, size: size).fill(using: .sourceIn)
            }
            return true
        }
        composed.isTemplate = color == nil
        return composed
    }
}

enum LabelFactory {
    static func make(_ text: String, font: NSFont, color: NSColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = font
        field.textColor = color
        field.isEditable = false
        field.isBordered = false
        field.drawsBackground = false
        return field
    }

    static func wrapping(_ text: String, font: NSFont, color: NSColor, lines: Int) -> NSTextField {
        let field = make(text, font: font, color: color)
        field.usesSingleLineMode = false
        field.maximumNumberOfLines = lines
        field.lineBreakMode = .byWordWrapping
        if let cell = field.cell as? NSTextFieldCell {
            cell.wraps = true
            cell.truncatesLastVisibleLine = false
        }
        return field
    }
}
