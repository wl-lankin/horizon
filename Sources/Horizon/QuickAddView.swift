import SwiftUI

struct QuickAddView: View {
    @EnvironmentObject var store: CalendarStore
    @State private var text = ""
    @State private var feedback: (ok: Bool, message: String)?
    @State private var editing = false
    @FocusState private var focused: Bool

    private var draft: QuickAdd.Draft? {
        QuickAdd.parse(text, now: store.now, cal: store.cal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(focused ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(.secondary))
                // The window auto-focuses any text field it contains when it opens, so the real field
                // only exists while editing; until then a look-alike placeholder stands in.
                if editing {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($focused)
                        .onSubmit(save)
                        .onExitCommand { stopEditing() }
                        .onChange(of: text) { if !text.isEmpty { feedback = nil } }
                        .onChange(of: focused) { if !focused && text.isEmpty { editing = false } }
                } else {
                    Text(placeholder)
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.primary.opacity(focused ? 0.09 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(focused ? AnyShapeStyle(Brand.gradient.opacity(0.6)) : AnyShapeStyle(.clear), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture { startEditing() }

            if let d = draft, !text.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "calendar.badge.plus")
                    Text(preview(d))
                    Spacer()
                    Text("↩︎")
                        .foregroundStyle(.tertiary)
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if let f = feedback {
                Label(f.message, systemImage: f.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(f.ok ? .green : .orange)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.2), value: text.isEmpty)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            if text.isEmpty { stopEditing() }
        }
    }

    private let placeholder = "Neuer Termin, z. B. „Fr 14 Uhr Zahnarzt“"

    private func startEditing() {
        guard !editing else { return }
        editing = true
        DispatchQueue.main.async { focused = true }
    }

    private func stopEditing() {
        text = ""
        focused = false
        editing = false
    }

    private func preview(_ d: QuickAdd.Draft) -> String {
        let day = "\(Fmt.dayTitle(d.start, now: store.now)), \(Fmt.string(d.start, "d. MMM"))"
        let time = d.allDay ? "ganztägig" : "\(Fmt.time(d.start)) - \(Fmt.time(d.end))"
        return "\(d.title) · \(day) · \(time)"
    }

    private func save() {
        guard let d = draft else { return }
        do {
            try store.add(d)
            feedback = (true, "Eingetragen: \(d.title), \(Fmt.string(d.start, "EE d. MMM"))")
            stopEditing()
            store.select(d.start)
        } catch {
            feedback = (false, "Konnte nicht speichern. Ist ein Standardkalender gesetzt?")
        }
    }
}
