import SwiftUI
import ServiceManagement

@main
struct HorizonApp: App {
    @StateObject private var store = CalendarStore()

    init() {
        if CommandLine.arguments.contains("--launch-at-login") {
            try? SMAppService.mainApp.register()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
