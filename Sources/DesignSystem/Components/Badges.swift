import SwiftUI

/// An icon + value pill used for points and comment counts. Always pairs an SF
/// Symbol with text so meaning never depends on color alone (color-blind safe).
struct StatLabel: View {
    let systemImage: String
    let value: String
    var tint: Color = Theme.textSecondary

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .imageScale(.small)
            Text(value)
                .font(AppFont.metaStrong)
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .accessibilityElement(children: .ignore)
    }
}

/// Small uppercase category tag (ASK / SHOW / JOB).
struct TagBadge: View {
    let text: String
    var color: Color = Theme.upvote

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .tracking(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous).fill(color.opacity(0.14))
            )
            .overlay(
                Capsule(style: .continuous).strokeBorder(color.opacity(0.22), lineWidth: 1)
            )
    }
}

/// Circular monogram avatar derived deterministically from a username.
struct MonogramAvatar: View {
    let name: String
    var size: CGFloat = 30

    private var initial: String {
        String(name.first?.uppercased() ?? "?")
    }

    private var gradient: LinearGradient {
        let base = Color.deterministic(from: name)
        return LinearGradient(
            colors: [base.opacity(0.95), base.opacity(0.65)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Circle()
            .fill(gradient)
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(.system(size: size * 0.46, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            )
            .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
            .accessibilityHidden(true)
    }
}

/// Numeric rank badge for feed ordering — a non-color cue for position.
struct RankBadge: View {
    let rank: Int
    var body: some View {
        Text("\(rank)")
            .font(.system(.footnote, design: .rounded).weight(.bold))
            .monospacedDigit()
            .foregroundStyle(Theme.textTertiary)
            .frame(minWidth: 22, alignment: .trailing)
            .accessibilityHidden(true)
    }
}

extension Color {
    /// Stable, pleasant color derived from a string (used for avatars).
    /// Uses an FNV-1a hash so the color is identical across app launches
    /// (Swift's `Hasher` is per-process randomized and would not be stable).
    static func deterministic(from string: String) -> Color {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        let hue = Double(hash % 360) / 360
        return Color(hue: hue, saturation: 0.55, brightness: 0.72)
    }
}
