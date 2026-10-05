// Run Scripts/check-popover-anchor-macos.sh.
// Exercises real AppKit geometry with mocked power/network actions.
import AppKit

@main
struct PopoverAnchorCheck {
    @MainActor
    static func main() async throws {
        setbuf(stdout, nil)
        NSApplication.shared.setActivationPolicy(.prohibited)
        let defaults = UserDefaults(suiteName: "agrypnos-anchor-check-" + UUID().uuidString)!
        let runtime = WatchRuntime(store: PreferencesStore(defaults: defaults),
            readLid: { false }, readKernel: { .clear }, setKernel: { _ in .ok },
            runCommand: { _, _ in (0, "", "") }, postIdle: { _, _ in }, notify: { _ in })
        let controller = PopoverController(runtime: runtime)
        controller.popover.animates = false
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { controller.close(); NSStatusBar.system.removeStatusItem(item) }
        let button = item.button!
        button.image = GlyphFactory.image(.off)
        button.imageScaling = .scaleProportionallyDown
        button.imagePosition = .imageOnly
        try await Task.sleep(nanoseconds: 100_000_000)
        controller.open(relativeTo: button)
        var failures: [String] = []
        func checkAnchor(_ label: String) {
            let image = button.cell!.imageRect(forBounds: button.bounds)
            let anchor = controller.popover.positioningRect
            print("\(label): bounds=\(button.bounds), eye=\(image), anchor=\(anchor)")
            if abs(anchor.midX - image.midX) > 0.5 {
                failures.append(label + " arrow must follow the eye")
            }
            if anchor.minY != button.bounds.minY || anchor.maxY != button.bounds.maxY {
                failures.append(label + " must keep the menu-bar edge")
            }
            if !button.bounds.contains(anchor) { failures.append(label + " anchor outside button") }
        }
        checkAnchor("off")
        for duration in [DurationOption.oneHour, .untilAgentsSettle] {
            _ = runtime.engine.userSetDuration(duration, now: Date())
            _ = runtime.engine.userSetEngaged(true, now: Date())
            button.title = duration == .untilAgentsSettle ? "Agents." : "Armed."
            button.imagePosition = .imageLeading
            button.imageHugsTitle = true
            item.length = NSStatusItem.variableLength
            controller.refresh()
            try await Task.sleep(nanoseconds: 100_000_000)
            checkAnchor("on \(button.title)")
            _ = runtime.engine.userSetEngaged(false, now: Date())
            button.title = ""
            button.imagePosition = .imageOnly
            button.imageHugsTitle = false
            item.length = NSStatusItem.squareLength
            controller.refresh()
            try await Task.sleep(nanoseconds: 100_000_000)
            checkAnchor("off after \(duration)")
        }
        // AppKit may resize the status button after the runtime refresh has returned.
        button.title = "Armed."
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        item.length = NSStatusItem.variableLength
        try await Task.sleep(nanoseconds: 100_000_000)
        checkAnchor("deferred resize without refresh")
        controller.close()
        controller.open(relativeTo: button)
        checkAnchor("opened while on")
        for turn in 0..<10 {
            button.title = turn.isMultiple(of: 2) ? "" : "Agents."
            button.imagePosition = turn.isMultiple(of: 2) ? .imageOnly : .imageLeading
            button.imageHugsTitle = !turn.isMultiple(of: 2)
            item.length = turn.isMultiple(of: 2) ? NSStatusItem.squareLength : NSStatusItem.variableLength
            try await Task.sleep(nanoseconds: 30_000_000)
            checkAnchor("repeat \(turn)")
        }
        controller.applySection(.general)
        try await Task.sleep(nanoseconds: 350_000_000)
        checkAnchor("section resize")
        if !failures.isEmpty {
            print(failures.joined(separator: "\n"))
            throw NSError(domain: "PopoverAnchorCheck", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "\(failures.count) anchor checks failed"])
        }
        print("Popover anchor checks passed")
    }
}
