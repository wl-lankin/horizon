import SwiftUI
import MapKit
import EventKit

struct DetailView: View {
    @EnvironmentObject var store: CalendarStore
    let item: Agenda

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(title: item.isReminder ? "Erinnerung" : "Termin")

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 10) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(item.color.gradient)
                            .frame(width: 4)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 17, weight: .semibold))
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                            Text(when)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Circle().fill(item.color).frame(width: 7, height: 7)
                                Text(item.calendarTitle)
                                if item.isRecurring {
                                    Image(systemName: "repeat").padding(.leading, 4)
                                    Text("wiederholt sich")
                                }
                            }
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)

                    if let url = item.meetingURL {
                        HStack {
                            JoinButton(url: url, color: item.color)
                            Text(url.host ?? "")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    if let location = item.location {
                        LocationBlock(location: location, coordinate: item.coordinate)
                    }

                    if !item.attendees.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            SectionLabel("Teilnehmer · \(item.attendees.count)")
                            ForEach(item.attendees.prefix(12), id: \.self) { a in
                                HStack(spacing: 7) {
                                    Image(systemName: a.status.symbol)
                                        .foregroundStyle(a.status.tint)
                                        .frame(width: 14)
                                    Text(a.name + (a.isMe ? " (du)" : ""))
                                        .lineLimit(1)
                                }
                                .font(.system(size: 12))
                            }
                            if item.attendees.count > 12 {
                                Text("und \(item.attendees.count - 12) weitere")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let notes = item.notes {
                        VStack(alignment: .leading, spacing: 5) {
                            SectionLabel("Notizen")
                            Text(notes)
                                .font(.system(size: 12))
                                .foregroundStyle(.primary.opacity(0.85))
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let url = item.url, url != item.meetingURL {
                        Link(destination: url) {
                            Label(url.absoluteString, systemImage: "link")
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .font(.system(size: 12))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 420)
            .fixedSize(horizontal: false, vertical: true)

            Hairline()
            HStack(spacing: 10) {
                if item.isReminder {
                    Button {
                        store.complete(item)
                    } label: {
                        Label("Erledigt", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(item.color)
                }
                Spacer()
                Button(item.isReminder ? "In „Erinnerungen“ öffnen" : "In „Kalender“ öffnen") {
                    store.open(item)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.small)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var when: String {
        let cal = store.cal
        let day = "\(Fmt.dayTitle(item.start, now: store.now)), \(Fmt.string(item.start, "d. MMMM yyyy"))"
        if item.isReminder {
            return item.isAllDay ? "fällig \(day)" : "fällig \(day), \(Fmt.time(item.start)) Uhr"
        }
        if item.isAllDay {
            let lastDay = item.end.addingTimeInterval(-1)
            if cal.isDate(item.start, inSameDayAs: lastDay) { return "\(day) · ganztägig" }
            return "\(Fmt.string(item.start, "d. MMM")) bis \(Fmt.string(lastDay, "d. MMM yyyy")) · ganztägig"
        }
        if !cal.isDate(item.start, inSameDayAs: item.end.addingTimeInterval(-1)) {
            return "\(Fmt.string(item.start, "EE d. MMM, HH:mm")) bis \(Fmt.string(item.end, "EE d. MMM, HH:mm"))"
        }
        let minutes = Int(item.end.timeIntervalSince(item.start) / 60)
        let length = minutes < 60 ? "\(minutes) Min." : minutes % 60 == 0 ? "\(minutes / 60) Std." : "\(minutes / 60) Std. \(minutes % 60) Min."
        return "\(day)\n\(Fmt.range(item)) Uhr · \(length)"
    }
}

private struct LocationBlock: View {
    let location: String
    let coordinate: CLLocationCoordinate2D?
    @State private var resolved: CLLocationCoordinate2D?
    @State private var lookedUp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                openInMaps()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                    Text(location)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.forward")
                        .foregroundStyle(.tertiary)
                }
                .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("In „Karten“ öffnen")

            if let c = coordinate ?? resolved {
                Map(initialPosition: .region(MKCoordinateRegion(center: c, latitudinalMeters: 1200, longitudinalMeters: 1200)),
                    interactionModes: []) {
                    Marker("", coordinate: c)
                }
                .frame(height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onTapGesture { openInMaps() }
                .transition(.opacity)
            }
        }
        .task(id: location) { await resolve() }
    }

    private func resolve() async {
        guard coordinate == nil, !lookedUp, !location.contains("://") else { return }
        lookedUp = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = location
        if let item = try? await MKLocalSearch(request: request).start().mapItems.first {
            withAnimation { resolved = item.coordinate }
        }
    }

    private func openInMaps() {
        var components = URLComponents(string: "maps://")!
        if let c = coordinate ?? resolved {
            components.queryItems = [URLQueryItem(name: "ll", value: "\(c.latitude),\(c.longitude)"),
                                     URLQueryItem(name: "q", value: location)]
        } else {
            components.queryItems = [URLQueryItem(name: "q", value: location)]
        }
        if let url = components.url { NSWorkspace.shared.open(url) }
    }
}

struct PanelHeader: View {
    @EnvironmentObject var store: CalendarStore
    let title: String

    var body: some View {
        HStack {
            Button {
                store.show(.none)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                    Text("Zurück")
                }
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            Spacer()
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

private extension EKParticipantStatus {
    var symbol: String {
        switch self {
        case .accepted: "checkmark.circle.fill"
        case .declined: "xmark.circle.fill"
        case .tentative: "questionmark.circle.fill"
        default: "circle.dotted"
        }
    }

    var tint: Color {
        switch self {
        case .accepted: .green
        case .declined: .red
        case .tentative: .orange
        default: .secondary
        }
    }
}

struct PlacePanel: View {
    @EnvironmentObject var store: CalendarStore
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var searching = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(title: "Ort für Sonnenzeiten")
            VStack(alignment: .leading, spacing: 10) {
                Text("Aktuell: \(store.placeName)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Ort suchen", text: $query)
                        .textFieldStyle(.plain)
                        .focused($focused)
                        .onSubmit { if let first = results.first { choose(first) } }
                    if searching { ProgressView().controlSize(.small) }
                }
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.primary.opacity(0.07)))

                VStack(spacing: 2) {
                    ForEach(results, id: \.self) { item in
                        PlaceRow(item: item) { choose(item) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .onAppear { focused = true }
        .task(id: query) {
            let q = query.trimmingCharacters(in: .whitespaces)
            guard q.count >= 2 else { results = []; return }
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            searching = true
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = q
            request.resultTypes = .address
            let found = (try? await MKLocalSearch(request: request).start().mapItems) ?? []
            searching = false
            guard !Task.isCancelled else { return }
            results = Array(found.prefix(6))
        }
    }

    private func choose(_ item: MKMapItem) {
        let c = item.coordinate
        store.setPlace(name: item.name ?? query, latitude: c.latitude, longitude: c.longitude)
    }
}

private struct PlaceRow: View {
    let item: MKMapItem
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill").foregroundStyle(Brand.gradient)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name ?? "").font(.system(size: 12.5, weight: .medium))
                    if let detail = item.shortAddress {
                        Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.primary.opacity(hover ? 0.08 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

private extension MKMapItem {
    var coordinate: CLLocationCoordinate2D {
        if #available(macOS 26, *) { return location.coordinate }
        return placemark.coordinate
    }

    var shortAddress: String? {
        if #available(macOS 26, *) { return address?.shortAddress ?? address?.fullAddress }
        let parts = [placemark.locality, placemark.administrativeArea, placemark.country].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
