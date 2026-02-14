import SwiftUI

struct EditServerSheet: View {
    @Environment(ServerManager.self) private var serverManager
    @Environment(\.dismiss) private var dismiss

    let server: ServerInfo

    @State private var name: String
    @State private var host: String
    @State private var username: String
    @State private var password = ""

    @State private var isTesting = false
    @State private var errorMessage: String?

    init(server: ServerInfo) {
        self.server = server
        _name = State(initialValue: server.name)
        _host = State(initialValue: server.host)
        _username = State(initialValue: server.username)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !host.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasChanges: Bool {
        name != server.name ||
        host != server.host ||
        username != server.username ||
        !password.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Edit Server")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 14) {
                field("Name", text: $name, prompt: "Homelab")
                field("Host / IP", text: $host, prompt: "192.168.1.100")
                field("SSH Username", text: $username, prompt: "pi")
                secureField("New Password", text: $password, prompt: "Leave blank to keep current")
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
                    Task { await save() }
                } label: {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text("Save")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid || !hasChanges || isTesting)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(width: 380, height: 340)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }

    private func save() async {
        errorMessage = nil
        isTesting = true
        defer { isTesting = false }

        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)

        // Update password in Keychain if changed
        if !password.isEmpty {
            try? KeychainStore.savePassword(password, for: server.id)
        }

        serverManager.updateServer(
            id: server.id,
            name: name.trimmingCharacters(in: .whitespaces),
            host: trimmedHost,
            username: trimmedUsername
        )
        dismiss()
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
