import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var store: CalendarStore
    @FocusState private var keyFocus: Bool

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

            switch store.panel {
            case .detail(let item):
                Hairline()
                DetailView(item: item)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .place:
                Hairline()
                PlacePanel()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .none:
                main
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            Hairline()
            FooterView()
        }
        .frame(width: 330)
        .background(SkyBackground(phase: SkyPhase.at(store.now)))
        .focusable()
        .focusEffectDisabled()
        .focused($keyFocus)
        .onKeyPress(phases: .down, action: handleKey)
        .onAppear {
            store.tick()
            keyFocus = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            if store.panel == .none { keyFocus = true }
        }
    }

    @ViewBuilder
    private var main: some View {
        VStack(spacing: 0) {
            if store.access == .granted {
                NowBanner()
                Hairline()
                DayArcView()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                Hairline()
                MonthGrid()
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                Hairline()
                AgendaList()
                Hairline()
                QuickAddView()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            } else {
                Hairline()
                AccessView()
            }
        }
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        if store.panel != .none {
            guard press.key == .escape else { return .ignored }
            store.show(.none)
            keyFocus = true
            return .handled
        }
        let byMonth = press.modifiers.contains(.command) || press.modifiers.contains(.option)
        switch press.key {
        case .leftArrow: byMonth ? store.shiftSelectionMonth(-1) : store.shiftSelection(days: -1)
        case .rightArrow: byMonth ? store.shiftSelectionMonth(1) : store.shiftSelection(days: 1)
        case .upArrow: store.shiftSelection(days: -7)
        case .downArrow: store.shiftSelection(days: 7)
        case .pageUp: store.shiftSelectionMonth(-1)
        case .pageDown: store.shiftSelectionMonth(1)
        case .return:
            guard let first = store.agendaSections().first?.items.first else { return .ignored }
            store.show(.detail(first))
        default:
            guard press.modifiers.isEmpty, ["t", "h"].contains(press.characters.lowercased()) else { return .ignored }
            store.goToToday()
        }
        return .handled
    }
}

struct HeaderView: View {
    @EnvironmentObject var store: CalendarStore
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let now = store.now
        let phase = SkyPhase.at(now)
        let todayCount = store.events(on: now).count
        let week = store.cal.component(.weekOfYear, from: now)

        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: -4) {
                Text(Fmt.string(now, "EEEE"))
                    .font(.system(size: 15, weight: .semibold))
                Text(Fmt.string(now, "d."))
                    .font(.system(size: 54, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: phase.symbol)
                    .symbolRenderingMode(phase == .night && scheme == .light ? .hierarchical : .multicolor)
                    .foregroundStyle(phase == .night && scheme == .light ? Brand.night : .primary)
                    .font(.system(size: 22))
                    .padding(.bottom, 2)
                Text(Fmt.string(now, "MMMM yyyy"))
                    .font(.system(size: 13, weight: .semibold))
                Text("KW \(week) · \(todayCount == 0 ? "frei" : todayCount == 1 ? "1 Termin" : "\(todayCount) Termine")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { store.goToToday() }
        .help("Zu heute springen")
    }
}

struct AccessView: View {
    @EnvironmentObject var store: CalendarStore

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 30))
                .foregroundStyle(Brand.gradient)
            Text("Horizon braucht Zugriff auf deine Kalender")
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.center)
            Text("Die Termine bleiben auf deinem Mac. Horizon liest sie nur, um sie hier anzuzeigen.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(store.access == .unknown ? "Zugriff erlauben" : "Systemeinstellungen öffnen") {
                if store.access == .unknown {
                    Task { await store.requestAccess() }
                } else {
                    store.openPrivacySettings()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.ember)
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
    }
}

struct FooterView: View {
    @EnvironmentObject var store: CalendarStore
    @ObservedObject private var updater = Updater.shared
    @State private var hover = false

    var body: some View {
        HStack {
            Button {
                store.openCalendarApp()
            } label: {
                Text("„Kalender“ öffnen")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(hover ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .onHover { hover = $0 }
            Spacer()
            if case .ready(let version) = updater.state {
                Button {
                    updater.relaunch()
                } label: {
                    Label("\(version) bereit · Neu starten", systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Brand.gradient)
                }
                .buttonStyle(.plain)
                .help("Horizon wurde aktualisiert und startet neu")
            }
            SettingsMenu()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct SettingsMenu: View {
    @EnvironmentObject var store: CalendarStore
    @AppStorage("barStyle") private var barStyle = BarStyle.next.rawValue
    @AppStorage("showWeeks") private var showWeeks = true
    @State private var updateState: Updater.State = .idle

    private var updateLabel: String {
        switch updateState {
        case .checking: "Suche nach Updates …"
        case .upToDate: "Horizon ist aktuell (\(Updater.shared.currentVersion))"
        case .downloading(let v): "Lade Version \(v) …"
        case .ready(let v): "Version \(v) ist bereit"
        case .failed(let m): "Update fehlgeschlagen: \(m)"
        case .idle: "Nach Updates suchen …"
        }
    }

    var body: some View {
        Menu {
            Picker("Menüleiste", selection: $barStyle) {
                ForEach(BarStyle.allCases) { Text($0.label).tag($0.rawValue) }
            }
            Picker("Vorschau", selection: $store.daysAhead) {
                Text("3 Tage").tag(3)
                Text("1 Woche").tag(7)
                Text("2 Wochen").tag(14)
                Text("1 Monat").tag(31)
            }
            Menu("Kalender") {
                ForEach(store.calendars, id: \.calendarIdentifier) { c in
                    Toggle(c.title, isOn: Binding(
                        get: { !store.hiddenCalendars.contains(c.calendarIdentifier) },
                        set: { on in
                            if on { store.hiddenCalendars.remove(c.calendarIdentifier) }
                            else { store.hiddenCalendars.insert(c.calendarIdentifier) }
                        }))
                }
            }
            Toggle("Erinnerungen anzeigen", isOn: $store.showReminders)
            Toggle("Kalenderwochen", isOn: $showWeeks)
            Button("Ort für Sonnenzeiten: \(store.placeName) …") { store.show(.place) }
            Divider()
            Toggle("Kurzbefehl ⌥⌘K öffnet Horizon", isOn: $store.hotKeyEnabled)
            Toggle("Bei Anmeldung starten", isOn: Binding(
                get: { store.launchAtLogin },
                set: { store.launchAtLogin = $0 }))
            Divider()
            Button(updateLabel) { Task { await Updater.shared.check(manual: true) } }
                .disabled(!Updater.shared.isEnabled)
            Divider()
            Button("Horizon \(Updater.shared.currentVersion) beenden") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 13, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .onReceive(Updater.shared.$state) { updateState = $0 }
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Einstellungen")
    }
}
