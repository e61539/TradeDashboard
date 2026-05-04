# TradingDashboard Frontend Agent Guide

## 1. System Overview

This repository is the Mac/iPhone SwiftUI frontend for `TradingDashboard`.

The Windows BuyLow backend owns trading decisions, Schwab integration, BuyLow logs, positions, capital utilization, capital readiness, and Schwab status. The SwiftUI app displays backend API results and sends user actions only through existing backend APIs.

Do not move backend responsibilities into Swift.

## 2. Frontend Responsibilities

- Display account, position, quote, BuyLow, log, capital readiness, and Schwab status data returned by backend APIs.
- Keep iPhone UI compact, readable, and decision-aware.
- Keep signal status separate from execution status.
- Never show `READY` unless backend data indicates execution is actually allowed.
- If BuyLow is blocked by ATR, show price discrepancy or distance to target instead of misleading `BUY` / `READY` language.
- Preserve existing `APIClient`, `ContentView`, `Models`, and settings behavior unless the task explicitly requires a change.
- Prefer minimal, local changes that match existing SwiftUI patterns.

## 3. Safety Rules

- Do not implement trading logic in Swift.
- Do not place orders except through existing backend preview/confirm APIs.
- Do not change Schwab auth logic in this frontend repo.
- Do not change Keychain or credential storage logic unless explicitly requested.
- Do not store backend secrets, API keys, tokens, or Schwab credentials in the repo unless explicitly requested.
- Do not add buttons or flows that initiate transfers, Merrill actions, Schwab orders, cap changes, or funding changes unless explicitly requested and routed through approved backend APIs.
- Do not change trading order preview/confirm behavior unless explicitly requested.

## 4. API Contract Rules

- Treat backend API responses as the source of truth.
- Keep Swift models aligned with backend JSON contracts.
- Decode optional or newly added backend fields defensively when practical.
- Do not mutate backend files or trigger backend actions from display-only endpoints.
- Preserve stale / last-known fallback behavior unless the task explicitly changes it.
- For BuyLow status, display both signal state and execution state when available.
- For blocked states, show the backend-provided block reason in a concise user-facing form.
- For capital readiness, use advisory language such as `Suggested manual transfer`, `Manual action required`, and `Advisory only`.
- Avoid unsafe action labels such as `Transfer now`, `Sell Merrill`, `Fund automatically`, or `Raise cap`.

## 5. Testing / Build Commands

Before code changes, summarize:

- Affected files.
- Intended behavior change.
- Test plan.

After code changes, run an Xcode build when possible:

```sh
xcodebuild -project TradingDashboard.xcodeproj -scheme TradingDashboard -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build
```

If that simulator is unavailable, choose an available iPhone simulator destination and report the exact command used.

Also verify:

- No trading logic moved into Swift.
- No Schwab auth or Keychain logic changed unintentionally.
- UI remains compact on iPhone.
- Existing preview/confirm order flow still routes through backend APIs.

## 6. Cross-Machine Workflow

- This repo is the Mac/iPhone frontend repo.
- The Windows BuyLow backend repo owns `dashboard_api.py`, BuyLow processing, Schwab integration, logs, capital readiness JSON generation, and capital utilization logic.
- When backend JSON contracts change on Windows, update Swift models and display code here only as needed.
- Confirm which machine/path is active before assuming code changes are present.
- Avoid copying whole files between Mac and Windows repos when a smaller API/model/UI update is sufficient.
- Keep frontend and backend changes separated unless the task explicitly spans both repos.
