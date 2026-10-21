import SwiftUI

extension Calendar {
    static let de: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "de_DE")
        c.timeZone = .autoupdatingCurrent
        c.firstWeekday = 2
        c.minimumDaysInFirstWeek = 4
        return c
    }()

    func startOfMonth(_ date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date))!
    }

    func adding(days: Int, to date: Date) -> Date {
        self.date(byAdding: .day, value: days, to: date)!
    }
}

enum Fmt {
    private static var cache: [String: DateFormatter] = [:]

    static func string(_ date: Date, _ format: String) -> String {
        if let f = cache[format] { return f.string(from: date) }
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.calendar = Calendar.de
        f.dateFormat = format
        cache[format] = f
        return f.string(from: date)
    }

    static func time(_ date: Date) -> String { string(date, "HH:mm") }

    static func range(_ a: Agenda) -> String {
        if a.isAllDay { return "ganztägig" }
        return "\(time(a.start)) - \(time(a.end))"
    }

    static func countdown(to date: Date, from now: Date) -> String {
        let minutes = Int((date.timeIntervalSince(now) / 60).rounded(.up))
        if minutes <= 0 { return "jetzt" }
        if minutes < 60 { return "in \(minutes) Min." }
        let hours = minutes / 60, rest = minutes % 60
        if hours < 3 && rest >= 5 { return "in \(hours) Std. \(rest) Min." }
        if hours < 24 { return "in \(hours) Std." }
        let days = Int((Double(minutes) / 1440).rounded())
        return days == 1 ? "in 1 Tag" : "in \(days) Tagen"
    }

    static func remaining(until date: Date, from now: Date) -> String {
        let minutes = max(1, Int((date.timeIntervalSince(now) / 60).rounded(.up)))
        if minutes < 60 { return "\(minutes) Min." }
        let hours = minutes / 60, rest = minutes % 60
        return rest == 0 ? "\(hours) Std." : "\(hours) Std. \(rest) Min."
    }

    static func dayTitle(_ day: Date, now: Date, cal: Calendar = .de) -> String {
        if cal.isDate(day, inSameDayAs: now) { return "Heute" }
        if cal.isDate(day, inSameDayAs: cal.adding(days: 1, to: now)) { return "Morgen" }
        if cal.isDate(day, inSameDayAs: cal.adding(days: -1, to: now)) { return "Gestern" }
        return string(day, "EEEE")
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

enum Brand {
    static let sun = Color(hex: 0xFFB347)
    static let ember = Color(hex: 0xFF6B6B)
    static let gradient = LinearGradient(colors: [Color(hex: 0xFFA552), Color(hex: 0xFF5F7E)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(.primary.opacity(0.12))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }
}
