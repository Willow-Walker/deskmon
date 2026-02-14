import SwiftUI

struct AddServerSheet: View {
    @Environment(ServerManager.self) private var serverManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var host = ""
    @State private var username = ""
    @State private var password = ""

    @State private var isConnecting = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !host.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Add Server")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 14) {
                field("Name", text: $name, prompt: "Homelab")
                field("Host / IP", text: $host, prompt: "192.168.1.100")
                field("SSH Username", text: $username, prompt: "pi")
                secureField("SSH Password", text: $password, prompt: "Password")
            }

            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.critical)
                    Text(errorMessage)
                        .foregroundStyle(Theme.critical)
                }
                .font(.caption)
            }

            Spacer()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    Task { await connectAndAdd() }
                } label: {
                    if isConnecting {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text("Connect")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid || isConnecting)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(width: 380)
        .frame(minHeight: 340)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }

    private func connectAndAdd() async {
        errorMessage = nil
        isConnecting = true
        defer { isConnecting = false }

        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        // Create server first, then attempt SSH connection
        let server = serverManager.addServer(
            name: trimmedName,
            host: trimmedHost,
            username: trimmedUsername
        )

        do {
            try await serverManager.connectServer(server, password: password)
            dismiss()
        } catch {
            // Remove the server if connection failed
            serverManager.deleteServer(server)
            errorMessage = Self.friendlyError(error)
        }
    }

    private static func friendlyError(_ error: Error) -> String {
        let msg = error.localizedDescription
        if msg.contains("IOError") && msg.contains("error 61") {
            return "Connection refused — check host and SSH port"
        }
        if msg.contains("IOError") && msg.contains("error 1") {
            return "Connection not permitted — check network permissions"
        }
        if msg.lowercased().contains("authentication") || msg.lowercased().contains("password") {
            return "Authentication failed — check username and password"
        }
        if msg.contains("IOError") && msg.contains("error 60") {
            return "Connection timed out — host may be unreachable"
        }
        return msg
    }

    private func field(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(.quaternary))
                .textFieldStyle(.roundedBorder)
        }
    }

    private func secureField(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            SecureField("", text: text, prompt: Text(prompt).foregroundStyle(.quaternary))
                .textFieldStyle(.roundedBorder)
        }
    }
}
