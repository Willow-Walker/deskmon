import SwiftUI

/// "Open in Browser" button shown in service dashboard headers.
/// Shows the auto-detected URL or lets the user set a custom one.
struct ServiceOpenButton: View {
    let service: ServiceInfo

    @State private var showingURLEditor = false
    @State private var customURLText = ""

    private var hasURL: Bool { service.effectiveURL != nil }

    var body: some View {
        HStack(spacing: 4) {
            // Open button
            if let url = service.effectiveURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Open in browser")
            }

            // Edit URL button
            Button {
                customURLText = ServiceURLStore.customURL(for: service.pluginId)
                    ?? service.url
                    ?? ""
                showingURLEditor = true
            } label: {
                Image(systemName: hasURL ? "link" : "link.badge.plus")
                    .font(.caption)
                    .foregroundStyle(hasURL ? .tertiary : .secondary)
            }
            .buttonStyle(.plain)
            .help(hasURL ? "Edit URL" : "Set custom URL")
            .popover(isPresented: $showingURLEditor) {
                urlEditor
            }
        }
    }

    // MARK: - URL Editor Popover

    private var urlEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Service URL")
                .font(.headline)

            if let detected = service.url, !detected.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.caption2)
                    Text("Detected: \(detected)")
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
            }

            TextField("https://...", text: $customURLText)
                .textFieldStyle(.roundedBorder)
                .onSubmit { saveURL() }

            HStack {
                if ServiceURLStore.customURL(for: service.pluginId) != nil {
                    Button("Reset to detected") {
                        ServiceURLStore.setCustomURL(nil, for: service.pluginId)
                        customURLText = service.url ?? ""
                        showingURLEditor = false
                    }
                    .font(.caption)
                }

                Spacer()

                Button("Cancel") { showingURLEditor = false }
                    .buttonStyle(.plain)
                    .font(.callout)

                Button("Save") { saveURL() }
                    .buttonStyle(.borderedProminent)
                    .tint(serviceAccent(for: service.pluginId))
                    .font(.callout)
                    .disabled(customURLText.isEmpty)
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private func saveURL() {
        let trimmed = customURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == service.url {
            ServiceURLStore.setCustomURL(nil, for: service.pluginId)
        } else {
            ServiceURLStore.setCustomURL(trimmed, for: service.pluginId)
        }
        showingURLEditor = false
    }
}
