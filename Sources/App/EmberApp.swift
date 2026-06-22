import SwiftUI

@main
struct EmberApp: App {
    @State private var settings = SettingsStore()
    @State private var bookmarks = BookmarkStore()
    @State private var readStore = ReadStore()
    @State private var linkOpener = LinkOpener()
    @State private var account = AccountStore()
    @State private var voteStore = VoteStore()
    @State private var pendingComments = PendingCommentStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(bookmarks)
                .environment(readStore)
                .environment(linkOpener)
                .environment(account)
                .environment(voteStore)
                .environment(pendingComments)
                .task {
                    await account.restore()
                }
        }
    }
}
