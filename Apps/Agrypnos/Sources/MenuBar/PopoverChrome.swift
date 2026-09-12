import AppKit

enum AgrypnosPalette {
    static let indigo = NSColor(srgbRed: 0.42, green: 0.38, blue: 0.92, alpha: 1)
    static let gold = NSColor(srgbRed: 0.90, green: 0.74, blue: 0.38, alpha: 1)
}

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
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
    static func image(_ glyph: AgrypnosGlyph) -> NSImage {
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
        guard glyph == .armed else {
            base.isTemplate = true
            return base
        }
        let size = base.size
        guard size.width > 0 else { base.isTemplate = true; return base }
        let composed = NSImage(size: size)
        composed.lockFocus()
        base.draw(in: NSRect(origin: .zero, size: size))
        let d = max(size.height * 0.24, 3.5)
        NSBezierPath(ovalIn: NSRect(x: size.width - d, y: size.height - d, width: d, height: d)).fill()
        composed.unlockFocus()
        composed.isTemplate = true
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
