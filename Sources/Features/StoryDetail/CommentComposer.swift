import SwiftUI

/// What a compose sheet is doing: a new top-level comment / reply, or editing
/// one of the user's existing comments.
struct ComposeTarget: Identifiable {
    enum Kind {
        case comment(parentID: Int)
        case edit(commentID: Int)
    }

    let id = UUID()
    let kind: Kind
    let storyID: Int
    let title: String
    /// Short preview of the thing being replied to (author · snippet).
    let context: String?
    /// Prefilled body — the raw source when editing.
    var initialText: String = ""
}

/// Native comment / reply / edit editor. Saves through the supplied closure; for
/// new comments it offers HN's own form in a web view as a fallback.
struct CommentComposer: View {
    let target: ComposeTarget
    let submit: (String) async throws -> Void
    var onPosted: (String) -> Void = { _ in }

    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var text: String
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var showWebFallback = false
    @FocusState private var focused: Bool

    init(target: ComposeTarget,
         submit: @escaping (String) async throws -> Void,
         onPosted: @escaping (String) -> Void = { _ in }) {
        self.target = target
        self.submit = submit
        self.onPosted = onPosted
        _text = State(initialValue: target.initialText)
    }

    private var isEditing: Bool {
        if case .edit = target.kind { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                if let context = target.context {
                    Text(context)
                        .font(AppFont.meta)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                        .padding(.horizontal, Spacing.l)
                        .padding(.top, Spacing.m)
                }

                TextEditor(text: $text)
                    .font(.reader(17, .regular, relativeTo: .body))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, Spacing.l - 4)
                    .padding(.top, Spacing.s)
                    .focused($focused)

                if let errorMessage {
                    HStack(spacing: Spacing.s) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.upvote)
                        Text(errorMessage)
                            .font(AppFont.meta)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer(minLength: 0)
                        if case .comment = target.kind {
                            Button("Use Browser") { showWebFallback = true }
                                .font(AppFont.metaStrong)
                        }
                    }
                    .padding(Spacing.l)
                }
            }
            .background(Theme.background)
            .navigationTitle(target.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isPosting {
                        ProgressView()
                    } else {
                        Button(isEditing ? "Save" : "Post", action: post)
                            .fontWeight(.semibold)
                            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .tint(settings.accent.color)
            .onAppear { focused = true }
            .sheet(isPresented: $showWebFallback) {
                if case .comment(let parentID) = target.kind {
                    HNWebSheet(task: .reply(parentID: parentID, storyID: target.storyID)) {
                        onPosted(text)
                        dismiss()
                    }
                }
            }
        }
    }

    private func post() {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        isPosting = true
        errorMessage = nil
        Task {
            do {
                try await submit(body)
                Haptics.success()
                onPosted(body)
                dismiss()
            } catch {
                isPosting = false
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't save. Please try again."
                Haptics.warning()
            }
        }
    }
}
