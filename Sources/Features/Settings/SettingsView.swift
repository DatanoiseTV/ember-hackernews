import SwiftUI

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(ReadStore.self) private var readStore
    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(AccountStore.self) private var account
    @Environment(\.openURL) private var openURL

    @State private var confirmClearRead = false
    @State private var confirmSignOut = false
    @State private var webTask: HNWebTask?
    @State private var cacheSize = 0

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                appearanceSection($settings)
                readingSection($settings)
                accountSection($settings)
                accessibilitySection($settings)
                personalizeSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .tint(settings.accent.color)
            .labelStyle(SettingsLabelStyle())
            .environment(\.defaultMinListRowHeight, 46)
            .task { cacheSize = await DiskCache.shared.sizeInBytes() }
            .sheet(item: $webTask) { task in
                HNWebSheet(task: task)
            }
        }
    }

    // MARK: Account

    private func accountSection(_ settings: Bindable<SettingsStore>) -> some View {
        Section {
            Toggle(isOn: settings.accountFeaturesEnabled) {
                Label("Account Features", systemImage: "person.crop.circle")
            }

            if settings.wrappedValue.accountFeaturesEnabled {
                if account.isSignedIn {
                    HStack {
                        Label("Signed in", systemImage: "checkmark.seal")
                        Spacer()
                        Text(account.username ?? "")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Button { webTask = .submit } label: {
                        Label("New Submission", systemImage: "square.and.pencil")
                    }
                    Toggle(isOn: settings.myCommentsFirst) {
                        Label("Show My Comments First", systemImage: "arrow.up.to.line")
                    }
                    Button(role: .destructive) {
                        confirmSignOut = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .confirmationDialog("Sign out of Hacker News?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                        Button("Sign Out", role: .destructive) {
                            Task { await account.signOut(); Haptics.warning() }
                        }
                    }
                } else {
                    Button { webTask = .login } label: {
                        Label("Sign In", systemImage: "person.crop.circle.badge.plus")
                    }
                }
            }
        } header: {
            Text("Hacker News Account")
        } footer: {
            Text("Optional. Sign in to upvote, comment, and submit. Ember opens news.ycombinator.com in a secure web view — your password is never seen by Ember; only the login session is stored in your device Keychain. These actions are performed on Hacker News on your behalf, so it's your responsibility to follow the [Hacker News guidelines and terms](https://news.ycombinator.com/newsguidelines.html).")
        }
    }

    // MARK: Appearance

    private func appearanceSection(_ settings: Bindable<SettingsStore>) -> some View {
        Section("Appearance") {
            Picker(selection: settings.appearance) {
                ForEach(AppAppearance.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage).tag(mode)
                }
            } label: {
                Label("Theme", systemImage: "circle.lefthalf.filled")
            }
            .pickerStyle(.menu)

            VStack(alignment: .leading, spacing: Spacing.l) {
                Label("Accent", systemImage: "paintpalette")
                AccentPicker(selection: settings.accent)
            }
            .padding(.vertical, Spacing.s)
        }
    }

    // MARK: Reading

    private func readingSection(_ settings: Bindable<SettingsStore>) -> some View {
        Section("Reading") {
            Stepper(value: settings.readingTextScale,
                    in: SettingsStore.minTextScale...SettingsStore.maxTextScale,
                    step: 0.1) {
                Label("Text Size — \(Int((settings.wrappedValue.readingTextScale * 100).rounded()))%",
                      systemImage: "textformat.size")
            }

            Picker(selection: settings.defaultFeed) {
                ForEach(Feed.allCases) { feed in
                    Label(feed.title, systemImage: feed.systemImage).tag(feed)
                }
            } label: {
                Label("Default Feed", systemImage: "list.bullet.rectangle")
            }

            Toggle(isOn: settings.openLinksInApp) {
                Label("Open Links in App", systemImage: "safari")
            }
            Toggle(isOn: settings.readerMode) {
                Label("Open Links in Reader Mode", systemImage: "doc.plaintext")
            }
            .disabled(!settings.wrappedValue.openLinksInApp)
            Toggle(isOn: settings.markReadOnOpen) {
                Label("Mark Stories Read on Open", systemImage: "checkmark.circle")
            }
            Toggle(isOn: settings.showThumbnails) {
                Label("Show Story Thumbnails", systemImage: "square.fill.text.grid.1x2")
            }
            Toggle(isOn: settings.urlAboveTitle) {
                Label("Show URL Above Title", systemImage: "link")
            }
        }
    }

    // MARK: Accessibility

    private func accessibilitySection(_ settings: Bindable<SettingsStore>) -> some View {
        Section {
            Toggle(isOn: settings.underlineLinks) {
                Label("Underline Links", systemImage: "underline")
            }
            Toggle(isOn: settings.distinguishWithoutColor) {
                Label("Color-Blind Friendly Cues", systemImage: "circle.dashed")
            }
            Toggle(isOn: settings.showRankNumbers) {
                Label("Show Rank Numbers", systemImage: "number")
            }
            Toggle(isOn: settings.hapticsEnabled) {
                Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
            }
        } header: {
            Text("Accessibility")
        } footer: {
            Text("Adds shapes and labels so status never depends on color alone. The app also follows your system accessibility settings.")
        }
    }

    // MARK: Personalize

    private var personalizeSection: some View {
        Section {
            Button {
                Haptics.tap()
                withAnimation { settings.resetToDefaults() }
            } label: {
                Label("Personalize Again", systemImage: "wand.and.stars")
            }
        } footer: {
            Text("Resets all preferences to their defaults and re-runs the quick setup.")
        }
    }

    // MARK: Data

    private var dataSection: some View {
        Section("Data") {
            Button(role: .destructive) {
                confirmClearRead = true
            } label: {
                Label("Clear Read History", systemImage: "eye.slash")
            }
            .confirmationDialog("Clear read history?", isPresented: $confirmClearRead, titleVisibility: .visible) {
                Button("Clear", role: .destructive) {
                    readStore.clear()
                    Haptics.warning()
                }
            } message: {
                Text("Stories will no longer appear as read.")
            }

            HStack {
                Label("Saved Stories", systemImage: "bookmark")
                Spacer()
                Text("\(bookmarks.items.count)")
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack {
                Label("Offline Cache", systemImage: "internaldrive")
                Spacer()
                Text(cacheSize.formatted(.byteCount(style: .file)))
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            }
            Button(role: .destructive) {
                Task {
                    await DiskCache.shared.clear()
                    cacheSize = 0
                    Haptics.warning()
                }
            } label: {
                Label("Clear Offline Cache", systemImage: "trash")
            }
        }
    }

    // MARK: About

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text(appVersion).foregroundStyle(Theme.textSecondary)
            }
            Button {
                openURL(URL(string: "https://news.ycombinator.com")!)
            } label: {
                Label("Hacker News", systemImage: "globe")
            }
            Button {
                openURL(URL(string: "https://github.com/HackerNews/API")!)
            } label: {
                Label("Powered by the HN API", systemImage: "chevron.left.forwardslash.chevron.right")
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

/// Consistent settings rows: a fixed-width icon column, generous icon-to-title
/// spacing, and vertical padding so rows breathe and icons never clip.
struct SettingsLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.m) {
            configuration.icon
                .font(.system(size: 16))
                .frame(width: 26, alignment: .center)
            configuration.title
        }
        .padding(.vertical, 4)
    }
}

/// Row of accent swatches; selection shown with a ring + checkmark (not color alone).
struct AccentPicker: View {
    @Binding var selection: AccentTheme

    var body: some View {
        HStack(spacing: Spacing.l) {
            ForEach(AccentTheme.allCases) { accent in
                Button {
                    selection = accent
                    Haptics.selection()
                } label: {
                    Circle()
                        .fill(accent.color)
                        .frame(width: 32, height: 32)
                        .overlay {
                            if accent == selection {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay(
                            Circle().strokeBorder(
                                accent == selection ? Theme.textPrimary : Color.clear,
                                lineWidth: 2
                            )
                            .padding(-3)
                        )
                        .padding(3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accent.title)
                .accessibilityAddTraits(accent == selection ? [.isButton, .isSelected] : .isButton)
            }
            Spacer()
        }
    }
}
