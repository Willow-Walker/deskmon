import SwiftUI

struct GenericServiceDashboardView: View {
    let service: ServiceInfo

    private var accent: Color { serviceAccent(for: service.pluginId) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: service.icon)
                        .font(.title2)
                        .foregroundStyle(accent)
                        .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(service.name)
                            .font(.title3.weight(.semibold))
                        HStack(spacing: 6) {
                            Circle()
                                .fill(service.isRunning ? Theme.healthy : Theme.critical)
                                .frame(width: 8, height: 8)
                            Text(service.status.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    ServiceOpenButton(service: service)
                }
                .padding(14)
                .tintedCardStyle(cornerRadius: 12, tint: accent)

                // Summary items
                if !service.summary.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(service.summary.enumerated()), id: \.element.id) { index, item in
                            HStack {
                                Text(item.label)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(item.value)
                                    .font(.callout.monospacedDigit().weight(.medium))
                                    .foregroundStyle(item.type == "percent" ? accent : .primary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)

                            if index < service.summary.count - 1 {
                                Divider().padding(.leading, 14)
                            }
                        }
                    }
                    .cardStyle(cornerRadius: 12)
                }

                // Error
                if let error = service.error, !error.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.critical)
                        Text(error)
                            .foregroundStyle(Theme.critical)
                    }
                    .font(.callout)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tintedCardStyle(cornerRadius: 12, tint: Theme.critical)
                }
            }
            .padding(20)
        }
    }
}
