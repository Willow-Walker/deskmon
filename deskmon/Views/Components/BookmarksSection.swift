import SwiftUI

struct BookmarksSection: View {
    @State private var hoveredBookmarkID: UUID?
    @State private var bookmarks: [BookmarkService] = []
    @State private var showingAddBookmark = false
    @State private var editingBookmark: BookmarkService?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Bookmarks")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                if !bookmarks.isEmpty {
                    Text("(\(bookmarks.count))")
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
                .help("Add bookmark")
            }

            if bookmarks.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
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
        .sheet(isPresented: $showingAddBookmark) {
            AddBookmarkSheet { bookmark in
                BookmarkStore.add(bookmark)
                bookmarks = BookmarkStore.load()
            }
        }
        .sheet(item: $editingBookmark) { bookmark in
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
        VStack(spacing: 10) {
            Image(systemName: "bookmark")
                .font(.system(size: 28))
                .foregroundStyle(Theme.cardBorder)

            Text("No Bookmarks")
                .font(.headline)

            Text("Add quick links to your services and dashboards")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button { showingAddBookmark = true } label: {
                Label("Add Bookmark", systemImage: "plus")
                    .font(.caption)
            }
            .buttonStyle(.dark)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
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
