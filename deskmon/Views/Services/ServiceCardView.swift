import SwiftUI

struct ServiceCardView: View {
    let service: ServiceInfo
    let isHovered: Bool

    private var accentColor: Color {
        serviceAccent(for: service.pluginId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Accent strip
            accentColor
                .frame(height: 3)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                // Header: icon + name + status
                HStack(spacing: 8) {
                    Image(systemName: service.icon)
                        .font(.title3)
                        .foregroundStyle(accentColor)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(service.name)
                            .font(.callout.weight(.semibold))
                        Text(service.status.capitalized)
                            .font(.caption2)
                            .foregroundStyle(service.isRunning ? Theme.healthy : Theme.critical)
                    }

                    Spacer()

                    Circle()
                        .fill(service.isRunning ? Theme.healthy : Theme.critical)
                        .frame(width: 8, height: 8)
                }

                // Summary stats
                if !service.summary.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(service.summary) { item in
                            HStack {
                                Text(item.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(item.value)
                                    .font(.caption.monospacedDigit().weight(.medium))
                                    .foregroundStyle(item.type == "percent" ? accentColor : .primary)
                            }
                        }
                    }
                }

                if let error = service.error, !error.isEmpty {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(Theme.critical)
                        .lineLimit(2)
                }
            }
            .padding(12)
        }
        .background(
            isHovered ? Color.white.opacity(0.06) : Theme.cardBackground,
            in: .rect(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isHovered ? accentColor.opacity(0.3) : Theme.cardBorder,
                    lineWidth: 1
                )
        )
        .clipShape(.rect(cornerRadius: 12))
    }
}

// MARK: - Service Accent Colors

func serviceAccent(for pluginId: String) -> Color {
    switch pluginId {
    case "pihole":
        return Color(red: 0.059, green: 0.620, blue: 0.525) // Pi-hole teal
    case "traefik":
        return Color(red: 0.141, green: 0.478, blue: 0.855) // Traefik blue
    case "nginx":
        return Color(red: 0.012, green: 0.663, blue: 0.286) // Nginx green
    default:
        return Theme.accent
    }
}
