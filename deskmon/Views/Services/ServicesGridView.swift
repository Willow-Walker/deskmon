import SwiftUI

struct ServicesGridView: View {
    let services: [ServiceInfo]
    let onSelect: (ServiceInfo) -> Void

    @State private var hoveredID: String?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if services.isEmpty {
                emptyState
            } else {
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
