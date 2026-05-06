# Pan3 Project Context

## Scope

The full rewrite targets the main iPhone app. Treat Watch App, iOS Widget, Watch Widget, Live Activities, App Intents, and Push Service as compatibility targets unless the user explicitly asks to rewrite them.

Current project shape:

- Main app: `Pan3`
- Watch app: `Car Watch App`
- iOS widget: `CarWidget`
- Watch widget: `CarWatchWidget`
- Live Activities: `LiveActivities`
- Push service extension: `Pan3PushService`
- Shared code: `Shared`

## Rewrite Direction

The main app should move away from:

- UIKit view controllers
- `Main.storyboard`
- QMUIKit
- SnapKit
- MJRefresh
- IQKeyboardManager
- SwiftyJSON
- Core Data as app-facing persistence

The rewritten main app should move toward:

- SwiftUI App lifecycle
- iOS 17+ SwiftUI APIs with iOS 26 Liquid Glass as the preferred visual system
- Observation
- SwiftData
- URLSession with async/await
- Codable models
- Swift Charts
- SwiftUI MapKit APIs
- Keychain sharing for secrets
- App Group snapshots for extension display

## Liquid Glass Direction

Use iOS 26 Liquid Glass for new main-app UI where it improves hierarchy and interaction. Keep all Liquid Glass usage availability-gated with iOS 17 fallbacks.

Recommended Pan3 targets:

- Login form and primary login action.
- Vehicle range/SOC hero card.
- Vehicle action controls: lock, AC, windows, honk.
- Vehicle status groups for windows, doors, and tire pressure.
- Compact floating actions and toolbar-like surfaces.

Do not use Liquid Glass as a blanket background. Vehicle data readability is more important than decorative depth.

## Persistent Data

Existing Core Data entities include:

- `TripRecord`
- `TripDataPoint`
- `ChargeRecord`
- `ChargeDataPoint`

The SwiftData replacement should preserve domain meaning, not necessarily class names. Prefer new model names that reflect business concepts clearly, such as:

- `StoredTrip`
- `StoredTripPoint`
- `StoredChargeSession`
- `StoredChargePoint`

Use domain IDs for upserts:

- `vin`
- `clientTripID`
- `clientChargeID`
- `timestampMs`
- server record identifiers when available

If preserving user history matters, create a migration path:

1. Open old Core Data store read-only.
2. Read old trips, charges, and points in batches.
3. Upsert into SwiftData using domain IDs.
4. Mark migration completion in a non-secret local flag.
5. Keep migration retryable and idempotent.

## Shared Data Contracts

Do not scatter raw App Group keys. Centralize keys and payload types under `SharedContracts`.

Recommended contracts:

- `SharedCarSnapshot`: current vehicle display state for Widget, App Intents, and Live Activities.
- `SharedAuthSnapshot`: non-secret login/display metadata only.
- `SharedRefreshRequest`: extension-to-app refresh hints if needed.
- `LiveActivityPayload`: typed ActivityKit input data.

Use Keychain access groups for tokens. Do not write tokens or passwords to App Group `UserDefaults`.

## Watch And Widget Compatibility

Watch remains based on WatchConnectivity and/or direct network refresh. SwiftUI does not replace `WCSession`.

Widgets and Live Activities should read compact snapshots, not query the full app database by default.

When a shared payload changes:

1. Update the Codable contract.
2. Keep backward-compatible decoding if users may still have old snapshots.
3. Update main app writers.
4. Update Widget, Watch, App Intents, and Live Activity readers.
5. Build all affected targets.

## Native-First Dependency Policy

Do not add dependencies to the rewritten main app unless the task documents why Apple-native APIs are insufficient.

Default replacements:

- Alamofire -> `URLSession`, `URLRequest`, async/await.
- SwiftyJSON -> `Codable`, `JSONDecoder`, custom decoding.
- SnapKit -> SwiftUI layout.
- MJRefresh -> `.refreshable`, `.task`, pagination state.
- Charts or DGCharts -> Swift Charts.
- UIKit map wrappers -> SwiftUI `Map` unless a specific MapKit feature requires a wrapped view.
- IQKeyboardManager -> `FocusState`, `.submitLabel`, `.scrollDismissesKeyboard`.
- Custom blur surfaces -> native iOS 26 Liquid Glass APIs with iOS 17 material fallback.
