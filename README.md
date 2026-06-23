<div align="center">

# Ember

**A native Hacker News reader for iPhone, iPad, and Mac — calm, fast, and built for everyone.**

Ember is a SwiftUI app that reads Hacker News the way a native app should:
threaded comments rendered natively, clean reading typography, a personalized
first-run setup, full dark mode, offline reading, and accessibility treated as a
feature rather than an afterthought. One codebase adapts from a tab bar on
iPhone to a three-pane layout on Mac and iPad — and an experimental Android
build shares the same Swift via [Skip](https://skip.dev).

![Platform](https://img.shields.io/badge/platform-iPhone%20%C2%B7%20iPad%20%C2%B7%20Mac%20%C2%B7%20Android-black)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue)
![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

<img src="docs/screenshots/feed.png" width="250" alt="Story feed">
<img src="docs/screenshots/detail.png" width="250" alt="Story detail with threaded comments">
<img src="docs/screenshots/onboarding-accent.png" width="250" alt="Personalization onboarding">

</div>

## Highlights

- **Every feed** — Top, New, Best, Ask HN, Show HN, and Jobs, switchable from a pinned filter bar.
- **Native comment threads** — Hacker News comment HTML is parsed into native text with tappable links, italics, block quotes, and code blocks. Threads are collapsible with depth indicators, and the whole tree loads in a single request.
- **Smart onboarding** — a short first-run flow that reads your device's appearance and accessibility settings, pre-configures the app to match, and shows a live preview as you choose a theme, accent, and home feed.
- **Search** — full-text search across Hacker News by relevance or recency.
- **Saved for later** — bookmark any story; saved stories are stored on device and work offline.
- **Offline reading** — feeds, stories, and comment threads you've viewed are cached to disk, so Ember keeps working without a connection and falls back to the cache automatically. Cache size is shown in Settings and can be cleared.
- **Read tracking** — visited stories are dimmed so you can pick up where you left off.
- **Runs on the desktop** — the same app runs on Mac (via Mac Catalyst) and large iPad with a native three-pane layout: a source-list sidebar, a story list, and the discussion side by side.
- **Reading typography** — body and comments are set in Inter with comfortable leading and a constrained measure, so long threads are easy to read.
- **Adjustable text size** — tune reading text in Settings, or pinch-to-zoom right in a discussion (on top of Dynamic Type).
- **In-app reading** — open links in an in-app Safari view with optional Reader mode, or hand off to your default browser.
- **Share** — a standard share button on every story (article or discussion link).
- **Profiles** — view any user's karma, join date, about, and recent submissions.
- **Thoughtful design** — a warm, hand-tuned color system, full light/dark support, six accent themes, haptics, and fluid animations.

## Accessibility

Accessibility is a first-class part of Ember, with particular care for color vision.

- **Never color alone.** Status is always carried by an icon, shape, or text in addition to color — points and comment counts pair an SF Symbol with their value, read state shows a checkmark, and selection states use rings and checkmarks.
- **Color-blind friendly cues.** A dedicated setting (auto-enabled when the system "Differentiate Without Color" is on) adds explicit non-color indicators throughout.
- **VoiceOver.** Story rows, comments, and controls expose meaningful labels, hints, traits, and custom actions; each story reads as a single coherent element.
- **Dynamic Type.** Typography scales with the system text size, and layouts — including comment indentation — adapt at accessibility sizes.
- **Reduce Motion.** Animations and the loading shimmer are minimized when Reduce Motion is enabled.
- **Underlined links.** Links in comments can be underlined so they remain identifiable without relying on color.
- **The onboarding adapts.** On first launch Ember detects VoiceOver, Reduce Motion, Differentiate Without Color, Bold Text, and large text, turns on the matching options, and tells you exactly what it changed.

## Screenshots

| Feed | Story & comments | Search |
| :---: | :---: | :---: |
| <img src="docs/screenshots/feed.png" width="230"> | <img src="docs/screenshots/detail.png" width="230"> | <img src="docs/screenshots/search.png" width="230"> |

| Settings | Onboarding · welcome | Onboarding · accessibility |
| :---: | :---: | :---: |
| <img src="docs/screenshots/settings.png" width="230"> | <img src="docs/screenshots/onboarding-welcome.png" width="230"> | <img src="docs/screenshots/onboarding-accessibility.png" width="230"> |

## Architecture

Ember is pure SwiftUI with no third-party dependencies.

- **UI:** SwiftUI, targeting iOS 18, with a Mac build via Mac Catalyst. The root layout adapts on horizontal size class: a `TabView` on iPhone, a three-column `NavigationSplitView` on Mac and regular-width iPad.
- **State:** the Observation framework (`@Observable`) for view models and stores.
- **Concurrency:** `async`/`await` networking; feed pages fetch concurrently with `TaskGroup` and tolerate individual missing items.
- **Persistence & offline:** `UserDefaults` for settings and read state; a JSON file for saved stories; a bounded JSON disk cache (`DiskCache`, an `actor`) that stores feed lists, items, and comment trees and is served as a fallback when the network is unavailable.
- **Typography:** the bundled Inter variable font for reading text, scaled with Dynamic Type; the system font for dense metadata and code.
- **Data sources:**
  - The official [Hacker News Firebase API](https://github.com/HackerNews/API) for feeds, items, and users.
  - The [Algolia HN Search API](https://hn.algolia.com/api) for full comment trees (one request per thread) and search.

### Project layout

```
Sources/
  App/              App entry, root tab view, environment wiring, in-app Safari
  Models/           HNItem, HNUser, Feed, Algolia models
  Networking/       HNService protocol, live client, mock for previews
  Stores/           Settings, bookmarks, read state
  DesignSystem/     Theme, typography, haptics, reusable components
  Utilities/        HTML comment renderer, relative time
  Features/
    Feed/           Feed list, filter bar, view model
    StoryDetail/    Story header + threaded collapsible comments
    Search/         Search with relevance/recency
    Saved/          Bookmarks
    Settings/       Appearance, reading, accessibility, data, about
    User/           Profiles
    Onboarding/     Smart first-run personalization
    Desktop/        NavigationSplitView layout for Mac / large iPad
Resources/          Assets, app icon, Info.plist, bundled Inter font
Tools/              Icon generator, screenshot device-framer
EmberSkip/          Android app (Skip — SwiftUI transpiled to Jetpack Compose)
```

## Android (experimental, via Skip)

`EmberSkip/` is an Android build of Ember using [Skip](https://skip.dev), which
transpiles SwiftUI to Kotlin / Jetpack Compose. It shares the design and reuses
the same Hacker News Firebase + Algolia APIs, and currently covers the feed
(all six lists), story detail with the linked article, and a fetched, threaded
comment view — all written in Swift.

| Android · feed | Android · story & comments |
| :---: | :---: |
| <img src="docs/screenshots/android-feed.png" width="230"> | <img src="docs/screenshots/android-detail.png" width="230"> |

Build the APK (requires the Skip toolchain — `brew install skiptools/skip/skip`,
plus a JDK and the Android SDK; run `skip checkup` to verify):

```bash
cd EmberSkip
swift build                          # transpiles Swift -> Kotlin
cd Android && gradle assembleDebug   # -> .build/Android/app/outputs/apk/debug/app-debug.apk
```

This is an early port: the polished iOS/Mac chrome (custom theme, onboarding,
offline cache, settings) is not yet brought across, and Android uses plain text
where iOS uses SF Symbols. The shared data layer (models, networking, comment
parsing) is the same Swift on both platforms.

## Getting started

### Requirements

- macOS with Xcode 16 or newer (built and tested against Xcode 26 / iOS 26 SDK).
- [XcodeGen](https://github.com/yonsm/XcodeGen) to generate the project: `brew install xcodegen`.

### Build and run

```bash
# 1. Generate the Xcode project from project.yml
xcodegen generate

# 2. Open it
open Ember.xcodeproj

# 3. Select the Ember scheme and an iPhone simulator, then Run.
```

Or build from the command line:

```bash
xcodegen generate

# iPhone / iPad simulator
xcodebuild -project Ember.xcodeproj -scheme Ember \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Mac (Mac Catalyst)
xcodebuild -project Ember.xcodeproj -scheme Ember \
  -destination 'platform=macOS,variant=Mac Catalyst' build
```

The generated `Ember.xcodeproj` is intentionally git-ignored — regenerate it with `xcodegen generate` after pulling.

### Signing for device builds

The simulator build above needs no signing. To build and run **signed code on a
physical device** with a paid Apple Developer account, edit `project.yml` to use
your own identifiers before regenerating the project:

- Set `DEVELOPMENT_TEAM` to your 10-character Team ID (find it in Xcode ▸
  Settings ▸ Accounts, or in the Apple Developer portal). It ships empty.
- Change `options.bundleIdPrefix` and the target's `PRODUCT_BUNDLE_IDENTIFIER`
  to a bundle ID you own (e.g. `com.yourname.ember`).

`project.yml` does **not** force `CODE_SIGNING_ALLOWED`/`CODE_SIGNING_REQUIRED`
to `NO`, so signing happens normally for device builds while the simulator build
still works without any team set.

After editing, regenerate the project:

```bash
xcodegen generate
```

### Regenerating assets

```bash
swift Tools/GenerateIcon.swift                                   # app icon
swift Tools/FrameScreenshot.swift in.png docs/screenshots/x.png  # device-framed screenshot
```

## Design notes

- The comment HTML renderer is a small purpose-built parser for the limited tag set Hacker News emits (`<p>`, `<i>`, `<b>`, `<a>`, `<pre><code>`, `<br>`, and entities), producing native `AttributedString` blocks rather than relying on a web view.
- The full comment tree is fetched from Algolia in one request and flattened into a list with depth, so collapsing a thread is instant.
- Colors are appearance-adaptive tokens defined in code, so light and dark are both deliberately tuned rather than auto-derived.

## Privacy

Ember reads from the official, public Hacker News APIs — the
[Firebase API](https://github.com/HackerNews/API) for feeds, items, and users,
and the [Algolia HN Search API](https://hn.algolia.com/api) for comment trees and
search. The app collects no personal data, contains no analytics or tracking
SDKs, and stores everything (settings, saved stories, read state, the offline
cache) locally on device. This is declared in
[`Resources/PrivacyInfo.xcprivacy`](Resources/PrivacyInfo.xcprivacy).

Signing in to a Hacker News account is **optional and off by default**. When you
enable it, login happens on `news.ycombinator.com` inside a secure web view —
your password is never seen by Ember; only the resulting login session is stored
in your device Keychain, and upvoting, commenting, favoriting, and submitting are
performed on Hacker News's own pages on your behalf. Because those actions act on
your real account, using them is subject to the
[Hacker News guidelines and terms](https://news.ycombinator.com/newsguidelines.html);
following them is your responsibility.

## Acknowledgements

- [Hacker News](https://news.ycombinator.com) and its public [Firebase API](https://github.com/HackerNews/API).
- [Algolia](https://hn.algolia.com/api) for Hacker News search and comment data.

Ember is an independent project and is not affiliated with Hacker News or Y Combinator.

## License

Released under the [MIT License](LICENSE).
