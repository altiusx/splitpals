# SplitPals

A native iOS app for splitting expenses with friends and groups. Track shared costs, see who owes what, and get a minimal set of suggested payments to settle up.

## Features

- **Expense groups** — create named groups with a custom icon and colour gradient (trip, flat, event, etc.)
- **Flexible splitting** — split equally among any subset of members, or enter exact amounts manually
- **Settle Up** — per-group balance view with a greedy-minimised payment suggestion list (fewest transfers to clear all debts)
- **Multi-currency** — 18 currencies supported; live exchange rates fetched from [Frankfurter](https://frankfurter.dev) and cached for 24 hours so the app works offline
- **Friends list** — reusable contacts that can be added to any group
- **Dark mode** — opt-in from Settings

## Tech Stack

| | |
|---|---|
| Language | Swift 5 |
| UI | SwiftUI |
| Persistence | Core Data (CloudKit-ready) |
| Async | Swift Concurrency (`async`/`await`) |
| External API | Frankfurter (FX rates, public, no key needed) |
| Dependencies | None |
| Minimum OS | iOS 26 |

## Getting Started

**Requirements:** macOS with a recent Xcode beta that supports the iOS 26 SDK.

1. Clone the repo and open `SplitPals.xcodeproj` in Xcode.
2. Select an iOS 26 simulator or device from the scheme selector.
3. Press **Cmd+R** to build and run.

No API keys or environment variables are needed.

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
│   └── SettlementManager.swift Bridges DebtSimplifier to Core Data
├── Groups/                     Group list + add/edit screens
├── Expenses/                   Expense list, add/edit, and Settle Up views
├── Friends/                    Friends list + add/edit screens
├── Onboarding/                 First-launch name + avatar flow
└── Settings/                   Dark mode toggle + home currency picker
```

## Roadmap

- CloudKit sync (the Core Data stack is already configured for a one-line switch to `NSPersistentCloudKitContainer`)
- Sign in with Apple (stub is in place in `AuthService.swift`)
