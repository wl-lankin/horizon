import AppKit
import Carbon.HIToolbox

/// System-wide shortcut via Carbon, which needs no accessibility permission.
final class GlobalHotKey {
    static let shared = GlobalHotKey()

    var action: (() -> Void)?
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    func register(keyCode: UInt32 = UInt32(kVK_ANSI_K), modifiers: UInt32 = UInt32(cmdKey | optionKey)) {
        unregister()
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { GlobalHotKey.shared.action?() }
            return noErr
        }, 1, &spec, nil, &handler)
        let id = EventHotKeyID(signature: OSType(0x48_52_5A_4E), id: 1)
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKey)
    }

    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil
        handler = nil
    }
}

enum StatusItem {
    /// MenuBarExtra has no API to open its window, so click its status bar button instead.
    static func toggle() {
        for window in NSApp.windows where window.className.contains("StatusBarWindow") {
            if let button = findButton(in: window.contentView) {
                NSApp.activate()
                button.performClick(nil)
                return
            }
        }
    }

    private static func findButton(in view: NSView?) -> NSButton? {
        guard let view else { return nil }
        if let button = view as? NSButton { return button }
        for sub in view.subviews {
            if let found = findButton(in: sub) { return found }
        }
        return nil
    }
}
