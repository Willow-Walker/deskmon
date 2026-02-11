import Foundation

struct BookmarkService: Codable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var url: String
    var icon: String

    init(id: UUID = UUID(), name: String, url: String, icon: String = "globe") {
        self.id = id
        self.name = name
        self.url = url
        self.icon = icon
    }

    var webURL: URL? { URL(string: url) }
}

// MARK: - Persistence

enum BookmarkStore {
    private static let key = "BookmarkServices"

    static func load() -> [BookmarkService] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([BookmarkService].self, from: data)) ?? []
    }

    static func save(_ bookmarks: [BookmarkService]) {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func add(_ bookmark: BookmarkService) {
        var list = load()
        list.append(bookmark)
        save(list)
    }

    static func remove(id: UUID) {
        var list = load()
        list.removeAll { $0.id == id }
        save(list)
    }

    static func update(_ bookmark: BookmarkService) {
        var list = load()
        if let i = list.firstIndex(where: { $0.id == bookmark.id }) {
            list[i] = bookmark
        }
        save(list)
    }
}
