import SwiftUI

struct AddServerSheet: View {
    @Environment(ServerManager.self) private var serverManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var host = ""
    @State private var port = "7654"
    @State private var token = ""

    @State private var isTesting = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !host.trimmingCharacters(in: .whitespaces).isEmpty &&
        !token.trimmingCharacters(in: .whitespaces).isEmpty
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
                    Task { await testAndAdd() }
                } label: {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text("Connect")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid || isTesting)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(width: 380, height: 320)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }

    private func testAndAdd() async {
        errorMessage = nil
        isTesting = true
        defer { isTesting = false }

        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        let portNum = Int(port) ?? 7654

        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        let result = await serverManager.testConnection(
            host: trimmedHost, port: portNum, token: trimmedToken
        )

        switch result {
        case .success:
            serverManager.addServer(
                name: name.trimmingCharacters(in: .whitespaces),
                host: trimmedHost,
                port: portNum,
                token: trimmedToken
            )
            dismiss()
        case .unreachable:
            errorMessage = "Server unreachable at \(trimmedHost):\(portNum)"
        case .unauthorized:
            errorMessage = "Invalid token — check your agent config"
        case .error(let msg):
            errorMessage = msg
        }
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
