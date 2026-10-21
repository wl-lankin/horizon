import Foundation

/// Small German natural-language parser: "Fr 14 Uhr Zahnarzt", "morgen 9:30-11 Friseur", "23.10. Geburtstag".
enum QuickAdd {
    struct Draft: Equatable {
        var title: String
        var start: Date
        var end: Date
        var allDay: Bool
    }

    private static let b = "(?<![\\p{L}\\d])"
    private static let e = "(?![\\p{L}\\d])"
    private static let weekdays: [String: Int] = [
        "montag": 2, "dienstag": 3, "mittwoch": 4, "donnerstag": 5, "freitag": 6, "samstag": 7, "sonntag": 1,
        "mo": 2, "di": 3, "mi": 4, "do": 5, "fr": 6, "sa": 7, "so": 1,
    ]

    static func parse(_ input: String, now: Date, cal: Calendar = .de) -> Draft? {
        guard !input.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        var text = " \(input) "
        let today = cal.startOfDay(for: now)

        func take(_ pattern: String) -> [String]? {
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let whole = Range(m.range, in: text) else { return nil }
            let groups = (0..<max(m.numberOfRanges, 6)).map { i -> String in
                guard i < m.numberOfRanges else { return "" }
                guard let r = Range(m.range(at: i), in: text) else { return "" }
                return String(text[r])
            }
            text.replaceSubrange(whole, with: " ")
            return groups
        }

        var day: Date?
        var weekdayTarget: Int?

        if let g = take(b + "(?:am\\s+)?(\\d{1,2})\\.(\\d{1,2})\\.(\\d{2,4})?" + e) {
            var comps = cal.dateComponents([.year], from: now)
            comps.day = Int(g[1]); comps.month = Int(g[2])
            if let y = Int(g[3]) { comps.year = y < 100 ? 2000 + y : y }
            if var d = cal.date(from: comps) {
                if g[3].isEmpty && d < today { d = cal.date(byAdding: .year, value: 1, to: d)! }
                day = d
            }
        } else if take(b + "übermorgen" + e) != nil {
            day = cal.adding(days: 2, to: today)
        } else if take(b + "morgen" + e) != nil {
            day = cal.adding(days: 1, to: today)
        } else if take(b + "heute" + e) != nil {
            day = today
        } else if let g = take(b + "in\\s+(\\d{1,3})\\s+tag(?:en)?" + e) {
            day = cal.adding(days: Int(g[1]) ?? 0, to: today)
        } else if let g = take(b + "(?:am\\s+|nächsten?\\s+)?(montag|dienstag|mittwoch|donnerstag|freitag|samstag|sonntag|mo|di|mi|do|fr|sa|so)\\.?" + e) {
            weekdayTarget = weekdays[g[1].lowercased()]
        }

        var start: (h: Int, m: Int)?
        var end: (h: Int, m: Int)?
        let hm = "(\\d{1,2})(?:[:.](\\d{2}))?"

        if let g = take(b + "(?:von\\s+|um\\s+|ab\\s+)?" + hm + "\\s*(?:uhr\\s*)?(?:-|–|bis)\\s*" + hm + "\\s*(?:uhr)?" + e) {
            start = (Int(g[1]) ?? 0, Int(g[2]) ?? 0)
            end = (Int(g[3]) ?? 0, Int(g[4]) ?? 0)
        } else if let g = take(b + "(?:um\\s+|ab\\s+)?(\\d{1,2})(?::(\\d{2}))?\\s*uhr" + e)
                    ?? take(b + "(?:um\\s+|ab\\s+)?(\\d{1,2}):(\\d{2})" + e)
                    ?? take(b + "(?:um|ab)\\s+(\\d{1,2})" + e) {
            start = (Int(g[1]) ?? 0, Int(g[2]) ?? 0)
        }
        if let s = start, s.h > 23 || s.m > 59 { start = nil; end = nil }

        var duration: TimeInterval = 3600
        if let g = take(b + "(?:für\\s+)?(\\d+(?:[.,]\\d+)?)\\s*(?:std\\.?|stunden?|h)" + e) {
            duration = (Double(g[1].replacingOccurrences(of: ",", with: ".")) ?? 1) * 3600
        } else if let g = take(b + "(?:für\\s+)?(\\d{1,3})\\s*min(?:\\.|uten)?" + e) {
            duration = (Double(g[1]) ?? 60) * 60
        }

        if let target = weekdayTarget {
            let current = cal.component(.weekday, from: today)
            var ahead = (target - current + 7) % 7
            if ahead == 0, let s = start, (s.h, s.m) <= (cal.component(.hour, from: now), cal.component(.minute, from: now)) {
                ahead = 7
            }
            day = cal.adding(days: ahead, to: today)
        }

        if day == nil {
            day = today
            if let s = start, (s.h, s.m) <= (cal.component(.hour, from: now), cal.component(.minute, from: now)) {
                day = cal.adding(days: 1, to: today)
            }
        }

        let title = cleanTitle(text)
        guard let base = day else { return nil }

        guard let s = start,
              let startDate = cal.date(bySettingHour: s.h, minute: s.m, second: 0, of: base) else {
            return Draft(title: title, start: base, end: cal.adding(days: 1, to: base), allDay: true)
        }
        var endDate = startDate.addingTimeInterval(duration)
        if let en = end, let candidate = cal.date(bySettingHour: min(en.h, 23), minute: min(en.m, 59), second: 0, of: base),
           candidate > startDate {
            endDate = candidate
        }
        return Draft(title: title, start: startDate, end: endDate, allDay: false)
    }

    private static func cleanTitle(_ raw: String) -> String {
        var words = raw.split(whereSeparator: \.isWhitespace).map(String.init)
        let fillers: Set<String> = ["am", "um", "von", "ab", "bis", "für", ",", "-", "·"]
        while let f = words.first, fillers.contains(f.lowercased()) { words.removeFirst() }
        while let l = words.last, fillers.contains(l.lowercased()) { words.removeLast() }
        let title = words.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: " ,;:-"))
        guard let first = title.first else { return "Neuer Termin" }
        return first.uppercased() + title.dropFirst()
    }
}
