import SwiftUI

struct FooterView: View {
    @Environment(ServerManager.self) private var serverManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 6) {
            Button {
                openWindow(id: "main-dashboard")
            } label: {
                Label("Dashboard", systemImage: "macwindow")
            }
            .buttonStyle(.darkProminent)

            Spacer()

            Button {
                serverManager.stopStreaming()
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.dark)
        }
    }
}
