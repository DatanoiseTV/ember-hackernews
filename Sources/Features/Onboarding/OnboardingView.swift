import SwiftUI
import UIKit

/// First-run personalization. The "smart" part: on appear it inspects the
/// device's appearance and accessibility settings and pre-configures Ember to
/// match, then explains what it tuned. Every choice updates the app — and the
/// live preview — immediately.
struct OnboardingView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(AccountStore.self) private var account
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var step = 0
    @State private var detected: [DetectedSetting] = []
    @State private var pulse = false
    @State private var webTask: HNWebTask?

    private let lastStep = 6

    var body: some View {
        @Bindable var settings = settings

        VStack(spacing: 0) {
            progressBar
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.l)

            TabView(selection: $step) {
                welcomeStep.tag(0)
                appearanceStep($settings).tag(1)
                accentStep($settings).tag(2)
                accessibilityStep($settings).tag(3)
                feedStep($settings).tag(4)
                accountStep.tag(5)
                doneStep.tag(6)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: step)

            bottomBar
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.l)
        }
        // Keep the flow a comfortable reading width on large (Mac) windows.
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .tint(settings.accent.color)
        .onAppear {
            applySmartDefaults()
            #if DEBUG
            if let seeded = LaunchArgs.onboardingStep { step = seeded }
            #endif
        }
        .sheet(item: $webTask) { task in
            // Re-inject stores across the sheet boundary (issue #1).
            HNWebSheet(task: task) { settings.accountFeaturesEnabled = true }
                .environment(account)
                .environment(settings)
        }
    }

    // MARK: Progress

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0...lastStep, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? settings.accent.color : Theme.separator)
                    .frame(height: 5)
                    .animation(.easeInOut, value: step)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(step + 1) of \(lastStep + 1)")
    }

    // MARK: Step 0 — Welcome

    private var welcomeStep: some View {
        StepScaffold {
            VStack(spacing: Spacing.xl) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(settings.accent.color.opacity(0.14))
                        .frame(width: 150, height: 150)
                        .scaleEffect(pulse ? 1.08 : 0.94)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(settings.accent.color)
                        .scaleEffect(pulse ? 1.04 : 1.0)
                }
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
                .accessibilityHidden(true)

                VStack(spacing: Spacing.s) {
                    Text("Welcome to Ember")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .multilineTextAlignment(.center)
                    Text("A calmer way to read Hacker News. Let's tune it to you — it takes about 20 seconds.")
                        .font(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.l)
                }
                Spacer()
                Spacer()
            }
        }
    }

    // MARK: Step 1 — Appearance

    private func appearanceStep(_ settings: Bindable<SettingsStore>) -> some View {
        StepScaffold {
            VStack(spacing: Spacing.xl) {
                StepHeader(
                    title: "Choose your look",
                    subtitle: systemScheme == .dark
                        ? "Your device is in Dark Mode — System will follow it automatically."
                        : "System follows your device's light and dark schedule."
                )
                HStack(spacing: Spacing.m) {
                    ForEach(AppAppearance.allCases) { mode in
                        SelectableCard(
                            title: mode.title,
                            systemImage: mode.systemImage,
                            isSelected: settings.wrappedValue.appearance == mode,
                            accent: settings.wrappedValue.accent.color
                        ) {
                            withAnimation { settings.wrappedValue.appearance = mode }
                            Haptics.selection()
                        }
                    }
                }
                previewCard
                Spacer()
            }
        }
    }

    // MARK: Step 2 — Accent

    private func accentStep(_ settings: Bindable<SettingsStore>) -> some View {
        StepScaffold {
            VStack(spacing: Spacing.xl) {
                StepHeader(title: "Pick an accent", subtitle: "Used for highlights, links, and actions across the app.")

                FlexibleLayout(spacing: Spacing.m, lineSpacing: Spacing.m) {
                    ForEach(AccentTheme.allCases) { accent in
                        Button {
                            withAnimation { settings.wrappedValue.accent = accent }
                            Haptics.selection()
                        } label: {
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(accent.color)
                                    .frame(width: 46, height: 46)
                                    .overlay {
                                        if settings.wrappedValue.accent == accent {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 17, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .overlay(
                                        Circle().strokeBorder(
                                            settings.wrappedValue.accent == accent ? Theme.textPrimary : .clear,
                                            lineWidth: 2.5
                                        ).padding(-4)
                                    )
                                Text(accent.title)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .frame(width: 64)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(accent.title)
                        .accessibilityAddTraits(settings.wrappedValue.accent == accent ? [.isButton, .isSelected] : .isButton)
                    }
                }
                previewCard
                Spacer()
            }
        }
    }

    // MARK: Step 4 — Home feed

    private func feedStep(_ settings: Bindable<SettingsStore>) -> some View {
        StepScaffold {
            VStack(spacing: Spacing.l) {
                StepHeader(title: "Where should we start?", subtitle: "Your home feed when you open Ember. You can switch anytime.")
                VStack(spacing: Spacing.s) {
                    ForEach(Feed.allCases) { feed in
                        FeedChoiceRow(
                            feed: feed,
                            isSelected: settings.wrappedValue.defaultFeed == feed,
                            accent: settings.wrappedValue.accent.color
                        ) {
                            withAnimation { settings.wrappedValue.defaultFeed = feed }
                            Haptics.selection()
                        }
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: Step 3 — Accessibility (smart)

    private func accessibilityStep(_ settings: Bindable<SettingsStore>) -> some View {
        StepScaffold {
            VStack(alignment: .leading, spacing: Spacing.l) {
                StepHeader(
                    title: "Tuned for you",
                    subtitle: detected.isEmpty
                        ? "Ember never relies on color alone. Adjust anything below."
                        : "We matched these to your device settings — change anything you like."
                )

                if !detected.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        ForEach(detected) { item in
                            HStack(spacing: Spacing.s) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(settings.wrappedValue.accent.color)
                                    .frame(width: 22)
                                Text(item.text)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer(minLength: 0)
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.positive)
                            }
                        }
                    }
                    .padding(Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                }

                VStack(spacing: 2) {
                    ToggleRow(title: "Color-blind friendly cues", subtitle: "Adds checkmarks and shapes, not just color", systemImage: "circle.dashed", isOn: settings.distinguishWithoutColor)
                    Divider().padding(.leading, 40)
                    ToggleRow(title: "Underline links", subtitle: "Keep links identifiable without color", systemImage: "underline", isOn: settings.underlineLinks)
                    Divider().padding(.leading, 40)
                    ToggleRow(title: "Rank numbers", subtitle: "Show numeric position in feeds", systemImage: "number", isOn: settings.showRankNumbers)
                    Divider().padding(.leading, 40)
                    ToggleRow(title: "Story thumbnails", subtitle: "Show the site favicon next to each story", systemImage: "square.fill.text.grid.1x2", isOn: settings.showThumbnails)
                    Divider().padding(.leading, 40)
                    ToggleRow(title: "URL above title", subtitle: "Show the site link above each headline, classic HN style", systemImage: "link", isOn: settings.urlAboveTitle)
                }
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))

                if typeSize.isAccessibilitySize {
                    Label("Large text detected — layouts adapt automatically.", systemImage: "textformat.size")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                previewCard
                Spacer()
            }
        }
    }

    // MARK: Step 5 — Account

    private var accountStep: some View {
        StepScaffold {
            VStack(spacing: Spacing.xl) {
                StepHeader(
                    title: "Sign in to Hacker News",
                    subtitle: "Optional. Sign in to upvote, comment, and submit — or skip and do it later in Settings."
                )

                ZStack {
                    Circle()
                        .fill(settings.accent.color.opacity(0.14))
                        .frame(width: 116, height: 116)
                    Image(systemName: account.isSignedIn ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
                        .font(.system(size: 54))
                        .foregroundStyle(settings.accent.color)
                }
                .accessibilityHidden(true)

                if account.isSignedIn {
                    Label("Signed in as \(account.username ?? "you")", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.positive)
                } else {
                    Button {
                        Haptics.tap()
                        webTask = .login
                    } label: {
                        Label("Sign In Now", systemImage: "person.crop.circle.badge.plus")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(settings.accent.color)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Text("Login happens on news.ycombinator.com in a secure web view — your password is never seen by Ember; only the session is stored in your device Keychain.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.l)
                }
                Spacer()
            }
        }
    }

    // MARK: Step 6 — Done

    private var doneStep: some View {
        StepScaffold {
            VStack(spacing: Spacing.xl) {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(settings.accent.color)
                    .accessibilityHidden(true)
                VStack(spacing: Spacing.s) {
                    Text("You're all set")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Text("Ember is tuned to your taste. You can change anything later in Settings.")
                        .font(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.l)
                }
                summaryChips
                Spacer()
                Spacer()
            }
        }
    }

    private var summaryChips: some View {
        FlexibleLayout(spacing: Spacing.s, lineSpacing: Spacing.s) {
            summaryChip(settings.appearance.systemImage, settings.appearance.title)
            summaryChip("paintpalette.fill", settings.accent.title)
            summaryChip(settings.defaultFeed.systemImage, settings.defaultFeed.title)
            if account.isSignedIn {
                summaryChip("person.crop.circle.fill", account.username ?? "Signed in")
            }
        }
        .frame(maxWidth: 320)
    }

    private func summaryChip(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption2.weight(.bold))
            Text(text).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, 7)
        .background(settings.accent.color.opacity(0.15))
        .foregroundStyle(settings.accent.color)
        .clipShape(Capsule())
    }

    // MARK: Live preview

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("PREVIEW")
                .font(.system(size: 10, weight: .heavy))
                .tracking(1)
                .foregroundStyle(Theme.textTertiary)
            OnboardingPreviewRow(accent: settings.accent.color, showThumbnail: settings.showThumbnails, showRank: settings.showRankNumbers, underlineLinks: settings.underlineLinks, urlAboveTitle: settings.urlAboveTitle)
                .padding(Spacing.m)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Theme.separator, lineWidth: 1))
        }
        .accessibilityHidden(true)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack(spacing: Spacing.m) {
            if step > 0 {
                Button {
                    Haptics.tap()
                    withAnimation { step -= 1 }
                } label: {
                    Text("Back")
                        .font(.headline)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                }
                .buttonStyle(.plain)
                .frame(width: 110)
            }

            Button {
                advance()
            } label: {
                Text(step == lastStep ? "Start Reading" : "Continue")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(settings.accent.color)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Logic

    private func advance() {
        if step == lastStep {
            Haptics.success()
            settings.hasCompletedOnboarding = true
        } else {
            Haptics.tap()
            withAnimation { step += 1 }
        }
    }

    /// Inspect the device and pre-configure matching options.
    private func applySmartDefaults() {
        guard detected.isEmpty else { return }
        var found: [DetectedSetting] = []

        if UIAccessibility.shouldDifferentiateWithoutColor {
            settings.distinguishWithoutColor = true
            found.append(DetectedSetting(icon: "circle.dashed", text: "Differentiate Without Color → color-blind cues on"))
        }
        if UIAccessibility.isReduceMotionEnabled {
            found.append(DetectedSetting(icon: "figure.walk.motion", text: "Reduce Motion → animations minimized"))
        }
        if UIAccessibility.isVoiceOverRunning {
            settings.underlineLinks = true
            settings.showRankNumbers = true
            found.append(DetectedSetting(icon: "speaker.wave.3.fill", text: "VoiceOver → labels & underlined links on"))
        }
        if UIAccessibility.isBoldTextEnabled {
            found.append(DetectedSetting(icon: "bold", text: "Bold Text honored throughout"))
        }
        if typeSize.isAccessibilitySize {
            found.append(DetectedSetting(icon: "textformat.size", text: "Large Text → adaptive layouts"))
        }
        detected = found
    }

    struct DetectedSetting: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
    }
}

// MARK: - Reusable step pieces

private struct StepScaffold<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.xl)
                .frame(maxWidth: .infinity, minHeight: 480, alignment: .top)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct StepHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: Spacing.s) {
            Text(title)
                .font(.system(.title, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct SelectableCard: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.s) {
                Image(systemName: systemImage)
                    .font(.system(size: 26))
                    .foregroundStyle(isSelected ? accent : Theme.textSecondary)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.l)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .strokeBorder(isSelected ? accent : Theme.separator, lineWidth: isSelected ? 2.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct FeedChoiceRow: View {
    let feed: Feed
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                Image(systemName: feed.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : accent)
                    .frame(width: 38, height: 38)
                    .background(isSelected ? accent : accent.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(feed.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? accent : Theme.separator)
            }
            .padding(Spacing.m)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .strokeBorder(isSelected ? accent.opacity(0.6) : Theme.separator, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(feed.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct ToggleRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: Spacing.m) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
    }
}

/// Mock story row used in the onboarding live preview.
private struct OnboardingPreviewRow: View {
    let accent: Color
    var showThumbnail: Bool = true
    var showRank: Bool = true
    var underlineLinks: Bool = true
    var urlAboveTitle: Bool = false

    private var hostLabel: some View {
        Text("paulgraham.com")
            .font(AppFont.meta)
            .foregroundStyle(Theme.textSecondary)
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            if showRank {
                // Mirror StoryRow: when the URL sits above the title, shrink the
                // rank and top-align it so they share the first line.
                Text("42")
                    .font(urlAboveTitle ? AppFont.meta : .system(.footnote, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 22, alignment: .trailing)
                    .padding(.top, urlAboveTitle ? 0 : 2)
            }
            if showThumbnail {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(accent.opacity(0.16))
                    .frame(width: 38, height: 38)
                    .overlay(Image(systemName: "flame.fill").foregroundStyle(accent))
            }
            VStack(alignment: .leading, spacing: 5) {
                if urlAboveTitle { hostLabel }
                Text("How to Do Great Work")
                    .font(AppFont.storyTitle)
                    .foregroundStyle(Theme.textPrimary)
                if !urlAboveTitle { hostLabel }
                HStack(spacing: Spacing.m) {
                    StatLabel(systemImage: "arrow.up", value: "842", tint: Theme.upvote)
                    StatLabel(systemImage: "bubble.left", value: "312")
                    Text("pg")
                    Text("1h")
                }
                .font(AppFont.meta)
                .foregroundStyle(Theme.textSecondary)
                Text("paulgraham.com/greatwork.html")
                    .font(AppFont.meta)
                    .foregroundStyle(accent)
                    .underline(underlineLinks)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}
