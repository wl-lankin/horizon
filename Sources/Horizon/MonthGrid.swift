import SwiftUI

struct MonthGrid: View {
    @EnvironmentObject var store: CalendarStore
    @AppStorage("showWeeks") private var showWeeks = true
    @State private var gridFrame: CGRect = .zero
    @State private var scrollMonitor: Any?
    @State private var scrollAccumulator: CGFloat = 0

    private let weekColumn: CGFloat = 26

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                Text(Fmt.string(store.month, "MMMM"))
                    .font(.system(size: 15, weight: .semibold))
                Text(Fmt.string(store.month, "yyyy"))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 3)
                Spacer()
                NavButton(symbol: "chevron.left", help: "Vorheriger Monat") { store.shiftMonth(-1) }
                NavButton(symbol: "smallcircle.filled.circle", help: "Heute") { store.goToToday() }
                NavButton(symbol: "chevron.right", help: "Nächster Monat") { store.shiftMonth(1) }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)

            HStack(spacing: 0) {
                if showWeeks { Color.clear.frame(width: weekColumn, height: 1) }
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                    Text(s)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            ZStack {
                grid
                    .id(store.month)
                    .transition(.push(from: store.monthDirection))
            }
            .clipped()
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { gridFrame = $0 }
        }
        .onAppear(perform: installScrollMonitor)
        .onDisappear {
            if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
            scrollMonitor = nil
        }
    }

    /// Scrolling over the grid flips months. A local monitor avoids an NSView overlay that would eat the clicks.
    private func installScrollMonitor() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard let content = event.window?.contentView else { return event }
            let p = event.locationInWindow
            let point = CGPoint(x: p.x, y: content.bounds.height - p.y)
            guard gridFrame.contains(point) else { return event }
            if event.momentumPhase != [] { return nil }
            if !event.hasPreciseScrollingDeltas {
                if event.scrollingDeltaY != 0 { store.shiftMonth(event.scrollingDeltaY < 0 ? 1 : -1) }
                return nil
            }
            if event.phase == .began { scrollAccumulator = 0 }
            scrollAccumulator += event.scrollingDeltaY
            if abs(scrollAccumulator) > 40 {
                store.shiftMonth(scrollAccumulator < 0 ? 1 : -1)
                scrollAccumulator = 0
            }
            return nil
        }
    }

    private var grid: some View {
        let days = store.gridDays
        return VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: 0) {
                    if showWeeks, days.count == 42 {
                        Text("\(store.cal.component(.weekOfYear, from: days[row * 7]))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                            .frame(width: weekColumn)
                    }
                    ForEach(0..<7, id: \.self) { col in
                        let i = row * 7 + col
                        if i < days.count { cell(days[i]) }
                    }
                }
            }
        }
    }

    private func cell(_ day: Date) -> some View {
        let cal = store.cal
        let events = store.events(on: day)
        var colors: [Color] = []
        for e in events where !colors.contains(e.color) && colors.count < 3 { colors.append(e.color) }
        let weekday = cal.component(.weekday, from: day)
        let tooltip = events.prefix(6).map { "\($0.isAllDay ? "ganztägig" : Fmt.time($0.start))  \($0.title)" }
            .joined(separator: "\n")

        return DayCell(
            number: cal.component(.day, from: day),
            inMonth: cal.isDate(day, equalTo: store.month, toGranularity: .month),
            isToday: cal.isDate(day, inSameDayAs: store.now),
            isSelected: cal.isDate(day, inSameDayAs: store.selectedDay),
            isPast: day < cal.startOfDay(for: store.now),
            isWeekend: weekday == 1 || weekday == 7,
            dots: colors,
            tooltip: tooltip.isEmpty ? Fmt.string(day, "EEEE, d. MMMM") : tooltip
        ) {
            store.select(day)
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = store.cal.shortStandaloneWeekdaySymbols.map { String($0.prefix(2)) }
        let first = store.cal.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }
}

struct DayCell: View {
    let number: Int
    let inMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let isPast: Bool
    let isWeekend: Bool
    let dots: [Color]
    let tooltip: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if isToday {
                    Circle()
                        .fill(Brand.gradient)
                        .shadow(color: Brand.ember.opacity(0.45), radius: 5, y: 1)
                } else if isSelected {
                    Circle().strokeBorder(.primary.opacity(0.55), lineWidth: 1.5)
                } else if hover {
                    Circle().fill(.primary.opacity(0.09))
                }
                Text("\(number)")
                    .font(.system(size: 13, weight: isToday ? .bold : .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(textStyle)
            }
            .frame(width: 27, height: 27)
            .overlay {
                if isToday && isSelected {
                    Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1).padding(2)
                }
            }

            HStack(spacing: 2.5) {
                ForEach(Array(dots.enumerated()), id: \.offset) { _, c in
                    Circle().fill(c).frame(width: 4, height: 4)
                }
            }
            .frame(height: 4)
            .opacity(inMonth ? (isPast ? 0.5 : 1) : 0.35)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture(perform: action)
        .help(tooltip)
    }

    private var textStyle: AnyShapeStyle {
        if isToday { return AnyShapeStyle(.white) }
        if !inMonth { return AnyShapeStyle(.quaternary) }
        if isPast { return AnyShapeStyle(.tertiary) }
        if isWeekend { return AnyShapeStyle(.secondary) }
        return AnyShapeStyle(.primary)
    }
}

struct NavButton: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(hover ? .primary : .secondary)
                .frame(width: 24, height: 22)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.primary.opacity(hover ? 0.08 : 0)))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(help)
    }
}
