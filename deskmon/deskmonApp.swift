import SwiftUI

@main
struct deskmonApp: App {
    @State private var serverManager = ServerManager()
    @State private var lockManager = AppLockManager()

    var body: some Scene {
        MenuBarExtra {
            DashboardView()
                .environment(serverManager)
                .environment(lockManager)
        } label: {
            MenuBarLabel(status: serverManager.currentStatus)
        }
        .menuBarExtraStyle(.window)

        Window("Deskmon", id: "main-dashboard") {
            MainDashboardView()
                .environment(serverManager)
                .environment(lockManager)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 640)

        Settings {
            SettingsView()
                .environment(serverManager)
                .environment(lockManager)
        }
    }
}
