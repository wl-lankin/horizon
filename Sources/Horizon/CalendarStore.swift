import SwiftUI
import EventKit
import ServiceManagement

@MainActor
final class CalendarStore: ObservableObject {
    enum Access { case unknown, granted, denied }

    enum Panel: Equatable {
        case none
        case detail(Agenda)
        case place
    }

    let ek = EKEventStore()
    let cal = Calendar.de

    @Published private(set) var access: Access = .unknown
    @Published private(set) var reminderAccess: Access = .unknown
    @Published private(set) var now = Date()
    @Published private(set) var month: Date
    @Published private(set) var selectedDay: Date
    @Published private(set) var monthDirection: Edge = .trailing
    @Published private(set) var gridDays: [Date] = []
    @Published private(set) var eventsByDay: [Date: [Agenda]] = [:]
    @Published private(set) var remindersByDay: [Date: [Agenda]] = [:]
    @Published private(set) var overdueReminders: [Agenda] = []
    @Published private(set) var calendars: [EKCalendar] = []
    @Published private(set) var placeName = Sun.placeName
    @Published var panel: Panel = .none

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

    @Published var showReminders: Bool {
        didSet {
            UserDefaults.standard.set(showReminders, forKey: "showReminders")
            if showReminders && reminderAccess == .unknown {
                Task { await requestReminderAccess() }
            }
            reload()
        }
    }

