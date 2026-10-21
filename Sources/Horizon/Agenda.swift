import SwiftUI
import EventKit

struct Agenda: Identifiable, Hashable {
    let id: String
    let eventID: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: Color
    let calendarTitle: String
    let location: String?
    let meetingURL: URL?

    init(_ e: EKEvent) {
        eventID = e.eventIdentifier ?? UUID().uuidString
        id = "\(eventID)@\(e.startDate.timeIntervalSince1970)"
        let t = e.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        title = t.isEmpty ? "Ohne Titel" : t
        start = e.startDate
        end = e.endDate
        isAllDay = e.isAllDay
        color = Color(nsColor: e.calendar?.color ?? .systemBlue)
        calendarTitle = e.calendar?.title ?? ""
        let loc = e.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        location = loc.isEmpty ? nil : loc
        meetingURL = MeetingLink.find(in: e)
    }

    func isOngoing(at now: Date) -> Bool { start <= now && end > now }

    func progress(at now: Date) -> Double {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        return min(1, max(0, now.timeIntervalSince(start) / total))
    }
}

struct AgendaSection: Identifiable {
    let day: Date
    let items: [Agenda]
    var id: Date { day }
}

enum MeetingLink {
    private static let hosts = ["zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com",
                                "webex.com", "whereby.com", "meet.jit.si", "facetime.apple.com", "gotomeeting.com"]
    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    static func find(in e: EKEvent) -> URL? {
        if let url = e.url, isMeeting(url) { return url }
        for text in [e.location, e.notes].compactMap({ $0 }) {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector?.matches(in: text, range: range) ?? [] {
                if let url = match.url, isMeeting(url) { return url }
            }
        }
        return nil
    }

    private static func isMeeting(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return hosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}
