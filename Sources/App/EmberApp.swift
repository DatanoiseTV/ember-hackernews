import SwiftUI

@main
struct EmberApp: App {
    @State private var settings = SettingsStore()
    @State private var bookmarks = BookmarkStore()
    @State private var readStore = ReadStore()
    @State private var linkOpener = LinkOpener()
    @State private var account = AccountStore()
    @State private var voteStore = VoteStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(bookmarks)
                .environment(readStore)
                .environment(linkOpener)
                .environment(account)
                .environment(voteStore)
                .task {
                    await account.restore()
                }
        }
    }
}