    @Published var hotKeyEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hotKeyEnabled, forKey: "hotKeyEnabled")
            applyHotKey()
        }
    }

    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var reminderFetch: Any?

    init() {
        let today = Calendar.de.startOfDay(for: Date())
        selectedDay = today
        month = Calendar.de.startOfMonth(today)
        hiddenCalendars = Set(UserDefaults.standard.stringArray(forKey: "hiddenCalendars") ?? [])
        let stored = UserDefaults.standard.integer(forKey: "daysAhead")
        daysAhead = stored == 0 ? 7 : stored
        showReminders = UserDefaults.standard.object(forKey: "showReminders") as? Bool ?? true
        hotKeyEnabled = UserDefaults.standard.object(forKey: "hotKeyEnabled") as? Bool ?? true
        applyHotKey()

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

        Task {
            if access == .unknown { await requestAccess() }
            if showReminders && reminderAccess == .unknown { await requestReminderAccess() }
        }
    }

    private func applyHotKey() {
        if hotKeyEnabled {
            GlobalHotKey.shared.action = { StatusItem.toggle() }
            GlobalHotKey.shared.register()
        } else {
            GlobalHotKey.shared.unregister()
        }
    }

    // MARK: Access

    private static func access(for type: EKEntityType) -> Access {
        switch EKEventStore.authorizationStatus(for: type) {
        case .fullAccess: .granted
        case .notDetermined: .unknown
        default: .denied
        }
    }

    func refreshAccess() {
        access = Self.access(for: .event)
        reminderAccess = Self.access(for: .reminder)
    }

    func requestAccess() async {
        _ = try? await ek.requestFullAccessToEvents()
        refreshAccess()
        reload()
    }

    func requestReminderAccess() async {
        _ = try? await ek.requestFullAccessToReminders()
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

    /// Moves the selection by whole months, keeping the day of month where possible.
    func shiftSelectionMonth(_ delta: Int) {
        select(cal.date(byAdding: .month, value: delta, to: selectedDay)!)
    }

    func shiftSelection(days: Int) {
        select(cal.adding(days: days, to: selectedDay))
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

    func show(_ panel: Panel) {
        withAnimation(.snappy(duration: 0.28)) { self.panel = panel }
    }

    // MARK: Data

    func reload() {
        gridDays = makeGrid(for: month)
        placeName = Sun.placeName
        guard access == .granted else {
            eventsByDay = [:]
            calendars = []
            reloadReminders(start: nil, end: nil)
            return
        }

        calendars = ek.calendars(for: .event).sorted {
            ($0.source?.title ?? "", $0.title) < ($1.source?.title ?? "", $1.title)
        }
        let visible = calendars.filter { !hiddenCalendars.contains($0.calendarIdentifier) }
        let (start, end) = loadedRange()

        guard !visible.isEmpty else {
            eventsByDay = [:]
            reloadReminders(start: start, end: end)
            return
        }

        let predicate = ek.predicateForEvents(withStart: start, end: end, calendars: visible)
        eventsByDay = group(ek.events(matching: predicate).map(Agenda.init), start: start, end: end)
        reloadReminders(start: start, end: end)
    }

    private func loadedRange() -> (Date, Date) {
        let gridStart = gridDays.first ?? selectedDay
        let today = cal.startOfDay(for: now)
        let start = min(gridStart, selectedDay, today)
        let end = max(cal.adding(days: gridDays.count, to: gridStart),
                      cal.adding(days: daysAhead + 1, to: selectedDay),
                      cal.adding(days: 2, to: today))
        return (start, end)
    }

    private func reloadReminders(start: Date?, end: Date?) {
        guard showReminders, reminderAccess == .granted else {
            remindersByDay = [:]
            overdueReminders = []
            return
        }
        let range = loadedRange()
        let start = start ?? range.0, end = end ?? range.1
        let lists = ek.calendars(for: .reminder).filter { !hiddenCalendars.contains($0.calendarIdentifier) }
        guard !lists.isEmpty else {
            remindersByDay = [:]
            overdueReminders = []
            return
        }
        // Overdue reminders can be arbitrarily old, so the query starts a year back.
        let predicate = ek.predicateForIncompleteReminders(
            withDueDateStarting: cal.date(byAdding: .year, value: -1, to: start), ending: end, calendars: lists)
        if let pending = reminderFetch { ek.cancelFetchRequest(pending) }
        reminderFetch = ek.fetchReminders(matching: predicate) { [weak self] reminders in
            let items: [Agenda] = (reminders ?? []).compactMap { r in
                guard let comps = r.dueDateComponents, let due = Calendar.de.date(from: comps) else { return nil }
                return Agenda(reminder: r, due: due, hasTime: comps.hour != nil)
            }
            Task { @MainActor in
                guard let self else { return }
                self.reminderFetch = nil
                let today = self.cal.startOfDay(for: self.now)
                self.overdueReminders = items.filter { $0.isOverdue(at: self.now) && $0.start < today }
                    .sorted { $0.start < $1.start }
                self.remindersByDay = self.group(items.filter { $0.start >= start }, start: start, end: end)
            }
        }
    }

    private func group(_ items: [Agenda], start: Date, end: Date) -> [Date: [Agenda]] {
        var byDay: [Date: [Agenda]] = [:]
        for e in items {
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
        return byDay
    }

    func events(on day: Date) -> [Agenda] {
        eventsByDay[cal.startOfDay(for: day)] ?? []
    }

    func reminders(on day: Date) -> [Agenda] {
        remindersByDay[cal.startOfDay(for: day)] ?? []
    }

    func agendaSections() -> [AgendaSection] {
        let today = cal.startOfDay(for: now)
        var seen = Set<String>()
        var sections: [AgendaSection] = []
        for offset in 0..<daysAhead {
            let day = cal.adding(days: offset, to: selectedDay)
            let events = events(on: day).filter { e in
                if day == today && e.end <= now { return false }
                return seen.insert(e.id).inserted
            }
            var reminders = reminders(on: day)
            if day == today { reminders = overdueReminders + reminders }
            let items = (reminders + events).sorted {
                ($0.isAllDay ? 0 : 1, $0.start) < ($1.isAllDay ? 0 : 1, $1.start)
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

    var writableCalendars: [EKCalendar] {
        calendars.filter(\.allowsContentModifications)
    }

    func calendar(matching hint: String?) -> EKCalendar? {
        guard let hint = hint?.lowercased(), !hint.isEmpty else { return nil }
        let candidates = writableCalendars
        return candidates.first { $0.title.lowercased() == hint }
            ?? candidates.first { $0.title.lowercased().hasPrefix(hint) }
            ?? candidates.first { $0.title.lowercased().contains(hint) }
    }

    func add(_ draft: QuickAdd.Draft) throws {
        guard let target = calendar(matching: draft.calendarHint) ?? ek.defaultCalendarForNewEvents else {
            throw NSError(domain: "Horizon", code: 1)
        }
        let event = EKEvent(eventStore: ek)
        event.title = draft.title
        event.startDate = draft.start
        event.endDate = draft.end
        event.isAllDay = draft.allDay
        event.location = draft.location
        event.calendar = target
        if let r = draft.recurrence {
            let frequency: EKRecurrenceFrequency = switch r {
            case .daily: .daily
            case .weekly: .weekly
            case .monthly: .monthly
            case .yearly: .yearly
            }
            event.recurrenceRules = [EKRecurrenceRule(recurrenceWith: frequency, interval: 1, end: nil)]
        }
        try ek.save(event, span: .futureEvents)
        reload()
    }

    func complete(_ reminder: Agenda) {
        guard let r = ek.calendarItem(withIdentifier: reminder.eventID) as? EKReminder else { return }
        r.isCompleted = true
        try? ek.save(r, commit: true)
        if panel == .detail(reminder) { show(.none) }
        reload()
    }

    func open(_ item: Agenda) {
        if item.isReminder {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.reminders") {
                NSWorkspace.shared.openApplication(at: url, configuration: .init())
            }
            return
        }
        let id = item.eventID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? item.eventID
        // Recurring events need the occurrence date in the URL, otherwise Calendar shows the first one.
        let path: String
        if item.isRecurring {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            f.timeZone = item.isAllDay ? .current : TimeZone(identifier: "UTC")
            path = "\(f.string(from: item.start))/\(id)"
        } else {
            path = id
        }
        if let url = URL(string: "ical://ekevent/\(path)?method=show&options=more") {
            NSWorkspace.shared.open(url)
        }
    }

    func openCalendarApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }

    func setPlace(name: String, latitude: Double, longitude: Double) {
        Sun.setPlace(name: name, latitude: latitude, longitude: longitude)
        placeName = name
        show(.none)
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            if newValue { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
        }
    }
}
