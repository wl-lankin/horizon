import SwiftUI

struct AgendaList: View {
    @EnvironmentObject var store: CalendarStore

    private let headerHeight: CGFloat = 30
    private let rowHeight: CGFloat = 44
    private let maxHeight: CGFloat = 250

    var body: some View {
        let sections = store.agendaSections()
        if sections.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "sun.haze.fill")
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Freie Bahn")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Keine Termine in den nächsten \(store.daysAhead) Tagen.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        } else {
            let rows = sections.reduce(0) { $0 + $1.items.count }
            let natural = CGFloat(sections.count) * headerHeight + CGFloat(rows) * rowHeight + 8
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(sections) { section in
                        SectionHeader(day: section.day, now: store.now)
                            .frame(height: headerHeight, alignment: .bottom)
                        ForEach(section.items) { e in
                            AgendaRow(event: e, day: section.day)
                                .frame(height: rowHeight)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.never)
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: min(natural, maxHeight))
        }
    }
}

private struct SectionHeader: View {
    let day: Date
    let now: Date

    var body: some View {
        HStack {
            Text(Fmt.dayTitle(day, now: now))
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            // The title already names the weekday unless it is a relative word like "Heute".
            Text(Fmt.string(day, Fmt.dayTitle(day, now: now) == Fmt.string(day, "EEEE") ? "d. MMMM" : "EE d. MMM"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 3)
    }
}

private struct AgendaRow: View {
    @EnvironmentObject var store: CalendarStore
    let event: Agenda
    let day: Date
    @State private var hover = false

    var body: some View {
        let now = store.now
        let ongoing = event.isOngoing(at: now) && !event.isAllDay
        let soon = event.start > now && event.start.timeIntervalSince(now) < 15 * 60

        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(event.color.gradient)
                .frame(width: 4, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if let url = event.meetingURL, ongoing || soon {
                JoinButton(url: url, color: event.color)
            } else if ongoing {
                Text("läuft")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(event.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(event.color.opacity(0.18)))
            } else if !event.isAllDay, event.start > now, event.start.timeIntervalSince(now) < 24 * 3600 {
                Text(Fmt.countdown(to: event.start, from: now))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else if event.meetingURL != nil {
                Image(systemName: "video")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(ongoing ? event.color.opacity(0.14) : .primary.opacity(hover ? 0.07 : 0))
        )
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { store.open(event) }
        .help("\(event.calendarTitle) · in „Kalender“ öffnen")
    }

    private var subtitle: String {
        var parts: [String] = []
        if event.isAllDay {
            parts.append("ganztägig")
        } else if !store.cal.isDate(event.start, inSameDayAs: event.end.addingTimeInterval(-1)) {
            parts.append("\(Fmt.string(event.start, "EE HH:mm")) - \(Fmt.string(event.end, "EE HH:mm"))")
        } else {
            parts.append(Fmt.range(event))
        }
        if let loc = event.location, event.meetingURL == nil || !loc.contains("://") {
            parts.append(loc.components(separatedBy: .newlines).first ?? loc)
        }
        return parts.joined(separator: " · ")
    }
}
