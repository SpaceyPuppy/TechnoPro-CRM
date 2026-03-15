# ADR 008: Native App Framework — Flutter

## Status
Accepted

## Context
Need native apps for Android tablets, Windows touchscreen devices, and eventually iOS and macOS. Key requirements: touch-friendly UI, offline capability with sync, and minimal codebase duplication. Options considered: Kotlin Multiplatform + Compose Multiplatform, Flutter, React Native, .NET MAUI, separate native apps per platform.

## Decision
Use **Flutter** (Dart) as a single codebase for all native app platforms.

## Rationale
- One codebase covers Android, Windows, iOS, and macOS — competitive advantage over web-only CRMs in this industry
- Built for touch-first UIs; translates naturally to tablets and touchscreen laptops
- Strong offline/local database support (SQLite, Hive, Isar)
- Backed by Google, proven at scale (BMW, eBay, Alibaba)
- Very large community and package ecosystem
- Future option to consolidate the React web app into Flutter web if desired
- Claude can write Dart fluently, so development velocity is not impacted

## Trade-offs
- Dart is a new language for the team (mitigated by Claude doing the heavy lifting)
- Flutter desktop (Windows/macOS) is stable but less battle-tested than mobile
- Cannot directly share TypeScript types from `@technopro/shared` — API contracts must be mirrored as Dart classes
- App bundle size larger than pure native

## Consequences
- `flutter/` directory replaces `android/` in the repo
- Offline sync engine built once in Dart, works on all platforms
- Local SQLite database for offline data and mutation queue
- API types defined in `packages/shared/` (TypeScript) serve as source of truth; Dart models mirror them
- Stage 5 scope expands from Android-only to Android + Windows
