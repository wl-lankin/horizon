import SwiftUI

/// The selected day as a horizon: the sun's path above, the day's events laid out below it.
struct DayArcView: View {
    @EnvironmentObject var store: CalendarStore

    private let arcHeight: CGFloat = 30
    private let laneHeight: CGFloat = 18
    private let labelHeight: CGFloat = 12

    var body: some View {
        let day = store.selectedDay
        let all = store.events(on: day)
        let timed = all.filter { !$0.isAllDay }
        let allDay = all.filter(\.isAllDay)
        let sun = Sun.times(for: day)
        let span = hourSpan(day: day, timed: timed, sun: sun)
        let lanes = assignLanes(timed)
        let laneCount = max(1, (lanes.values.max() ?? 0) + 1)
        let isToday = store.isTodaySelected

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(caption(day))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                if !isToday {
                    Button("Heute") { store.goToToday() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Brand.ember)
                }
                Spacer()
                if let sun {
                    HStack(spacing: 8) {
                        Label(Fmt.time(sun.rise), systemImage: "sunrise.fill")
                        Label(Fmt.time(sun.set), systemImage: "sunset.fill")
                    }
                    .labelStyle(CompactLabel())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
            }

            if !allDay.isEmpty {
                HStack(spacing: 5) {
                    ForEach(allDay.prefix(3)) { e in
                        Text(e.title)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(e.color.opacity(0.25)))
                            .overlay(Capsule().strokeBorder(e.color.opacity(0.5), lineWidth: 0.5))
                            .onTapGesture { store.open(e) }
                    }
                    if allDay.count > 3 {
                        Text("+\(allDay.count - 3)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            GeometryReader { geo in
                let w = geo.size.width
                let x: (Date) -> CGFloat = { date in
                    let f = date.timeIntervalSince(span.start) / span.end.timeIntervalSince(span.start)
                    return CGFloat(min(1, max(0, f))) * w
                }
                let baseline = arcHeight
                let lanesTop = baseline + 6
                let labelsTop = lanesTop + CGFloat(laneCount) * laneHeight + 4

                ZStack(alignment: .topLeading) {
                    if let sun {
                        SunArc(riseX: x(sun.rise), setX: x(sun.set), baseline: baseline, height: arcHeight - 4)
                            .fill(LinearGradient(colors: [Brand.sun.opacity(0.18), .clear],
                                                 startPoint: .top, endPoint: .bottom))
                        SunArc(riseX: x(sun.rise), setX: x(sun.set), baseline: baseline, height: arcHeight - 4, closed: false)
                            .stroke(.primary.opacity(0.25), style: StrokeStyle(lineWidth: 1.2, dash: [2, 3]))
                        if isToday {
                            SunArc(riseX: x(sun.rise), setX: x(sun.set), baseline: baseline, height: arcHeight - 4,
                                   closed: false, until: x(store.now))
                                .stroke(LinearGradient(colors: [Brand.ember, Brand.sun], startPoint: .leading, endPoint: .trailing),
                                        style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        }
                    }

                    Rectangle()
                        .fill(.primary.opacity(0.2))
                        .frame(width: w, height: 1)
                        .offset(y: baseline)

                    if timed.isEmpty {
                        Text(allDay.isEmpty ? "Nichts geplant" : "Keine Termine mit Uhrzeit")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .frame(width: w, height: laneHeight)
                            .offset(y: lanesTop)
                    }

                    ForEach(timed) { e in
                        let x0 = x(e.start), x1 = x(e.end)
                        let width = max(5, x1 - x0 - 1.5)
                        let past = isToday && e.end <= store.now
                        EventCapsule(event: e, width: width, height: laneHeight - 3)
                            .opacity(past ? 0.4 : 1)
                            .offset(x: x0, y: lanesTop + CGFloat(lanes[e.id] ?? 0) * laneHeight)
                            .onTapGesture { store.open(e) }
                    }

                    ForEach(hourMarks(span), id: \.self) { mark in
                        let px = x(mark)
                        Text(Fmt.string(mark, "HH"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                            .fixedSize()
                            .frame(width: 24)
                            .offset(x: min(max(px - 12, -6), w - 18), y: labelsTop)
                    }

                    if isToday, store.now > span.start, store.now < span.end {
                        nowMarker(x: x(store.now), sun: sun, baseline: baseline,
                                  bottom: lanesTop + CGFloat(laneCount) * laneHeight)
                    }
                }
            }
            .frame(height: arcHeight + 6 + CGFloat(laneCount) * laneHeight + 4 + labelHeight)
        }
        .animation(.snappy(duration: 0.3), value: store.selectedDay)
    }

    @ViewBuilder
    private func nowMarker(x: CGFloat, sun: Sun.Times?, baseline: CGFloat, bottom: CGFloat) -> some View {
        let isDay = sun.map { store.now > $0.rise && store.now < $0.set } ?? true
        let y: CGFloat = {
            guard let sun, isDay else { return baseline }
            let span = sun.set.timeIntervalSince(sun.rise)
            let f = store.now.timeIntervalSince(sun.rise) / span
            return baseline - CGFloat(sin(.pi * f)) * (arcHeight - 4)
        }()

        Rectangle()
            .fill(Brand.ember.opacity(0.7))
            .frame(width: 1.5, height: bottom - baseline)
            .offset(x: x - 0.75, y: baseline)

        if isDay {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFFF1B8), Brand.sun], center: .center, startRadius: 0, endRadius: 6))
                .frame(width: 11, height: 11)
                .shadow(color: Brand.sun.opacity(0.9), radius: 6)
                .offset(x: x - 5.5, y: y - 5.5)
        } else {
            Image(systemName: "moon.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color(hex: 0xC9D3FF))
                .shadow(color: Color(hex: 0x9FB0FF).opacity(0.8), radius: 4)
                .offset(x: x - 5, y: baseline - 15)
        }
    }

    private func caption(_ day: Date) -> String {
        let title = Fmt.dayTitle(day, now: store.now)
        return "\(title), \(Fmt.string(day, "d. MMMM"))"
    }

    private func hourSpan(day: Date, timed: [Agenda], sun: Sun.Times?) -> (start: Date, end: Date) {
        let cal = store.cal
        var startH = 7, endH = 21
        let dayStart = cal.startOfDay(for: day)
        let dayEnd = cal.adding(days: 1, to: dayStart)
        func hour(_ d: Date) -> Double { d.timeIntervalSince(dayStart) / 3600 }
        for e in timed {
            startH = min(startH, Int(floor(max(0, hour(e.start)))))
            endH = max(endH, Int(ceil(min(24, hour(e.end)))))
        }
        if let sun {
            startH = min(startH, Int(floor(hour(sun.rise))))
            endH = max(endH, Int(ceil(hour(sun.set))))
        }
        if store.isTodaySelected {
            let h = hour(store.now)
            startH = min(startH, Int(floor(h)))
            endH = max(endH, Int(ceil(h + 0.01)) + 1)
        }
        startH = max(0, startH); endH = min(24, max(endH, startH + 1))
        return (dayStart.addingTimeInterval(Double(startH) * 3600),
                min(dayEnd, dayStart.addingTimeInterval(Double(endH) * 3600)))
    }

    private func hourMarks(_ span: (start: Date, end: Date)) -> [Date] {
        let hours = Int(span.end.timeIntervalSince(span.start) / 3600)
        let step = hours <= 12 ? 2 : 3
        let startHour = store.cal.component(.hour, from: span.start)
        let first = Int(ceil(Double(startHour) / Double(step))) * step
        return stride(from: first, through: startHour + hours, by: step).map {
            store.cal.startOfDay(for: span.start).addingTimeInterval(Double($0) * 3600)
        }
    }

    private func assignLanes(_ events: [Agenda]) -> [String: Int] {
        var laneEnds: [Date] = []
        var result: [String: Int] = [:]
        for e in events.sorted(by: { $0.start < $1.start }) {
            if let i = laneEnds.firstIndex(where: { $0 <= e.start }) {
                laneEnds[i] = e.end
                result[e.id] = i
            } else if laneEnds.count < 3 {
                laneEnds.append(e.end)
                result[e.id] = laneEnds.count - 1
            } else {
                result[e.id] = 2
            }
        }
        return result
    }
}

struct SunArc: Shape {
    var riseX: CGFloat
    var setX: CGFloat
    var baseline: CGFloat
    var height: CGFloat
    var closed = true
    var until: CGFloat? = nil

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let width = setX - riseX
        guard width > 1 else { return p }
        let endX = min(setX, until ?? setX)
        guard endX > riseX else { return p }
        p.move(to: CGPoint(x: riseX, y: baseline))
        var x = riseX
        while x < endX {
            x = min(endX, x + 2)
            let f = (x - riseX) / width
            p.addLine(to: CGPoint(x: x, y: baseline - sin(.pi * f) * height))
        }
        if closed { p.addLine(to: CGPoint(x: endX, y: baseline)); p.closeSubpath() }
        return p
    }
}

struct EventCapsule: View {
    let event: Agenda
    let width: CGFloat
    let height: CGFloat
    @State private var hover = false

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(event.color.gradient.opacity(hover ? 1 : 0.85))
            .overlay(alignment: .leading) {
                if width > 34 {
                    Text(event.title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 5)
                }
            }
            .frame(width: width, height: height)
            .scaleEffect(hover ? 1.04 : 1)
            .animation(.snappy(duration: 0.15), value: hover)
            .onHover { hover = $0 }
            .help("\(event.title)\n\(Fmt.range(event))\(event.location.map { "\n\($0)" } ?? "")")
    }
}

struct CompactLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.symbolRenderingMode(.multicolor)
            configuration.title
        }
    }
}
