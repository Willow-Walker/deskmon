import SwiftUI

struct ServicesGridView: View {
    let services: [ServiceInfo]
    let lastUpdate: Date?
    let onSelect: (ServiceInfo) -> Void

    @State private var hoveredID: String?

    /// The agent sends services events every 10 seconds.
    private static let refreshInterval: TimeInterval = 10

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if services.isEmpty {
                emptyState
            } else {
                // Refresh countdown bar — driven by wall clock, not animation
                RefreshCountdownBar(lastUpdate: lastUpdate, interval: Self.refreshInterval)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(services) { service in
                        ServiceCardView(
                            service: service,
                            isHovered: hoveredID == service.id
                        )
                        .contentShape(.rect)
                        .onTapGesture {
                            onSelect(service)
                        }
                        .onHover { isHovering in
                            hoveredID = isHovering ? service.id : nil
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(Theme.cardBorder)
            Text("No Services Detected")
                .font(.headline)
            Text("The agent is scanning for services like Pi-hole, Traefik, and Nginx.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Refresh Countdown Bar

/// Ticks once per second using TimelineView so both the countdown text
/// and progress bar update in sync from the wall clock.
private struct RefreshCountdownBar: View {
    let lastUpdate: Date?
    let interval: TimeInterval

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let now = timeline.date
            let elapsed = lastUpdate.map { now.timeIntervalSince($0) } ?? interval
            let overdue = elapsed >= interval
            let progress = min(max(elapsed / interval, 0), 1)
            let remaining = max(Int(ceil(interval - elapsed)), 0)

            VStack(spacing: 4) {
                HStack {
                    HStack(spacing: 4) {
                        if overdue {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.trianglehead.clockwise")
                                .font(.system(size: 8))
                        }
                        Text(overdue ? "Refreshing..." : "Next refresh")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)

                    Spacer()

                    if !overdue {
                        Text("\(remaining)s")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                            .contentTransition(.numericText())
                    }
                }

                GeometryReader { geo in
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Theme.accent.opacity(0.4))
                                .frame(width: geo.size.width * progress)
                                .animation(.linear(duration: 1), value: progress)
                        }
                }
                .frame(height: 3)
                .clipShape(Capsule())
            }
        }
    }
}
