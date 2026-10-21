import SwiftUI

struct NowBanner: View {
    @EnvironmentObject var store: CalendarStore

    var body: some View {
        if let focus = store.focusEvent {
            let e = focus.event
            VStack(spacing: 0) {
                Hairline()
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(e.color.opacity(0.22))
                        Image(systemName: focus.ongoing ? "waveform" : "clock.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(e.color)
                            .symbolEffect(.variableColor.iterative, isActive: focus.ongoing)
                    }
                    .frame(width: 30, height: 30)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(focus.ongoing
                             ? "Läuft gerade · noch \(Fmt.remaining(until: e.end, from: store.now))"
                             : "Beginnt \(Fmt.countdown(to: e.start, from: store.now)) · \(Fmt.time(e.start))")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(e.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        if focus.ongoing {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(.primary.opacity(0.1))
                                    Capsule().fill(e.color)
                                        .frame(width: max(4, geo.size.width * e.progress(at: store.now)))
                                }
                            }
                            .frame(height: 4)
                            .padding(.top, 2)
                        }
                    }
                    Spacer(minLength: 4)
                    if let url = e.meetingURL {
                        JoinButton(url: url, color: e.color)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                .onTapGesture { store.show(.detail(e)) }
            }
        }
    }
}

struct JoinButton: View {
    let url: URL
    let color: Color
    @State private var hover = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            Label("Beitreten", systemImage: "video.fill")
                .font(.system(size: 11.5, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(color.opacity(hover ? 1 : 0.85)))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(url.absoluteString)
    }
}
