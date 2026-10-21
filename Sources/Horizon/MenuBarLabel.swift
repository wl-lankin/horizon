import SwiftUI

enum BarStyle: String, CaseIterable, Identifiable {
    case icon, date, next

    var id: String { rawValue }

    var label: String {
        switch self {
        case .icon: "Nur Symbol"
        case .date: "Symbol und Datum"
        case .next: "Symbol und nächster Termin"
        }
    }
}

struct MenuBarLabel: View {
    @ObservedObject var store: CalendarStore
    @AppStorage("barStyle") private var barStyle = BarStyle.next.rawValue

    var body: some View {
        let day = store.cal.component(.day, from: store.now)
        HStack(spacing: 4) {
            Image(nsImage: BarIcon.image(day: day))
            if let text { Text(text) }
        }
    }

    private var text: String? {
        switch BarStyle(rawValue: barStyle) ?? .next {
        case .icon:
            return nil
        case .date:
            return Fmt.string(store.now, "EE d. MMM")
        case .next:
            guard let focus = store.focusEvent else { return nil }
            let title = focus.event.title.count > 18 ? focus.event.title.prefix(17) + "…" : Substring(focus.event.title)
            if focus.ongoing {
                return "\(title) · noch \(Fmt.remaining(until: focus.event.end, from: store.now))"
            }
            guard focus.event.start.timeIntervalSince(store.now) <= 60 * 60 else { return nil }
            return "\(title) \(Fmt.countdown(to: focus.event.start, from: store.now))"
        }
    }
}

/// Menu bar glyph: a rounded tile with the day number punched out, so it tints like a system icon.
enum BarIcon {
    private static var cache: [Int: NSImage] = [:]

    static func image(day: Int) -> NSImage {
        if let cached = cache[day] { return cached }
        let size = NSSize(width: 19, height: 16)
        let image = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let tile = NSRect(x: 1, y: 0.5, width: 17, height: 15)
            NSColor.black.setFill()
            NSBezierPath(roundedRect: tile, xRadius: 4.2, yRadius: 4.2).fill()

            ctx.setBlendMode(.destinationOut)
            let font = NSFont.systemFont(ofSize: 10.5, weight: .bold)
            let digits = NSFont(descriptor: font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor, size: 10.5) ?? font
            let attrs: [NSAttributedString.Key: Any] = [.font: digits, .foregroundColor: NSColor.black]
            let str = NSAttributedString(string: "\(day)", attributes: attrs)
            let s = str.size()
            str.draw(at: NSPoint(x: tile.midX - s.width / 2, y: tile.midY - s.height / 2 - 0.5))

            // Thin horizon line across the bottom of the tile.
            NSBezierPath(rect: NSRect(x: tile.minX + 4, y: 2.6, width: tile.width - 8, height: 1)).fill()
            return true
        }
        image.isTemplate = true
        cache[day] = image
        return image
    }
}
