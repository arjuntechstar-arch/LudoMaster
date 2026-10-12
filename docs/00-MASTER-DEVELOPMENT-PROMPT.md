# MASTER DEVELOPMENT PROMPT --- Production Ludo Multiplayer Game

## Role

Act as a principal game architect, senior mobile engineer, backend
engineer, realtime multiplayer engineer, UI/UX designer, DevOps
engineer, QA engineer, security engineer, and product owner.

Build a production-ready, original cross-platform Ludo game inspired by
the standard Ludo rules and the broad feature categories found in
leading Ludo applications. Do NOT copy any third-party trademark, logo,
UI, artwork, audio, proprietary text, source code, board artwork,
animations, or other protected assets. Create original branding,
layouts, assets, effects, and naming.

## Product Goal

Create a polished Android/iOS Ludo product with: - Classic Ludo - Online
multiplayer for 2--6 players - Private rooms with room code/link -
Offline vs computer - Local pass-and-play - Quick game - 2v2 team mode -
Tournament mode - Friends/buddies and challenges - In-game emoji/preset
chat and optional moderated text/voice chat - Profiles, XP, levels,
statistics - Coins and non-cash virtual rewards - Daily login, daily
goals, missions, seasons - Themes, dice skins, token skins, emojis -
Leaderboards - Reconnect/resume - Spectator-ready architecture - Push
notifications - Admin dashboard - Analytics, observability, moderation,
anti-cheat - Scalable realtime backend

Do not implement real-money gambling, cash wagering, withdrawal, or
purchasable random rewards unless a later legal/compliance specification
explicitly authorizes them.

## Recommended Stack

Mobile: Flutter + Dart. State management: Riverpod or Bloc; choose one
and use consistently. Game rendering: Flutter CustomPainter/animations
for a 2D board, or Flame only where it clearly simplifies animation.
Backend: FastAPI + Python. Realtime: WebSockets. Primary database:
PostgreSQL. Cache/presence/matchmaking/pub-sub: Redis. Object storage:
S3-compatible storage. Admin: React + TypeScript. Reverse proxy: Nginx.
Containerization: Docker / Docker Compose. Production: AWS/Azure/GCP
compatible. CI/CD: GitHub Actions. Notifications: Firebase Cloud
Messaging + APNs. Voice: WebRTC or a managed provider behind an
abstraction. Authentication: JWT access + rotating refresh tokens;
Google/Apple sign-in optional. Payments: Google Play Billing / Apple
StoreKit for permitted digital purchases. Server-side receipt
validation.

If requirements dictate a different stack, document the reason before
changing it.

## Engineering Rules

1.  Read every document in this package before writing code.
2.  Implement phase-by-phase. Do not jump ahead.
3.  No placeholder implementations for functionality scheduled in the
    active phase.
4.  Server is authoritative for every online match.
5.  Never trust a client-supplied dice value, move result, balance, XP,
    inventory ownership, or match outcome.
6.  Game rules must be a deterministic domain module independent of
    UI/network/database.
7.  Every state-changing request/event must support idempotency where
    retries are possible.
8.  Realtime events must have event name, version, match ID, sequence
    number, server timestamp and payload.
9.  Persist enough authoritative state/events to restore interrupted
    games.
10. All secrets are environment variables/secret-manager values.
11. Add tests with every feature.
12. Run lint, static analysis, unit tests and integration tests before
    calling a phase complete.
13. Maintain migrations, seed data, API documentation and README.
14. Mobile UI must support small/large screens, safe areas and low-end
    devices.
15. Build accessibility hooks and localization from the beginning.
16. Use UTC on servers and ISO-8601 timestamps; render local time on
    clients.
17. Do not manipulate dice outcomes to favor monetization, retention,
    bots or specific players.

## Required Repository

/apps/mobile /apps/admin /services/api /services/realtime
/packages/game_engine /packages/contracts /infra /docs /tests

A modular monolith is acceptable initially, but game engine, realtime
boundaries and contracts must remain separable.

## Definition of Done

A feature is complete only when: - acceptance criteria pass, - tests
pass, - errors/loading/empty states exist, - authorization is
enforced, - telemetry exists where appropriate, - reconnect/retry
behavior is considered, - documentation is updated, - no hard-coded
secrets or test bypasses remain.
