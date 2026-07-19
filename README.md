# SplitPals

A native iOS app for splitting expenses with friends and groups. Track shared costs, see who owes what, and get a minimal set of suggested payments to settle up.

## Features

- **Expense groups** — create named groups with a custom icon and colour gradient (trip, flat, event, etc.)
- **Flexible splitting** — split equally among any subset of members, or enter exact amounts manually
- **Settle Up** — per-group balance view with a greedy-minimised payment suggestion list (fewest transfers to clear all debts)
- **Multi-currency** — 18 currencies supported; live exchange rates fetched from [Frankfurter](https://frankfurter.dev) and cached for 24 hours so the app works offline
- **Friends list** — reusable contacts that can be added to any group
- **Dark mode** — opt-in from Settings
- **Sign in with Apple / Google** — cloud identity against the same Supabase project as the [SplitPals web app](https://github.com/altiusx/splitpals-online-beta), from Settings

## Tech Stack

| | |
|---|---|
| Language | Swift 5 |
| UI | SwiftUI |
| Persistence | Core Data (CloudKit-ready) |
| Async | Swift Concurrency (`async`/`await`) |
| External API | Frankfurter (FX rates, public, no key needed) |
| Auth | [supabase-swift](https://github.com/supabase/supabase-swift) — Sign in with Apple (native) + Google (Supabase-hosted OAuth) |
| Dependencies | supabase-swift (Swift Package Manager) |
| Minimum OS | iOS 26 |

## Getting Started

**Requirements:** macOS with a recent Xcode beta that supports the iOS 26 SDK.

1. Clone the repo and open `SplitPals.xcodeproj` in Xcode.
2. Select an iOS 26 simulator or device from the scheme selector.
3. Press **Cmd+R** to build and run — Xcode resolves the `supabase-swift` package automatically on first build.

No API keys or environment variables are needed; the Supabase project URL and publishable key live in `Services/SupabaseConfig.swift` (safe to commit — same trust model as a web anon key).

### Auth setup (Supabase dashboard)

Sign-in only works once the Supabase project has both providers enabled and this app's redirect URL allow-listed:

1. **Authentication → Providers**: enable **Google** (reuses the same OAuth client already configured for the web app) and **Apple**.
2. **Authentication → URL Configuration**: add `com.chrischoong.splitpals://auth-callback` to the redirect URL allow list — this is where Google's OAuth flow redirects back into the app via `ASWebAuthenticationSession`.
3. In Xcode, under the SplitPals target's **Signing & Capabilities**, confirm **Sign in with Apple** is enabled (the entitlement is checked in; it just needs a provisioning profile that includes the capability, which Automatic signing will generate).

## Running Tests

Press **Cmd+U** in Xcode, or from the command line:

```bash
xcodebuild test \
  -project SplitPals.xcodeproj \
  -scheme SplitPals \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

The test suite covers split calculation logic, debt simplification, and settlement flows over an in-memory Core Data store.

## Project Structure

```
SplitPals/
├── SplitPalsApp.swift          App entry point
├── ContentView.swift           Root tab bar + onboarding gate
├── PersistenceController.swift Core Data stack setup
├── ExchangeRateService.swift   FX rate fetching + caching
├── Services/
│   ├── SplitCalculator.swift   Pure split math (equal & exact, remainder-safe)
│   ├── DebtSimplifier.swift    Greedy debt-minimisation algorithm
│   ├── SettlementManager.swift Bridges DebtSimplifier to Core Data
│   ├── SupabaseConfig.swift    Supabase project URL + publishable key
│   ├── SupabaseManager.swift   Shared SupabaseClient instance
│   └── AuthService.swift       Local "current user" resolution + Apple/Google cloud sign-in
├── Groups/                     Group list + add/edit screens
├── Expenses/                   Expense list, add/edit, and Settle Up views
├── Friends/                    Friends list + add/edit screens
├── Onboarding/                 First-launch name + avatar flow
└── Settings/                   Dark mode toggle, home currency picker, Account section
```

## Roadmap

- CloudKit sync (the Core Data stack is already configured for a one-line switch to `NSPersistentCloudKitContainer`)
- Cross-device data sync over the signed-in Supabase account (today, sign-in only establishes identity — it doesn't yet sync expenses/groups the way the web app's `splitpals_states` table does)
