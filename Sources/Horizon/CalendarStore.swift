import SwiftUI
import EventKit
import ServiceManagement

@MainActor
final class CalendarStore: ObservableObject {
    enum Access { case unknown, granted, denied }

    let ek = EKEventStore()
    let cal = Calendar.de

    @Published private(set) var access: Access = .unknown
    @Published private(set) var now = Date()
    @Published private(set) var month: Date
    @Published private(set) var selectedDay: Date
    @Published private(set) var monthDirection: Edge = .trailing
    @Published private(set) var gridDays: [Date] = []
    @Published private(set) var eventsByDay: [Date: [Agenda]] = [:]
    @Published private(set) var calendars: [EKCalendar] = []

    @Published var hiddenCalendars: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(hiddenCalendars), forKey: "hiddenCalendars")
            reload()
        }
    }

    @Published var daysAhead: Int {
        didSet {
            UserDefaults.standard.set(daysAhead, forKey: "daysAhead")
            reload()
        }
    }

    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    init() {
        let today = Calendar.de.startOfDay(for: Date())
        selectedDay = today
        month = Calendar.de.startOfMonth(today)
        hiddenCalendars = Set(UserDefaults.standard.stringArray(forKey: "hiddenCalendars") ?? [])
        let stored = UserDefaults.standard.integer(forKey: "daysAhead")
        daysAhead = stored == 0 ? 7 : stored

        refreshAccess()
        reload()

        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: .EKEventStoreChanged, object: ek, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        })
        observers.append(nc.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        })

        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }

        if access == .unknown {
            Task { await requestAccess() }
        }
    }

    // MARK: Access

    func refreshAccess() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: access = .granted
        case .notDetermined: access = .unknown
        default: access = .denied
        }
    }

    func requestAccess() async {
        _ = try? await ek.requestFullAccessToEvents()
        refreshAccess()
        reload()
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Time & navigation

    func tick() {
        let previous = now
        now = Date()
        if !cal.isDate(previous, inSameDayAs: now) {
            // Day rolled over: keep following "today" if the user was looking at it.
            if cal.isDate(selectedDay, inSameDayAs: previous) {
                selectedDay = cal.startOfDay(for: now)
                month = cal.startOfMonth(now)
            }
        }
        reload()
    }

    var isTodaySelected: Bool { cal.isDate(selectedDay, inSameDayAs: now) }

    func shiftMonth(_ delta: Int) {
        monthDirection = delta > 0 ? .trailing : .leading
        withAnimation(.snappy(duration: 0.32)) {
            month = cal.date(byAdding: .month, value: delta, to: month)!
            reload()
        }
    }

    func goToToday() {
        let today = cal.startOfDay(for: now)
        let targetMonth = cal.startOfMonth(today)
        monthDirection = targetMonth < month ? .leading : .trailing
        withAnimation(.snappy(duration: 0.32)) {
            month = targetMonth
            selectedDay = today
            reload()
        }
    }

    func select(_ day: Date) {
        let day = cal.startOfDay(for: day)
        let targetMonth = cal.startOfMonth(day)
        if targetMonth != month { monthDirection = targetMonth < month ? .leading : .trailing }
        withAnimation(.snappy(duration: 0.28)) {
            selectedDay = day
            month = targetMonth
            reload()
        }
    }

    // MARK: Data

    func reload() {
        gridDays = makeGrid(for: month)
        guard access == .granted else {
            eventsByDay = [:]
            calendars = []
            return
        }

        calendars = ek.calendars(for: .event).sorted {
            ($0.source?.title ?? "", $0.title) < ($1.source?.title ?? "", $1.title)
        }
        let visible = calendars.filter { !hiddenCalendars.contains($0.calendarIdentifier) }
        guard !visible.isEmpty, let gridStart = gridDays.first else {
            eventsByDay = [:]
            return
        }

        let today = cal.startOfDay(for: now)
        let start = min(gridStart, selectedDay, today)
        let end = max(cal.adding(days: gridDays.count, to: gridStart),
                      cal.adding(days: daysAhead + 1, to: selectedDay),
                      cal.adding(days: 2, to: today))

        let predicate = ek.predicateForEvents(withStart: start, end: end, calendars: visible)
        let events = ek.events(matching: predicate).map(Agenda.init)

        var byDay: [Date: [Agenda]] = [:]
        for e in events {
            var day = cal.startOfDay(for: e.start)
            let last = e.end > e.start ? e.end.addingTimeInterval(-1) : e.start
            var guardCount = 0
            while day <= last && guardCount < 62 {
                if day >= start && day < end { byDay[day, default: []].append(e) }
                day = cal.adding(days: 1, to: day)
                guardCount += 1
            }
        }
        for key in byDay.keys {
            byDay[key]!.sort { ($0.isAllDay ? 0 : 1, $0.start) < ($1.isAllDay ? 0 : 1, $1.start) }
        }
        eventsByDay = byDay
    }

    func events(on day: Date) -> [Agenda] {
        eventsByDay[cal.startOfDay(for: day)] ?? []
    }

    func agendaSections() -> [AgendaSection] {
        let today = cal.startOfDay(for: now)
        var seen = Set<String>()
        var sections: [AgendaSection] = []
        for offset in 0..<daysAhead {
            let day = cal.adding(days: offset, to: selectedDay)
            let items = events(on: day).filter { e in
                if day < today { return seen.insert(e.id).inserted }
                if day == today && e.end <= now { return false }
                return seen.insert(e.id).inserted
            }
            if !items.isEmpty { sections.append(AgendaSection(day: day, items: items)) }
        }
        return sections
    }

    /// The event that matters right now: the one running, or the next one within three hours.
    var focusEvent: (event: Agenda, ongoing: Bool)? {
        let today = events(on: now) + events(on: cal.adding(days: 1, to: now))
        let timed = today.filter { !$0.isAllDay }
        if let running = timed.filter({ $0.isOngoing(at: now) }).max(by: { $0.start < $1.start }) {
            return (running, true)
        }
        if let next = timed.filter({ $0.start > now }).min(by: { $0.start < $1.start }),
           next.start.timeIntervalSince(now) < 3 * 3600 {
            return (next, false)
        }
        return nil
    }

    private func makeGrid(for month: Date) -> [Date] {
        let first = cal.startOfMonth(month)
        let weekday = cal.component(.weekday, from: first)
        let lead = (weekday - cal.firstWeekday + 7) % 7
        let start = cal.adding(days: -lead, to: first)
        return (0..<42).map { cal.adding(days: $0, to: start) }
    }

    // MARK: Actions

    func add(_ draft: QuickAdd.Draft) throws {
        guard let target = ek.defaultCalendarForNewEvents else {
            throw NSError(domain: "Horizon", code: 1)
        }
        let event = EKEvent(eventStore: ek)
        event.title = draft.title
        event.startDate = draft.start
        event.endDate = draft.end
        event.isAllDay = draft.allDay
        event.calendar = target
        try ek.save(event, span: .thisEvent)
        reload()
    }

    func open(_ event: Agenda) {
        let id = event.eventID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? event.eventID
        if let url = URL(string: "ical://ekevent/\(id)?method=show&options=more") {
            NSWorkspace.shared.open(url)
        }
    }

    func openCalendarApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            if newValue { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
        }
    }
}
