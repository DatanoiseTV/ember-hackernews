import SwiftUI

struct SearchView: View {
    @State private var vm = SearchViewModel()
    @State private var path = NavigationPath()

    private let suggestions = ["Swift", "AI", "Rust", "Startups", "Security", "Apple", "Postgres"]

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Search")
                .navigationDestination(for: HNItem.self) { StoryDetailView(item: $0) }
                .navigationDestination(for: UserRoute.self) { UserView(username: $0.username) }
        }
        .searchable(text: $vm.query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search stories and discussions")
        .task(id: searchKey) {
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            await vm.runSearch()
        }
        .onAppear {
            #if DEBUG
            if let seeded = LaunchArgs.query, vm.query.isEmpty { vm.query = seeded }
            #endif
        }
    }

    private var searchKey: String { "\(vm.query)|\(vm.mode.rawValue)" }

    @ViewBuilder private var content: some View {
        switch vm.phase {
        case .idle:
            suggestionsView
        case .searching:
            ScrollView { SkeletonList(count: 6) }.background(Theme.background)
        case .failed(let message):
            ErrorStateView(message: message) { Task { await vm.runSearch() } }
                .background(Theme.background)
        case .empty:
            EmptyStateView(systemImage: "magnifyingglass",
                           title: "No results",
                           message: "Try different keywords or switch the sort order.")
                .background(Theme.background)
        case .results:
            resultsList
        }
    }

    private var resultsList: some View {
        List {
            Section {
                ForEach(vm.results) { story in
                    ZStack {
                        NavigationLink(value: story) { EmptyView() }.opacity(0)
                        StoryRow(item: story)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: Spacing.l, bottom: 0, trailing: Spacing.l))
                    .listRowSeparatorTint(Theme.separator)
                    .listRowBackground(Theme.background)
                }
            } header: {
                modePicker
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
    }

    private var modePicker: some View {
        Picker("Sort", selection: Binding(
            get: { vm.mode },
            set: { newValue in Task { await vm.setMode(newValue) } }
        )) {
            ForEach(SearchMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .textCase(nil)
        .padding(.vertical, Spacing.xs)
        .listRowInsets(EdgeInsets(top: Spacing.s, leading: Spacing.l, bottom: Spacing.s, trailing: Spacing.l))
        .listRowBackground(Theme.background)
    }

    private var suggestionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Text("Popular topics")
                    .font(.headline)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, Spacing.xl)

                FlowChips(items: suggestions) { tag in
                    vm.query = tag
                    Haptics.selection()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.l)
        }
        .background(Theme.background)
    }
}

/// Simple wrapping chip layout.
private struct FlowChips: View {
    let items: [String]
    let onTap: (String) -> Void

    var body: some View {
        FlexibleLayout(spacing: Spacing.s) {
            ForEach(items, id: \.self) { item in
                Button {
                    onTap(item)
                } label: {
                    Text(item)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, Spacing.m)
                        .padding(.vertical, Spacing.s)
                        .background(Theme.surface)
                        .foregroundStyle(Theme.textPrimary)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Theme.separator, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
