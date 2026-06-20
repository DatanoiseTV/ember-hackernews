import SwiftUI

struct UserView: View {
    let username: String
    @State private var vm: UserViewModel
    @Environment(\.openURL) private var openURL

    init(username: String) {
        self.username = username
        _vm = State(initialValue: UserViewModel(username: username))
    }

    var body: some View {
        ScrollView {
            switch vm.phase {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            case .failed(let message):
                ErrorStateView(message: message) { Task { await vm.load() } }
            case .loaded:
                VStack(alignment: .leading, spacing: 0) {
                    header
                    if !vm.submissions.isEmpty { submissionsSection }
                }
            }
        }
        .background(Theme.background)
        .navigationTitle(username)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    openURL(URL(string: "https://news.ycombinator.com/user?id=\(username)")!)
                } label: {
                    Image(systemName: "safari")
                }
                .accessibilityLabel("Open profile on Hacker News")
            }
        }
        .task { await vm.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            HStack(spacing: Spacing.m) {
                MonogramAvatar(name: username, size: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text(username)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    if let joined = vm.user?.createdDate {
                        Text("Joined \(RelativeTime.absolute(joined))")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
            }

            HStack(spacing: Spacing.s) {
                statTile(value: formatted(vm.user?.karmaValue ?? 0), label: "Karma", icon: "star.fill")
                statTile(value: "\(vm.user?.submissionCount ?? 0)", label: "Submissions", icon: "doc.text.fill")
            }

            if let about = vm.user?.about, !about.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("About")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    ForEach(Array(HTMLRenderer.render(about).enumerated()), id: \.offset) { _, block in
                        CommentBlockView(block: block)
                    }
                }
                .padding(.top, Spacing.xs)
            }
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
    }

    private func statTile(value: String, label: String, icon: String) -> some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.upvote)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    private var submissionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent Submissions")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.l)
                .padding(.bottom, Spacing.s)

            ForEach(vm.submissions) { story in
                NavigationLink(value: story) {
                    StoryRow(item: story)
                        .padding(.horizontal, Spacing.l)
                }
                .buttonStyle(.plain)
                Divider().background(Theme.hairline).padding(.leading, Spacing.l)
            }
        }
    }

    private func formatted(_ n: Int) -> String {
        n.formatted(.number.notation(.compactName))
    }
}
