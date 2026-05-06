---
name: pan3-swiftui-ios17
description: Strict Pan3 main iOS app rewrite rules for SwiftUI-first, iOS 17+ implementation with iOS 26 Liquid Glass as the preferred visual system. Use when Codex creates, refactors, reviews, or migrates the Pan3 main app, app shell, navigation, screens, state, persistence, networking, or shared app services to modern SwiftUI, Observation, SwiftData, async/await, Liquid Glass, and Apple-native APIs; enforce no legacy UIKit/storyboard/Core Data UI-era patterns unless explicitly isolated for migration.
---

# Pan3 SwiftUI iOS 17 Plus Liquid Glass

## Core Contract

Build the Pan3 main iOS app as a clean iOS 17+ SwiftUI app with an iOS 26-first Liquid Glass visual direction. Treat old UIKit code as reference behavior, not architecture to preserve. Prefer Apple-native frameworks and the newest stable API available for the configured deployment target.

Before using a SwiftUI, Liquid Glass, SwiftData, Observation, WidgetKit, ActivityKit, App Intents, MapKit, or CloudKit API whose best practice may have changed, verify current Apple Developer documentation. If the existing code and Apple guidance conflict, follow Apple guidance and call out the migration impact.

Read `references/project-context.md` before major app-shell, persistence, shared-data, widget, watch, or Live Activity work.
Read `references/liquid-glass.md` before new screen implementation or any visual refactor.

## Non-Negotiable Requirements

- Set the main app deployment target to iOS 17.0 or newer.
- Prefer iOS 26 Liquid Glass APIs for new visual surfaces, controls, tab-adjacent chrome, floating actions, and status cards, with iOS 17 fallback UI.
- Use SwiftUI App lifecycle for the rewritten main app.
- Use SwiftData as the app database for new persistent models.
- Use Observation (`@Observable`, `@State`, `@Environment`) for app and feature state.
- Use `async/await`, structured concurrency, and `URLSession` for new service code.
- Use enum-driven `NavigationStack`, `TabView`, `.sheet(item:)`, and typed routing.
- Use Apple-native frameworks first: SwiftUI, SwiftData, Swift Charts, MapKit, ActivityKit, WidgetKit, App Intents, WatchConnectivity, Security, UserNotifications.
- Keep Widget, Watch, Live Activity, App Intents, and Push Service targets compatible through explicit shared data contracts.
- Add previews, mock services, loading states, empty states, error states, accessibility identifiers, and both iOS 26 glass/fallback visual coverage for new user-facing SwiftUI screens.

## Forbidden In New Main App Code

Do not introduce these unless the user explicitly asks for a temporary migration adapter:

- `UIKit` screens, `UIViewController`, `UITableViewController`, `UICollectionViewController`, storyboards, xibs, segues, Auto Layout constraint code, `UIHostingController` as main architecture.
- Legacy SwiftUI navigation and lifecycle APIs: `NavigationView`, `NavigationLink(destination:isActive:)`, `NavigationLink(tag:selection:)`, `.navigationBarTitle`, `@Environment(\.presentationMode)`, old `.onChange(of:perform:)`, and `UIApplication.shared.windows`.
- `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, and broad `EnvironmentObject` for new iOS 17+ state. Use Observation instead.
- New Core Data entities, `NSManagedObject`, `NSFetchRequest`, `NSPersistentContainer`, or `NSPersistentCloudKitContainer` as the app's primary database API. Use SwiftData.
- Combine pipelines for ordinary app state, networking, or view refreshes. Use async sequences or structured concurrency.
- Third-party UI/layout/refresh/keyboard/JSON libraries in rewritten code, including QMUIKit, SnapKit, MJRefresh, IQKeyboardManager, SwiftyJSON, and SwifterSwift.
- Custom blur/material stacks that imitate Liquid Glass when native `glassEffect`, `GlassEffectContainer`, or glass button styles are available.
- Alamofire for new networking unless an existing endpoint behavior cannot be reproduced safely in the current task.
- `UserDefaults` for passwords, access tokens, refresh tokens, or other secrets. Use Keychain access groups.
- Stringly typed navigation, many boolean sheet flags, global singleton view state, or side effects inside `body`.

## Architecture

Create a thin SwiftUI shell:

- `Pan3App`: app lifecycle, model container, dependency construction.
- `AppRootView`: auth gate, app tabs, high-level routing.
- `AppTab`: enum for tab identity and labels.
- `AppRoute`: enum for pushed destinations.
- `AppSheet`: enum for modal presentation.

Keep feature modules small:

- `Features/Home`
- `Features/Charge`
- `Features/Trips`
- `Features/Settings`
- `Features/Auth`
- `Services`
- `Persistence`
- `SharedContracts`

Views should be declarative and small. Move domain logic into services, repositories, formatters, and SwiftData models. Extract dedicated subviews rather than building huge computed `some View` sections.

## Liquid Glass Visual System

Treat Liquid Glass as the default design language for iOS 26+ while preserving clean iOS 17 fallback behavior:

- Use native Liquid Glass APIs: `glassEffect(_:in:)`, `GlassEffectContainer`, `.buttonStyle(.glass)`, and `.buttonStyle(.glassProminent)`.
- Gate every Liquid Glass API with `if #available(iOS 26, *)` or a small reusable availability wrapper. Never break iOS 17 builds.
- Use `.glassEffect(.regular.interactive(), in: ...)` only for interactive/tappable glass elements. Do not mark passive cards as interactive.
- Wrap groups of nearby glass elements in `GlassEffectContainer` for performance and coherent effect interaction.
- Apply glass modifiers after layout, clipping, and visual styling modifiers.
- Use consistent shapes across related surfaces. Prefer rounded rectangles for cards, capsules for compact controls, and circles for icon-only controls.
- Prefer system navigation, toolbars, sheets, tab bars, and controls because they receive platform-correct Liquid Glass behavior automatically.
- Use `glassEffectID` with `@Namespace` only for deliberate morphing transitions when a glass element changes hierarchy under animation.
- Avoid stacking many translucent surfaces over each other. If content readability drops, reduce tint, increase spacing, or use the fallback material style.
- Keep glass decorative weight lower than vehicle data: range, SOC, lock state, temperature, location, and safety/status indicators must remain instantly readable.

