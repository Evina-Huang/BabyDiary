# AGENTS.md

This file provides guidance to Codex when working with code in this repository.

## Project

BabyDiary is a Chinese-first, iOS-only SwiftUI app for recording baby care. It covers feeding, sleep, diapers, solids, growth, vaccines, medication, food observation, recipes, teeth, and milestones. It also includes reminders, widgets, Live Activities, App Shortcuts, local backup/restore, and PDF export.

Target: iOS 18, Swift 5.10, Xcode 16. Bundle ID `com.evina.BabyDiary`, team `5WF2DNSHC6`.

## Build and test

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen). If `project.yml`, target membership, resources, or source layout changes, regenerate it:

```bash
xcodegen generate
```

Build and test from the command line:

```bash
# Build
xcodebuild -project BabyDiary.xcodeproj -scheme BabyDiary \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# Full test suite
xcodebuild -project BabyDiary.xcodeproj -scheme BabyDiary \
  -destination 'platform=iOS Simulator,name=iPhone 17' test

# Single Swift Testing test (match by test name)
xcodebuild -project BabyDiary.xcodeproj -scheme BabyDiary \
  -destination 'platform=iOS Simulator,name=iPhone 17' test \
  -only-testing:BabyDiaryTests/BabyDiaryTests/eventCreation
```

Tests use Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest. Follow that style in `BabyDiaryTests/`.

## Runtime and persistence

`BabyDiaryApp.swift` creates one `AppStore` with `AppStore.loadedOrSeeded()` and injects it through `.environment(store)`. Views read it with:

```swift
@Environment(AppStore.self) private var store
```

Use the iOS Observation API (`@Observable`). Do not introduce `ObservableObject`, `@Published`, or `@StateObject` for app state.

The app is local-first, not memory-only:

- `Backup.swift` persists a Codable `DataSnapshot` as `BabyDiary.json` in the app Documents directory.
- The snapshot includes domain data, active sleep/feed state, reminder settings, recent formula amounts, appearance, and theme.
- Mutations normally call `persist()` through `AppStore` methods.
- JSON export/import is backup and full replacement, not merge.
- PDF export is a readable report, not a medical record.
- A recovery copy is maintained as `BabyDiary.previous.json` when appropriate.
- A normal real-device start uses empty personal data. Simulator builds merge dedicated demo data for UI testing.

When adding persisted state, update `DataSnapshot`, `snapshot()`, `apply(_:)`, migration defaults, and relevant tests together. New optional snapshot fields should decode older backups safely.

## State and mutation rules

`AppStore.swift` is the single state center. It owns:

- Baby profile and appearance: `baby`, `theme`, `appearance`
- Daily records: `events`
- Health and growth: `vaccines`, `growth`, `foods`, `recipes`, `medications`, `teeth`, `milestones`
- Active care: `activeTimer`, `feedDraft`
- Reminders and convenience state: `feedReminder`, `sleepReminder`, `formulaMlHistory`

Prefer store methods such as `addEvent`, `updateEvent`, `deleteEvent`, `updateBaby`, `addGrowth`, `updateVaccine`, `recordSolidFood`, and the reminder update methods. Views should not directly mutate store collections or manually reimplement persistence side effects.

`Event` is the common timeline model for feeding, sleep, diapers, and solids. Long-lived or specialist records use dedicated models (`Vaccine`, `GrowthPoint`, `FoodItem`, `Recipe`, `MedicationRecord`, `ToothRecord`, `Milestone`). Before adding a new feature, decide whether it belongs in the event timeline or in a specialist model.

## Navigation

`ContentView` owns the current `MainTab` and optional `SubScreen`. It uses the custom `AppTabBar`; there is no `TabView`.

The four main tabs are:

- `home`
- `records`
- `growth`
- `health`

Sheets are represented by `SubScreen`: night quick record, sleep, feed, diaper, solids, vaccines, medication, food list, recipes, teeth, settings, and backup. Open these through the closures passed by `ContentView` instead of creating a second navigation source of truth.

Deep links, notifications, widgets, and App Shortcuts route back through destinations handled by `ContentView` and the shared types in `Sources/Shared/`.

## Source layout

- `BabyDiary/Sources/App/` — app entry, global store, persistence/export, navigation, themes, reminders, Live Activity controllers.
- `BabyDiary/Sources/Models/` — value models for events, health, growth, food, recipes, teeth, and milestones.
- `BabyDiary/Sources/Components/` — reusable UI primitives, accessibility helpers, formatting, record feedback, and custom icons.
- `BabyDiary/Sources/Shared/` — data and ActivityAttributes shared by the app and widget extension.
- `BabyDiary/Sources/Views/` — tab screens, record sheets, settings, and feature screens.
- `BabyDiaryWidgets/` — configurable widgets and feed/sleep Live Activities.
- `BabyDiaryTests/` — Swift Testing coverage for state, persistence compatibility, reminders, shortcuts, summaries, and health flows.

## UI and theming

Match the existing light, warm, status-first design language.

- Never hard-code brand colors. Use `store.theme`, `Palette.*`, and semantic surface/text roles from `Theme.swift`.
- Use `.shadowCard()`, `.shadowSurface()`, and `.shadowPill(tint:)` instead of ad-hoc shadows.
- Reuse `ScreenHeader`, `ScreenBody`, `Card`, `CTAButton`, `SegPill`, `FormField`, `EventRow`, save bars, toasts, and accessibility helpers from `Primitives.swift`.
- Prefer the Canvas icons in `AppIcon` over unrelated SF Symbols. Category rendering should use `CategoryStyle.forKind(_:iconSize:)`.
- Preserve typography conventions: system fonts, tight tracking on headings, uppercase micro-labels with wider tracking.
- Use `PressableStyle` for matching tap feedback.
- Preserve Dynamic Type, VoiceOver labels/status, Reduce Motion handling, large-screen, compact-screen, and landscape behavior.

Visual consistency with the existing React/CSS-derived design tokens matters more than introducing a new component style.

## Safety boundaries

- Health, vaccination, medication, allergy, and growth information is record-keeping only; do not present it as diagnosis or medical advice.
- Keep app and widget App Group identifiers aligned when changing entitlements or bundle identifiers.
- Reminder scheduling changes should continue respecting authorization, quiet hours, and cancellation behavior.
- Active timer/feed changes should remain consistent across persistence, widgets, Live Activities, shortcuts, and in-app status surfaces.
