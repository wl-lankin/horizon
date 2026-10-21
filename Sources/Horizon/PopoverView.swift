import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var store: CalendarStore

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

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

            Hairline()
            FooterView()
        }
        .frame(width: 330)
        .background(SkyBackground(phase: SkyPhase.at(store.now)))
        .onAppear { store.tick() }
    }
}

struct HeaderView: View {
    @EnvironmentObject var store: CalendarStore

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
                    .symbolRenderingMode(.multicolor)
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
            Toggle("Kalenderwochen", isOn: $showWeeks)
            Toggle("Bei Anmeldung starten", isOn: Binding(
                get: { store.launchAtLogin },
                set: { store.launchAtLogin = $0 }))
            Divider()
            Button("Horizon beenden") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 13, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Einstellungen")
    }
}
