import Foundation
import Observation
import os

nonisolated private let bookmarkLog = Logger(subsystem: "g.IndicatorDiff", category: "bookmark")

nonisolated struct StoredURL: Codable, Sendable, Hashable {
    let path: String
    let bookmark: Data?

    init(url: URL) {
        self.path = url.path
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        bookmarkLog.log("bookmark.create start didStart=\(didStart) path=\(url.path, privacy: .public)")
        do {
            // Our entitlement is user-selected.read-only — the bookmark must
            // declare read-only scope too, otherwise the API tries to open the
            // file read-write and the sandbox returns EPERM.
            let data = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            bookmarkLog.log("bookmark.create success bytes=\(data.count) path=\(url.path, privacy: .public)")
            self.bookmark = data
        } catch {
            bookmarkLog.error("bookmark.create FAILED path=\(url.path, privacy: .public) error=\(String(describing: error), privacy: .public)")
            self.bookmark = nil
        }
    }

    /// Resolves the stored security-scoped bookmark to a URL that can be accessed
    /// (after the caller starts its security scope). Returns `nil` when the bookmark
    /// is missing or unresolvable.
    func resolve() -> URL? {
        guard let bookmark else {
            bookmarkLog.log("bookmark.resolve skipped (no bookmark) path=\(path, privacy: .public)")
            return nil
        }
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            bookmarkLog.log("bookmark.resolve success isStale=\(isStale) path=\(url.path, privacy: .public)")
            return url
        } catch {
            bookmarkLog.error("bookmark.resolve FAILED path=\(path, privacy: .public) error=\(String(describing: error), privacy: .public)")
            return nil
        }
    }

    var hasBookmark: Bool { bookmark != nil }
}

nonisolated enum HistoryMode: String, Codable, Sendable {
    case files
    case folders
}

nonisolated struct HistoryEntry: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var timestamp: Date
    var mode: HistoryMode
    var slotA: StoredURL
    var slotB: StoredURL

    init(mode: HistoryMode, slotA: StoredURL, slotB: StoredURL) {
        self.id = UUID()
        self.timestamp = Date()
        self.mode = mode
        self.slotA = slotA
        self.slotB = slotB
    }
}

@MainActor
@Observable
final class ComparisonHistory {
    static let defaultsKey = "IndicatorDiff.comparisonHistory"
    static let maxEntries = 50

    var entries: [HistoryEntry] = []

    init() { load() }

    func record(mode: HistoryMode, urlA: URL, urlB: URL) {
        bookmarkLog.log("history.record mode=\(mode.rawValue, privacy: .public) a=\(urlA.path, privacy: .public) b=\(urlB.path, privacy: .public)")
        let a = StoredURL(url: urlA)
        let b = StoredURL(url: urlB)
        bookmarkLog.log("history.record bookmarks a=\(a.hasBookmark, privacy: .public) b=\(b.hasBookmark, privacy: .public)")

        if let idx = entries.firstIndex(where: {
            $0.mode == mode && $0.slotA.path == a.path && $0.slotB.path == b.path
        }) {
            var entry = entries.remove(at: idx)
            entry.timestamp = Date()
            entry.slotA = a
            entry.slotB = b
            entries.insert(entry, at: 0)
        } else {
            var entry = HistoryEntry(mode: mode, slotA: a, slotB: b)
            entry.timestamp = Date()
            entries.insert(entry, at: 0)
        }

        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
        save()
    }

    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func clear() {
        entries = []
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey) else { return }
        guard let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        self.entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }
}
