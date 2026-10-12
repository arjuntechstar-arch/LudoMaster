# 🎲 LudoMaster

> **Enterprise-Grade, Server-Authoritative Ludo Game Monorepo**  
> Built with Flutter (Mobile), Dart (Deterministic Core Engine), FastAPI & WebSockets (Backend), Redis (Pub/Sub & Presence), PostgreSQL, and React + TypeScript + Vite (Admin Dashboard).

---

## 🌟 Executive Summary

**LudoMaster** is a complete, scalable, cross-platform multiplayer board game platform adhering to strict server-authoritative rules, real-time synchronization, comprehensive progression/meta systems, and live operations management.

### Key Architectural Pillars
- **Deterministic Core Game Engine**: Implemented in pure Dart with zero network or UI dependencies. Governed by a pure state machine, invariant checks, strict sixes/bonus-turn policies, capture resolutions, and complete simulation suites.
- **Server-Authoritative Realtime Gateway**: FastAPI WebSockets with Redis pub/sub room broadcasting, ping-pong liveness detection, automatic bot replacement on disconnect, and turn timeout auto-moves.
- **Full-Featured Mobile Client**: Built with Flutter and Riverpod. Supports responsive phone/tablet layouts, custom board coordinate mappers, rich dice roll animations, offline computer bots, local pass-and-play, and online multiplayer.
- **Multi-Language Localization & Accessibility**: Native dictionary support for English (`en`), Hindi (`hi`), Spanish (`es`), French (`fr`), and German (`de`), high-contrast color scheme, dynamic font scaling, and global error boundaries.
- **Security & Privacy by Design**: JWT session management, Bcrypt hashing, guest-to-permanent account linking, anti-cheat dice validation, rate limiting, GDPR data export, and account self-deletion.
- **Live Ops Admin Portal**: React + Vite single-page dashboard with role-based access control (RBAC), user moderation, economy ledger inspection, remote configuration, catalog management, and audit logs.

---

## 📋 Complete Feature Matrix (100% Implemented)

### 1. Core Gameplay
- [x] **Classic Ludo**: Authentic standard board with 4 colored quadrants (Red, Green, Yellow, Blue), 52 track cells, 8 safe/star cells, and home columns.
- [x] **2 / 3 / 4 / 5 / 6 Player Support**: Flexible seat layout and dynamic board configurations.
- [x] **Offline Computer Bots**: Three intelligent heuristics (Easy, Medium, Hard) that prioritize captures, home entries, and safe positioning.
- [x] **Local Pass-and-Play**: Seamless hotseat multiplayer on a single device without internet access.
- [x] **Online Matchmaking**: Tier- and region-based queue system with automatic match formation.
- [x] **Private Custom Rooms**: 6-character room codes with shareable deep links (`ludomaster://room/CODE`).
- [x] **Quick Mode**: Fast-paced 2-token match variant with mandatory opponent capture to unlock the home lane.
- [x] **2v2 Team Mode**: Allied players cannot capture each other; finished players roll for their partner to secure team victory.
- [x] **8-Player Tournament Brackets**: 3-round knockout bracket (Quarterfinals, Semifinals, Finals) with automated progression and trophy awards.
- [x] **State Persistence & Reconnect**: Save and resume local games; online clients reconnect and re-sync match snapshots seamlessly.
- [x] **Turn Timeout & AFK Policy**: Server-enforced turn timer (15s) with automated dice rolls and move fallbacks.

### 2. Social & Community
- [x] **Friends & Buddies**: Unique player ID search (`LM-XXXXX`), incoming/outgoing friend requests, accept/reject, and presence indicators.
- [x] **Direct Invites**: Send room challenge invites directly to online friends.
- [x] **In-Game Chat**: Emoji reactions, preset tactical messages, and moderated free-text chat with profanity filtering.
- [x] **Voice Chat & Safety**: Room voice chat with ephemeral tokens, explicit privacy consent, mic mute/unmute, talking visualizer, individual player mute, and voice harassment reporting.
- [x] **Clubs & Social Rooms**: Create or join custom clubs (`[TAG]`), manage rosters, minimum-level entry gates, and automated leadership succession.
- [x] **Moderation & Safety**: Block abusive users, in-game report dialogs, and moderation queues.

### 3. Meta, Economy & Monetization
- [x] **Player Profile & Progression**: XP curves, level scaling, avatar selection, win/loss records, and historical match stats.
- [x] **Economy System**: Dual-currency model (Soft: Coins, Hard: Gems) backed by an immutable append-only ledger.
- [x] **Daily Rewards**: 7-day escalating login streak calendar with bonus multipliers.
- [x] **Missions & Quests**: Daily and weekly rotating objectives with automatic progress tracking and one-click reward claims.
- [x] **Achievements System**: Milestone achievements across rolls, captures, wins, and currency milestones.
- [x] **Seasons & Season Pass**: Timed seasonal ladders with Free and Premium reward tracks.
- [x] **Global & Regional Leaderboards**: Ranked tiers with all-time, monthly, and weekly leaderboards.
- [x] **Cosmetics & Store Catalog**: Customizable board themes, dice styles, and token trails.
- [x] **In-App Purchases (IAP)**: Store tiers, mock receipt verification, order tracking, and wallet crediting.
- [x] **Inbox & Announcements**: System notifications with read/unread tracking and batch actions.

