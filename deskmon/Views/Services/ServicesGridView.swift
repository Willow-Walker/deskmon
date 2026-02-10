import SwiftUI

struct ServicesGridView: View {
    let services: [ServiceInfo]
    let lastUpdate: Date?
    let onSelect: (ServiceInfo) -> Void

    @State private var hoveredID: String?
    @State private var refreshProgress: CGFloat = 0

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
                // Refresh countdown bar
                refreshBar

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
        .onChange(of: lastUpdate) {
            // Reset and restart the countdown when new data arrives.
            refreshProgress = 0
            withAnimation(.linear(duration: Self.refreshInterval)) {
                refreshProgress = 1
            }
        }
        .onAppear {
            // Kick off the first countdown based on elapsed time since last update.
            if let last = lastUpdate {
                let elapsed = Date().timeIntervalSince(last)
                let remaining = max(Self.refreshInterval - elapsed, 0)
                refreshProgress = CGFloat(elapsed / Self.refreshInterval)
                withAnimation(.linear(duration: remaining)) {
                    refreshProgress = 1
                }
            }
        }
    }

    // MARK: - Refresh Bar

    private var refreshBar: some View {
        VStack(spacing: 4) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.trianglehead.clockwise")
                        .font(.system(size: 8))
                    Text("Next refresh")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int((1 - refreshProgress) * Self.refreshInterval))s")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Theme.accent.opacity(0.4))
                            .frame(width: geo.size.width * refreshProgress)
                    }
            }
            .frame(height: 3)
            .clipShape(Capsule())
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
