<div align="center">

# Ember

**A native Hacker News reader for iOS — calm, fast, and built for everyone.**

Ember is a SwiftUI app that reads Hacker News the way a native iOS app should:
threaded comments rendered natively, a personalized first-run setup, full
dark mode, and accessibility treated as a feature rather than an afterthought.

![Platform](https://img.shields.io/badge/platform-iOS%2018%2B-black)
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
- **Read tracking** — visited stories are dimmed so you can pick up where you left off.
- **In-app reading** — open links in an in-app Safari view with optional Reader mode, or hand off to your default browser.
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

- **UI:** SwiftUI, targeting iOS 18.
- **State:** the Observation framework (`@Observable`) for view models and stores.
- **Concurrency:** `async`/`await` networking; feed pages fetch concurrently with `TaskGroup` and tolerate individual missing items.
- **Persistence:** `UserDefaults` for settings and read state; a JSON file for saved stories.
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
Resources/          Assets, app icon, Info.plist
Tools/              Icon generator, screenshot device-framer
```

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
xcodebuild -project Ember.xcodeproj -scheme Ember \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

The generated `Ember.xcodeproj` is intentionally git-ignored — regenerate it with `xcodegen generate` after pulling.

### Regenerating assets

```bash
swift Tools/GenerateIcon.swift                                   # app icon
swift Tools/FrameScreenshot.swift in.png docs/screenshots/x.png  # device-framed screenshot
```

## Design notes

- The comment HTML renderer is a small purpose-built parser for the limited tag set Hacker News emits (`<p>`, `<i>`, `<b>`, `<a>`, `<pre><code>`, `<br>`, and entities), producing native `AttributedString` blocks rather than relying on a web view.
- The full comment tree is fetched from Algolia in one request and flattened into a list with depth, so collapsing a thread is instant.
- Colors are appearance-adaptive tokens defined in code, so light and dark are both deliberately tuned rather than auto-derived.

## Acknowledgements

- [Hacker News](https://news.ycombinator.com) and its public [Firebase API](https://github.com/HackerNews/API).
- [Algolia](https://hn.algolia.com/api) for Hacker News search and comment data.

Ember is an independent project and is not affiliated with Hacker News or Y Combinator.

## License

Released under the [MIT License](LICENSE).
