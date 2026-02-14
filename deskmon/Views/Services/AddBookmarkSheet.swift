import SwiftUI

struct AddBookmarkSheet: View {
    @Environment(\.dismiss) private var dismiss

    var editingBookmark: BookmarkService?
    var onSave: (BookmarkService) -> Void

    @State private var name = ""
    @State private var url = ""
    @State private var selectedIcon = "globe"

    private static let iconOptions = [
        "globe", "server.rack", "network", "externaldrive",
        "cloud", "lock.shield", "chart.bar", "gearshape",
        "envelope", "bolt.fill", "cpu", "doc.text",
        "terminal", "hammer", "wrench", "puzzlepiece",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editingBookmark == nil ? "Add Bookmark" : "Edit Bookmark")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. n8n, Homarr, Dokploy", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("https://...", text: $url)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Icon")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(36), spacing: 8), count: 8), spacing: 8) {
                    ForEach(Self.iconOptions, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.body)
                                .frame(width: 36, height: 36)
                                .background(
                                    selectedIcon == icon ? Theme.accent.opacity(0.2) : Color.white.opacity(0.04),
                                    in: .rect(cornerRadius: 8)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            selectedIcon == icon ? Theme.accent.opacity(0.5) : Theme.cardBorder,
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)

                Spacer()

                Button(editingBookmark == nil ? "Add" : "Save") {
                    let bookmark = BookmarkService(
                        id: editingBookmark?.id ?? UUID(),
                        name: name.trimmingCharacters(in: .whitespaces),
                        url: url.trimmingCharacters(in: .whitespaces),
                        icon: selectedIcon
                    )
                    onSave(bookmark)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                          url.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
        .onAppear {
            if let b = editingBookmark {
                name = b.name
                url = b.url
                selectedIcon = b.icon
            }
        }
    }
}