Fallback for iOS 17-25:

- Use `.background(.thinMaterial, in: RoundedRectangle(...))` or `.background(.regularMaterial, in: ...)` for glass-like surfaces.
- Use `.buttonStyle(.bordered)` / `.buttonStyle(.borderedProminent)` when glass button styles are unavailable.
- Keep fallback layout, spacing, accessibility labels, and interactions identical to the iOS 26 version.

## SwiftData Rules

Use SwiftData for the new persistence layer:

- Define `@Model` types for trips, trip points, charge records, charge points, user/session metadata when local persistence is needed.
- Use stable domain IDs such as `vin`, `clientTripID`, `clientChargeID`, `timestampMs`, and server IDs.
- Use `ModelContainer` and `ModelConfiguration` in the app root.
- Use `@Query` only for simple view-local reads. Use repository/service methods for sync, pagination, imports, deletes, and complex predicates.
- Keep CloudKit-compatible models: relationships must tolerate optional/missing related objects, defaults must be explicit, and migrations must be additive unless a destructive reset is intentionally chosen.
- Do not rely on uniqueness constraints for CloudKit conflict resolution. Implement upsert logic in repositories using domain IDs.
- Create a one-time Core Data to SwiftData migration service if old user data must be preserved. Keep old Core Data access read-only and delete the adapter after migration is complete.

## State And Concurrency

Use narrow state ownership:

- Local UI state: `@State`.
- Root-owned observable services/models: `@State`.
- Shared dependencies: custom `@Environment` keys or typed environment injection.
- Child mutation of value state: `@Binding`.
- Editing properties of injected observable models: `@Bindable`.

Use modern SwiftUI equivalents:

- `NavigationStack` plus `.navigationDestination(for:)` instead of `NavigationView`.
- `@Environment(\.dismiss)` instead of `presentationMode`.
- `.onChange(of:initial:)` with the iOS 17 closure forms instead of deprecated `onChange` overloads.
- `ContentUnavailableView` for empty/error surfaces when it fits.
- `scrollPosition`, `scrollTargetLayout`, `containerRelativeFrame`, and `safeAreaInset` for modern scroll/layout behavior where appropriate.
- SwiftUI `Map` with typed camera/selection state before wrapping `MKMapView`.
- iOS 26 Liquid Glass APIs before custom materials for foreground surfaces and controls, with iOS 17 fallback.

Async work must be cancellable and lifecycle-aware:

- Use `.task` and `.task(id:)` for view-driven loading.
- Use explicit `isLoading`, `error`, and retry states.
- Avoid launching untracked `Task` from views except from small action methods.
- Mark UI-bound observable services `@MainActor`.
- Keep network, parsing, and persistence work off the main actor when appropriate.

## Data Sharing

Keep App Groups, WatchConnectivity, and Keychain roles separate:

- App Groups: small non-secret snapshots for Widget, App Intents, Live Activity handoff, and extension display.
- Keychain access groups: secrets and auth tokens.
- WatchConnectivity: iPhone-Watch communication.
- SwiftData/CloudKit: app database and user history.

Do not let extensions depend on full app internals. Share Codable contracts such as `SharedCarSnapshot`, `SharedAuthState`, and Live Activity payloads.

## Migration Workflow

1. Inspect old UIKit behavior and data contracts before writing replacement code.
2. Define the SwiftData models and service boundaries first.
3. Build the SwiftUI shell with auth, tabs, navigation, and dependency injection.
4. Migrate simple screens before complex screens.
5. Rebuild Home, Charge, Trips, and Settings as SwiftUI-native features.
6. Keep Widget, Watch, Live Activity, App Intents, and Push Service targets compiling after each shared-contract change.
7. Remove obsolete dependencies only after no rewritten main-app code imports them.
8. Build and run tests after each meaningful slice.

## Review Checklist

Reject or revise code when any item is true:

- It introduces UIKit/storyboard architecture into the new main app.
- It uses Core Data as the primary database instead of SwiftData.
- It adds a third-party library where an Apple-native iOS 17+ API is sufficient.
- It creates custom blur/glass effects instead of using native iOS 26 Liquid Glass APIs with fallback.
- It uses Liquid Glass without availability gating for iOS 17 compatibility.
- It applies interactive glass to passive content or too many nested glass surfaces that harm readability/performance.
- It uses legacy Observation/Combine patterns for new state.
- It stores secrets in App Groups or `UserDefaults`.
- It makes Widget/Watch/Live Activity data contracts implicit or stringly typed.
- It depends on undocumented behavior or stale API assumptions without checking Apple documentation.
- It lacks loading, empty, error, preview, or accessibility coverage for new UI.
