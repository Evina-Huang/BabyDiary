# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project

iOS-only SwiftUI app for logging baby-care events (feed / diaper / sleep / solids, plus vaccines and growth). UI is Chinese (`zh_CN`). All data is in-memory — there is no persistence layer; `AppStore.seed()` populates demo data on launch.

## Build / test

The Xcode project is **generated from `project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen)**. If you edit `project.yml` (or add source files in a way that would change the project), regenerate:

```bash
xcodegen generate
```

Build & test from the command line:

```bash
# Build
xcodebuild -project BabyDiary.xcodeproj -scheme BabyDiary \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# Full test suite
xcodebuild -project BabyDiary.xcodeproj -scheme BabyDiary \
  -destination 'platform=iOS Simulator,name=iPhone 17' test

# Single test (Swift Testing — match by test name, not XCTest method path)
xcodebuild -project BabyDiary.xcodeproj -scheme BabyDiary \
  -destination 'platform=iOS Simulator,name=iPhone 17' test \
  -only-testing:BabyDiaryTests/BabyDiaryTests/eventCreation
```

Tests use the **Swift Testing** framework (`import Testing`, `@Test`, `#expect`) — not XCTest. Follow that style when adding tests in `BabyDiaryTests/`.

Target: iOS 18, Swift 5.10, Xcode 16. Bundle ID `com.evina.BabyDiary`, team `5WF2DNSHC6`.

## Architecture

**State flow.** A single `@Observable` class `AppStore` ([BabyDiary/Sources/App/AppStore.swift](BabyDiary/Sources/App/AppStore.swift)) holds all app state (`baby`, `events`, `vaccines`, `growth`, `theme`, `timerStart`). It is created once in [BabyDiaryApp.swift](BabyDiary/Sources/App/BabyDiaryApp.swift) and injected with `.environment(store)`. Views read it with `@Environment(AppStore.self) private var store`. This is the iOS 17+ Observation API — **do not** use `ObservableObject` / `@Published` / `@StateObject`; follow the existing pattern.

Mutations go through store methods (`addEvent`, `deleteEvent`, `toggleVaccine`, `addGrowth`). Screens should not mutate `store.events` etc. directly.

**Navigation.** `ContentView` owns two pieces of state: the current `MainTab` (home / records / growth / stats) and an optional `SubScreen` (sleep / feed / diaper / solid / vaccine) presented as a sheet. Tab switching is handled by the **custom** floating `AppTabBar` — there is no `TabView`. Sub-screens are opened by calling the `onOpen:` closure passed down from `ContentView` to `HomeView` (and `onOpenVaccines` from `GrowthView`).

**Layer layout.**
- `Sources/App/` — entry point, `AppStore`, `ContentView` + tab bar, `Theme.swift` (color tokens `Palette.*`, `AppTheme` enum with 4 skins, shadow view modifiers, `Color(hex:)` helper).
- `Sources/Models/` — plain value types: `Event` + `EventKind`, `Vaccine` + `VaccineStatus`, `GrowthPoint`, `Baby`.
- `Sources/Components/` — shared building blocks used by every screen:
  - `Primitives.swift` — `ScreenHeader`, `ScreenBody`, `Card`, `CTAButton`, `SegPill`, `FormField`, `EventRow`, `SinceLastBanner`, `EmptyStateView`, `PressableStyle`, plus the Chinese formatters `formatTime` / `formatDur` / `formatDurShort` / `formatDateLabel`.
  - `Icons.swift` — the `AppIcon.*` set. Icons are **drawn as `Canvas` paths** on a 24×24 / 32×32 grid to match the original React/CSS design exactly. Prefer reusing these over SF Symbols; add new ones in the same style if needed. Also contains `CategoryStyle.forKind(_:iconSize:)`, a factory that maps `EventKind` → `(label, tint, ink, icon)` — every view that renders a category color should call this instead of reimplementing the mapping.
- `Sources/Views/` — one file per feature screen (`HomeView`, `RecordsView`, `GrowthView`, `StatsView`, and the modal sheet screens `SleepScreen`, `FeedScreen`, `DiaperScreen`, `SolidScreen`, `VaccineScreen`). Note: `TabTitleHeader` (the kicker + large-title header used by the tab screens) is defined at the bottom of `GrowthView.swift` but is shared across RecordsView, StatsView, and GrowthView.
- `Sources/ViewModels/` — currently empty; logic lives in the store or inline in views.

**Theming.** Never hard-code brand colors. Primary color comes from `store.theme.primary` / `primary600` / `primaryTint` (4 skins in `AppTheme`). Neutrals and category accents come from `Palette.*`. Shadows come from the `.shadowCard()` / `.shadowSurface()` / `.shadowPill(tint:)` view modifiers — they encode the design's two-layer soft shadows and should be used instead of raw `.shadow(...)`.

**Styling conventions, from the existing code.** Typography is `.system(size:weight:)` with negative `tracking` on headings and `0.6–0.72` tracking + `.textCase(.uppercase)` on micro-labels (see `MicroLabel`). Screens follow `ScreenHeader` + `ScreenBody` + `Card(...)` composition. Tap affordance is `PressableStyle` (0.97 scale). The design is a port of a React/CSS reference, so matching the existing visual tokens matters more than inventing new ones.
