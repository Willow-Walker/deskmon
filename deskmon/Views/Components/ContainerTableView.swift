import SwiftUI

struct ContainerTableView: View {
    let containers: [DockerContainer]
    var selectedID: String? = nil
    var onSelect: ((DockerContainer) -> Void)? = nil

    @State private var hoveredID: String?

    /// Running/restarting first, stopped pushed to the bottom.
    private var sortedContainers: [DockerContainer] {
        containers.sorted { a, b in
            let aRunning = a.status != .stopped
            let bRunning = b.status != .stopped
            if aRunning != bRunning { return aRunning }
            return false // preserve original order within group
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(title: "Containers", count: containers.count)
                .padding(.horizontal, 4)

            VStack(spacing: 6) {
                ForEach(sortedContainers) { container in
                    containerRow(container)
                }
            }
        }
    }

    // MARK: - Row

    private func containerRow(_ container: DockerContainer) -> some View {
        let isSelected = container.id == selectedID
        let isHovered = hoveredID == container.id

        return HStack(spacing: 0) {
            // Left color strip
            RoundedRectangle(cornerRadius: 1.5)
                .fill(stripColor(for: container))
                .frame(width: 3, height: 32)
                .padding(.trailing, 10)

            // Name + optional image subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(container.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)

                if let subtitle = readableImage(container.image) {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            // CPU
            if container.status == .running {
                Text(String(format: "%.1f%%", container.cpuPercent))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(cpuColor(container.cpuPercent))
                    .frame(width: 52, alignment: .trailing)
                    .contentTransition(.numericText())

                // Memory
                Text(String(format: "%.0f MB", container.memoryUsageMB))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(memoryColor(container.memoryUsageMB))
                    .frame(width: 72, alignment: .trailing)
                    .contentTransition(.numericText())
            } else {
                Text("–")
                    .foregroundStyle(.quaternary)
                    .frame(width: 52, alignment: .trailing)
                Text("–")
                    .foregroundStyle(.quaternary)
                    .frame(width: 72, alignment: .trailing)
            }

            // Chevron — hover only
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 16)
                .padding(.leading, 8)
                .opacity(isHovered || isSelected ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isSelected ? Theme.accent.opacity(0.1) :
            (isHovered ? Color.white.opacity(0.04) : .clear),
            in: .rect(cornerRadius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? Theme.accent.opacity(0.25) : .clear, lineWidth: 1)
        )
        .background(Theme.cardBackground, in: .rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Theme.cardBorder, lineWidth: 1)
        )
        .opacity(container.status == .stopped ? 0.5 : 1)
        .contentShape(.rect)
        .onTapGesture { onSelect?(container) }
        .onHover { hoveredID = $0 ? container.id : nil }
    }

    // MARK: - Color Strip

    private func stripColor(for container: DockerContainer) -> Color {
        switch container.status {
        case .running:
            if container.healthStatus == .unhealthy { return Theme.critical }
            return Theme.healthy
        case .stopped:
            return .secondary.opacity(0.4)
        case .restarting:
            return Theme.warning
        }
    }

    // MARK: - Resource Colors

    private func cpuColor(_ value: Double) -> Color {
        if value > 50 { return Theme.critical }
        if value > 20 { return Theme.warning }
        if value > 5 { return Theme.cpu }
        return .secondary
    }

    private func memoryColor(_ mb: Double) -> Color {
        if mb > 1000 { return Theme.warning }
        if mb > 500 { return Theme.memory }
        return .secondary
    }

    // MARK: - Image Name

    /// Returns a readable image name, or nil for SHA hashes.
    private func readableImage(_ image: String) -> String? {
        let cleaned: String
        if let last = image.split(separator: "/").last {
            cleaned = String(last)
        } else {
            cleaned = image
        }
        // Hide SHA-prefixed images
        if cleaned.hasPrefix("sha256:") { return nil }
        return cleaned
    }
}