### 4. Platform & Operations
- [x] **Cross-Platform**: Ready for iOS and Android deployment.
- [x] **Localization**: 5 languages (English, Hindi, Spanish, French, German) with fallback dictionary.
- [x] **Accessibility (a11y)**: High-contrast theme mode, dynamic text scaling, and global error boundaries with crash diagnostics.
- [x] **Low-End Optimization**: Lightweight canvas rendering, minimal texture overhead, and memory efficiency.
- [x] **Disaster Recovery**: Automated database backup, compression, verification, and point-in-time restore scripts.
- [x] **E2E Load Testing**: In-process and multi-client concurrent load simulation tool.
- [x] **CI/CD Automation**: GitHub Actions pipeline for linting, testing, Docker builds, and deployment verification.

---

## 📂 Repository Structure

```
LudoMaster/
├── .github/workflows/          # GitHub Actions CI/CD automation
│   └── ci.yml
├── apps/
│   ├── admin/                  # React + TypeScript + Vite Admin Web Dashboard
│   │   ├── Dockerfile
│   │   ├── nginx.conf
│   │   └── src/
│   └── mobile/                 # Flutter mobile application
│       ├── lib/
│       │   ├── src/
│       │   │   ├── controllers/  # Riverpod state notifiers
│       │   │   ├── localization/ # Multi-language dictionaries
│       │   │   ├── screens/      # All UI screens & modals
│       │   │   ├── services/     # API client, WebSocket & storage
│       │   │   └── widgets/      # Canvas board, dice & voice controls
│       └── test/                 # 40 Flutter unit & widget tests
├── packages/
│   ├── contracts/              # Shared schemas and contract specifications
│   └── game_engine/            # Pure Dart deterministic game engine
│       ├── lib/src/            # State machine, rulesets, invariants
│       └── test/               # 39 unit & simulation tests
├── services/
│   ├── api/                    # FastAPI REST backend
│   │   ├── Dockerfile
│   │   ├── app/
│   │   │   ├── api/v1/         # Routers (auth, rooms, clubs, voice, etc.)
│   │   │   ├── models/         # SQLAlchemy ORM models
│   │   │   └── schemas/        # Pydantic validation schemas
│   │   └── tests/              # 43 pytest API tests
│   └── realtime/               # WebSocket game server & room manager
│       ├── gateway.py          # WebSocket connection handler
│       └── tests/              # 19 pytest real-time multiplayer tests
├── infra/
│   └── docker-compose.yml      # Orchestrated Postgres, Redis, API, and Admin
├── scripts/
│   └── backup_restore.py       # Disaster recovery & database drill tool
├── tests/
│   └── e2e_load_test.py        # End-to-end concurrent load simulation
└── docs/                       # Architectural & design documentation
```

---

## 🚀 Quick Start Guide

### Option 1: Full Stack via Docker Compose (Recommended)

From the project root:
```bash
docker compose -f infra/docker-compose.yml up --build
```
This launches:
- **PostgreSQL Database** on port `5432`
- **Redis Cache & Pub/Sub** on port `6379`
- **FastAPI Backend (REST + Realtime WS)** on port `8000`
- **Admin Management Portal** on port `3000`

### Option 2: Running Services Individually

#### 1. Backend REST API & Realtime Gateway
```bash
cd services/api
python -m venv .venv
source .venv/bin/activate  # Or on Windows: .venv\Scripts\Activate.ps1
pip install -r requirements.txt -r ../realtime/requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
- API Documentation (Swagger): [http://localhost:8000/docs](http://localhost:8000/docs)
- Health Check: [http://localhost:8000/health](http://localhost:8000/health)

#### 2. Admin Web Portal
```bash
cd apps/admin
npm install
npm run dev
```
Open [http://localhost:5173](http://localhost:5173) in your browser.  
Default Admin credentials:
- Username: `admin`
- Password: `AdminPass123!`

#### 3. Mobile Flutter Client
```bash
cd apps/mobile
flutter pub get
flutter run
```

---

## 🧪 Monorepo Verification & Test Suites

The entire monorepo is covered by **141 automated tests**, all passing green:

### 1. Deterministic Game Engine (39 tests)
```bash
cd packages/game_engine
flutter test
```

### 2. Backend REST API (43 tests)
```powershell
$env:PYTHONPATH=".;./services/api;./services/realtime"
pytest services/api/tests -v
```

### 3. Realtime WebSocket Gateway (19 tests)
```powershell
$env:PYTHONPATH=".;./services/api;./services/realtime"
pytest services/realtime/tests -v
```

### 4. Mobile Application Unit & Widget Tests (40 tests)
```bash
cd apps/mobile
flutter test
```

### 5. Admin Web Portal Production Build
```bash
cd apps/admin
npm run build
```

---

## 🛡️ Disaster Recovery & Load Testing

### Disaster Recovery Drill
To execute an automated database backup, compression, integrity verification, and restore cycle:
```bash
python scripts/backup_restore.py drill
```

### End-to-End Concurrent Load Simulation
Simulates concurrent players creating rooms, joining, rolling dice, and executing moves:
```bash
python tests/e2e_load_test.py --in-process --clients 10 --iterations 3
```

---

## 📜 License

Proprietary © 2026 LudoMaster Studio. All rights reserved.
