import SwiftUI

struct EditServerSheet: View {
    @Environment(ServerManager.self) private var serverManager
    @Environment(\.dismiss) private var dismiss

    let server: ServerInfo

    @State private var name: String
    @State private var host: String
    @State private var port: String
    @State private var token: String

    @State private var isTesting = false
    @State private var errorMessage: String?

    init(server: ServerInfo) {
        self.server = server
        _name = State(initialValue: server.name)
        _host = State(initialValue: server.host)
        _port = State(initialValue: String(server.port))
        _token = State(initialValue: server.token)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !host.trimmingCharacters(in: .whitespaces).isEmpty &&
        !token.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasChanges: Bool {
        name != server.name ||
        host != server.host ||
        port != String(server.port) ||
        token != server.token
    }

    /// Only re-verify if connection details changed (host, port, or token).
    private var needsReVerify: Bool {
        host != server.host ||
        port != String(server.port) ||
        token != server.token
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

                HStack(spacing: 12) {
                    field("Port", text: $port, prompt: "7654")
                        .frame(width: 100)
                    secureField("Token", text: $token, prompt: "Agent token")
                }
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
                    Task { await testAndSave() }
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
        .frame(width: 380, height: 320)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }

    private func testAndSave() async {
        errorMessage = nil

        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        let portNum = Int(port) ?? 7654

        // Only re-verify connection if host/port/token changed
        if needsReVerify {
            isTesting = true
            defer { isTesting = false }

            let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

            let result = await serverManager.testConnection(
                host: trimmedHost, port: portNum, token: trimmedToken
            )

            switch result {
            case .success:
                break
            case .unreachable:
                errorMessage = "Server unreachable at \(trimmedHost):\(portNum)"
                return
            case .unauthorized:
                errorMessage = "Invalid token — check your agent config"
                return
            case .error(let msg):
                errorMessage = msg
                return
            }
        }

        serverManager.updateServer(
            id: server.id,
            name: name.trimmingCharacters(in: .whitespaces),
            host: trimmedHost,
            port: portNum,
            token: token.trimmingCharacters(in: .whitespacesAndNewlines)
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
