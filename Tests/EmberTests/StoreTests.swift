import Foundation
import Testing
@testable import Ember

@Suite("User defaults stores", .serialized)
struct UserDefaultsStoreTests {
    @Test("Settings use defaults, persist mutations, and reload")
    func settingsPersistence() {
        let (defaults, suite) = TestSupport.defaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = SettingsStore(defaults: defaults)
        #expect(settings.appearance == .system)
        #expect(settings.accent == .ember)
        #expect(settings.defaultFeed == .top)
        #expect(settings.openLinksInApp)
        #expect(!settings.hasCompletedOnboarding)

        settings.appearance = .dark
        settings.accent = .ocean
        settings.defaultFeed = .best
        settings.openLinksInApp = false
        settings.readerMode = true
        settings.markReadOnOpen = false
        settings.hapticsEnabled = false
        settings.underlineLinks = false
        settings.distinguishWithoutColor = true
        settings.showRankNumbers = false
        settings.hasCompletedOnboarding = true

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.appearance == .dark)
        #expect(reloaded.accent == .ocean)
        #expect(reloaded.defaultFeed == .best)
        #expect(!reloaded.openLinksInApp)
        #expect(reloaded.readerMode)
        #expect(!reloaded.markReadOnOpen)
        #expect(!reloaded.hapticsEnabled)
        #expect(!reloaded.underlineLinks)
        #expect(reloaded.distinguishWithoutColor)
        #expect(!reloaded.showRankNumbers)
        #expect(reloaded.hasCompletedOnboarding)
    }

    @Test("Read history persists, ignores duplicates, clears, and stays bounded")
    func readStorePersistenceAndBounds() {
        let (defaults, suite) = TestSupport.defaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = ReadStore(defaults: defaults)
        store.markRead(10)
        store.markRead(10)
        #expect(store.readIDs == [10])
        #expect(ReadStore(defaults: defaults).isRead(10))

        store.markUnread(10)
        #expect(!store.isRead(10))
        store.markUnread(10)

        for id in 1...2_050 { store.markRead(id) }
        #expect(store.readIDs.count == 2_000)
        #expect(store.isRead(2_050))
        #expect(!store.isRead(1))

        store.clear()
        #expect(store.readIDs.isEmpty)
        #expect(ReadStore(defaults: defaults).readIDs.isEmpty)
    }
}

@Suite("Bookmark store", .serialized)
struct BookmarkStoreTests {
    @Test("Bookmarks persist ordering, toggle, remove, and clear")
    func bookmarkLifecycle() {
        let filename = "bookmarks-\(UUID().uuidString).json"
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let fileURL = directory.appendingPathComponent(filename)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let first = TestSupport.story(id: 1)
        let second = TestSupport.story(id: 2)
        let store = BookmarkStore(filename: filename)
        #expect(store.items.isEmpty)
        #expect(store.toggle(first))
        #expect(store.toggle(second))
        #expect(store.items.map(\.id) == [2, 1])
        #expect(store.isBookmarked(first))

        let reloaded = BookmarkStore(filename: filename)
        #expect(reloaded.items.map(\.id) == [2, 1])
        #expect(!reloaded.toggle(second))
        #expect(reloaded.items.map(\.id) == [1])

        reloaded.remove(1)
        #expect(reloaded.items.isEmpty)
        reloaded.toggle(first)
        reloaded.removeAll()
        #expect(reloaded.items.isEmpty)
        #expect(BookmarkStore(filename: filename).items.isEmpty)
    }
}
