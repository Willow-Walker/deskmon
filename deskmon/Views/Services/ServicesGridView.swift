import SwiftUI

struct ServicesGridView: View {
    let services: [ServiceInfo]
    let lastUpdate: Date?
    let onSelect: (ServiceInfo) -> Void

    @State private var hoveredID: String?
    @State private var hoveredBookmarkID: UUID?
    @State private var bookmarks: [BookmarkService] = []
    @State private var showingAddBookmark = false
    @State private var editingBookmark: BookmarkService?

    /// The agent sends services events every 10 seconds.
    private static let refreshInterval: TimeInterval = 10

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with add button
            HStack {
                Text("Services")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                if !services.isEmpty {
                    Text("(\(services.count + bookmarks.count))")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button { showingAddBookmark = true } label: {
                    Image(systemName: "plus")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Add service bookmark")
            }

            if !services.isEmpty {
                RefreshCountdownBar(lastUpdate: lastUpdate, interval: Self.refreshInterval)
            }

            if services.isEmpty && bookmarks.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    // Detected services
                    ForEach(services) { service in
                        ServiceCardView(
                            service: service,
                            isHovered: hoveredID == service.id
                        )
                        .contentShape(.rect)
                        .onTapGesture { onSelect(service) }
                        .onHover { hoveredID = $0 ? service.id : nil }
                    }

                    // Bookmark services
                    ForEach(bookmarks) { bookmark in
                        BookmarkCardView(
                            bookmark: bookmark,
                            isHovered: hoveredBookmarkID == bookmark.id,
                            onEdit: { editingBookmark = bookmark },
                            onDelete: { removeBookmark(bookmark) }
                        )
                        .contentShape(.rect)
                        .onTapGesture {
                            if let url = bookmark.webURL {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .onHover { hoveredBookmarkID = $0 ? bookmark.id : nil }
                    }
                }
            }
        }
        .onAppear { bookmarks = BookmarkStore.load() }
        .popover(isPresented: $showingAddBookmark) {
            AddBookmarkSheet { bookmark in
                BookmarkStore.add(bookmark)
                bookmarks = BookmarkStore.load()
            }
        }
        .popover(item: $editingBookmark) { bookmark in
            AddBookmarkSheet(editingBookmark: bookmark) { updated in
                BookmarkStore.update(updated)
                bookmarks = BookmarkStore.load()
            }
        }
    }

    private func removeBookmark(_ bookmark: BookmarkService) {
        withAnimation(.smooth(duration: 0.25)) {
            BookmarkStore.remove(id: bookmark.id)
            bookmarks = BookmarkStore.load()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(Theme.cardBorder)
            Text("No Services")
                .font(.headline)
            Text("The agent scans for services like Pi-hole, Traefik, and Nginx.\nYou can also add service bookmarks with the + button.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Bookmark Card

private struct BookmarkCardView: View {
    let bookmark: BookmarkService
    let isHovered: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Accent strip
            Theme.accent.opacity(0.6)
                .frame(height: 3)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: bookmark.icon)
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(bookmark.name)
                            .font(.callout.weight(.semibold))
                        Text(bookmark.url)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    Spacer()
                }

                // Actions
                HStack(spacing: 8) {
                    Label("Open", systemImage: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)

                    Spacer()

                    // Edit/delete — visible on hover
                    HStack(spacing: 4) {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.caption2)
                                .foregroundStyle(Theme.critical.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                    .opacity(isHovered ? 1 : 0)
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
                    isHovered ? Theme.accent.opacity(0.3) : Theme.cardBorder,
                    lineWidth: 1
                )
        )
        .clipShape(.rect(cornerRadius: 12))
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
