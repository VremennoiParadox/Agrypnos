import AppKit

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

/// Read-only Bot setup guide. Instructions, links, and screenshots only — no settings.
@MainActor
final class BotGuideWindow: NSObject {
    private static let size = NSSize(width: 520, height: 640)
    private static let margin: CGFloat = 24
    private static var textWidth: CGFloat { size.width - 2 * margin }

    private let window = NSWindow(
        contentRect: NSRect(origin: .zero, size: size),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: true
    )
    private let tabs = NSSegmentedControl(
        labels: BotGuideTab.allCases.map(\.title),
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let scroll = NSScrollView()
    private let stack = NSStackView()
    private var links: [URL] = []
    private var placed = false

    override init() {
        super.init()
        window.title = BotGuide.windowTitle
        window.isReleasedWhenClosed = false
        tabs.target = self
        tabs.action = #selector(tabChanged)
        tabs.selectedSegment = 0
        layout()
        render(.telegram)
    }

    func show() {
        if !placed {
            window.center()
            placed = true
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func layout() {
        guard let content = window.contentView else { return }
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: Self.margin, bottom: Self.margin, right: Self.margin)

        let document = FlippedView()
        document.addSubview(stack)
        scroll.documentView = document
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false

        for view in [tabs, scroll, stack, document] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        content.addSubview(tabs)
        content.addSubview(scroll)
        NSLayoutConstraint.activate([
            tabs.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            tabs.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            scroll.topAnchor.constraint(equalTo: tabs.bottomAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            document.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor),
        ])
    }

    @objc private func tabChanged() {
        render(BotGuideTab.allCases[max(tabs.selectedSegment, 0)])
    }

    @objc private func linkTapped(_ sender: NSButton) {
        NSWorkspace.shared.open(links[sender.tag])
    }

    private func render(_ tab: BotGuideTab) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        links = []
        for section in BotGuide.sections(for: tab) {
            add(label(section.title, font: .boldSystemFont(ofSize: 16)), spacingAfter: 4)
            if let note = section.note {
                add(label(note, font: .systemFont(ofSize: 12), color: .secondaryLabelColor))
            }
            for (index, step) in section.steps.enumerated() {
                let title = section.numbered ? "\(index + 1). \(step.title)" : step.title
                add(label(title, font: .boldSystemFont(ofSize: 13)), spacingAfter: 2)
                add(label(step.body, font: .systemFont(ofSize: 13)))
                if let link = step.link, let url = URL(string: link.url) {
                    let button = NSButton(title: link.title, target: self, action: #selector(linkTapped(_:)))
                    button.bezelStyle = .rounded
                    button.tag = links.count
                    links.append(url)
                    add(button)
                }
                if let name = step.image, let image = NSImage(named: name) {
                    add(screenshot(image))
                }
            }
            if let last = stack.arrangedSubviews.last {
                stack.setCustomSpacing(24, after: last)
            }
        }
        scroll.contentView.scroll(to: .zero)
    }

    private func add(_ view: NSView, spacingAfter: CGFloat? = nil) {
        stack.addArrangedSubview(view)
        if let spacingAfter {
            stack.setCustomSpacing(spacingAfter, after: view)
        }
    }

    private func label(_ text: String, font: NSFont, color: NSColor = .labelColor) -> NSTextField {
        let field = LabelFactory.wrapping(text, font: font, color: color, lines: 0)
        field.isSelectable = true
        field.preferredMaxLayoutWidth = Self.textWidth
        field.widthAnchor.constraint(equalToConstant: Self.textWidth).isActive = true
        return field
    }

    private func screenshot(_ image: NSImage) -> NSImageView {
        let view = NSImageView(image: image)
        view.imageScaling = .scaleProportionallyUpOrDown
        view.wantsLayer = true
        view.layer?.cornerRadius = 8
        view.layer?.masksToBounds = true
        let aspect = image.size.width > 0 ? image.size.height / image.size.width : 0
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: Self.textWidth),
            view.heightAnchor.constraint(equalToConstant: Self.textWidth * aspect),
        ])
        return view
    }
}
