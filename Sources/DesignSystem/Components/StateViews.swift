import SwiftUI

// MARK: - Shimmer (Reduce Motion aware)

private struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        if reduceMotion {
            content.opacity(0.6)
        } else {
            content
                .overlay(
                    GeometryReader { geo in
                        let width = geo.size.width
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.35), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: width * 0.6)
                        .offset(x: phase * width * 1.6)
                        .blendMode(.overlay)
                    }
                )
                .mask(content)
                .onAppear {
                    withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        }
    }
}

extension View {
    func shimmering() -> some View { modifier(Shimmer()) }
}

// MARK: - Skeleton placeholder rows

struct SkeletonStoryRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Theme.surfacePressed)
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: Spacing.s) {
                RoundedRectangle(cornerRadius: 5).fill(Theme.surfacePressed).frame(height: 14)
                RoundedRectangle(cornerRadius: 5).fill(Theme.surfacePressed).frame(width: 200, height: 14)
                RoundedRectangle(cornerRadius: 5).fill(Theme.surfacePressed).frame(width: 140, height: 11)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, Spacing.s)
        .shimmering()
        .accessibilityHidden(true)
    }
}

struct SkeletonList: View {
    var count = 8
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonStoryRow()
                    .padding(.horizontal, Spacing.l)
                Divider().background(Theme.hairline)
            }
        }
        .padding(.top, Spacing.s)
    }
}

// MARK: - Error & empty states

struct ErrorStateView: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text("Something went wrong")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            if let retry {
                Button(action: {
                    Haptics.tap()
                    retry()
                }) {
                    Label("Try Again", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, Spacing.l)
                        .padding(.vertical, Spacing.s)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .padding(.top, Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .accessibilityElement(children: .combine)
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: systemImage)
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(Theme.textTertiary)
                .accessibilityHidden(true)
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
        .accessibilityElement(children: .combine)
    }
}
