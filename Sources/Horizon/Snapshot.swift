import SwiftUI

/// `Horizon --snapshot <dir> [detail|place]` renders the popover in light and dark mode to PNGs and quits.
/// Used to check both appearances without clicking through the menu bar.
@MainActor
enum Snapshot {
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count else { return }
        let dir = URL(fileURLWithPath: args[i + 1])
        let mode = i + 2 < args.count ? args[i + 2] : "main"

        let store = CalendarStore()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            switch mode {
            case "detail":
                if let item = store.agendaSections().first?.items.first { store.panel = .detail(item) }
            case "place":
                store.panel = .place
            default:
                break
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                    render(store: store, appearance: NSAppearance(named: appearance)!,
                           to: dir.appendingPathComponent("horizon-\(mode)-\(name).png"))
                }
                exit(0)
            }
        }
    }

    private static func render(store: CalendarStore, appearance: NSAppearance, to url: URL) {
        let host = NSHostingView(rootView: PopoverView().environmentObject(store))
        host.appearance = appearance
        let size = host.fittingSize
        let window = NSWindow(contentRect: NSRect(origin: CGPoint(x: -4000, y: -4000), size: size),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = appearance
        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effect.material = .popover
        effect.state = .active
        effect.blendingMode = .behindWindow
        host.frame = effect.bounds
        effect.addSubview(host)
        window.contentView = effect
        window.orderFrontRegardless()
        effect.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))

        guard let rep = effect.bitmapImageRepForCachingDisplay(in: effect.bounds) else { return }
        effect.cacheDisplay(in: effect.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        window.orderOut(nil)
    }
}
