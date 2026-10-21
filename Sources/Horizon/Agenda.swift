import SwiftUI
import EventKit
import CoreLocation

struct Agenda: Identifiable, Hashable {
    enum Kind: Hashable { case event, reminder }

    struct Attendee: Hashable {
        let name: String
        let status: EKParticipantStatus
        let isMe: Bool
    }

    let kind: Kind
    let id: String
    let eventID: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: Color
    let calendarTitle: String
    let location: String?
    let coordinate: CLLocationCoordinate2D?
    let meetingURL: URL?
    let url: URL?
    let notes: String?
    let attendees: [Attendee]
    let isRecurring: Bool

    var isReminder: Bool { kind == .reminder }

    init(_ e: EKEvent) {
        kind = .event
        eventID = e.eventIdentifier ?? UUID().uuidString
        id = "\(eventID)@\(e.startDate.timeIntervalSince1970)"
        title = Self.clean(e.title) ?? "Ohne Titel"
        start = e.startDate
        end = e.endDate
        isAllDay = e.isAllDay
        color = Color(nsColor: e.calendar?.color ?? .systemBlue)
        calendarTitle = e.calendar?.title ?? ""
        location = Self.clean(e.location)
        coordinate = e.structuredLocation?.geoLocation?.coordinate
        meetingURL = MeetingLink.find(in: e)
        url = e.url
        notes = Self.clean(e.notes)
        attendees = (e.attendees ?? []).map {
            Attendee(name: $0.name ?? $0.url.absoluteString.replacingOccurrences(of: "mailto:", with: ""),
                     status: $0.participantStatus, isMe: $0.isCurrentUser)
        }
        isRecurring = e.hasRecurrenceRules
    }

    init(reminder r: EKReminder, due: Date, hasTime: Bool, cal: Calendar = .de) {
        kind = .reminder
        eventID = r.calendarItemIdentifier
        id = "r:\(eventID)"
        title = Self.clean(r.title) ?? "Ohne Titel"
        start = hasTime ? due : cal.startOfDay(for: due)
        end = hasTime ? due : cal.adding(days: 1, to: cal.startOfDay(for: due))
        isAllDay = !hasTime
        color = Color(nsColor: r.calendar?.color ?? .systemOrange)
        calendarTitle = r.calendar?.title ?? ""
        location = Self.clean(r.location)
        coordinate = nil
        meetingURL = nil
        url = r.url
        notes = Self.clean(r.notes)
        attendees = []
        isRecurring = r.hasRecurrenceRules
    }

    func isOngoing(at now: Date) -> Bool { !isReminder && start <= now && end > now }

    func isOverdue(at now: Date, cal: Calendar = .de) -> Bool {
        isReminder && (isAllDay ? end <= cal.startOfDay(for: now) : start < now)
    }

    func progress(at now: Date) -> Double {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        return min(1, max(0, now.timeIntervalSince(start) / total))
    }

    private static func clean(_ s: String?) -> String? {
        let t = s?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? nil : t
    }

    static func == (a: Agenda, b: Agenda) -> Bool { a.id == b.id && a.start == b.start && a.title == b.title }
    func hash(into h: inout Hasher) { h.combine(id) }
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
