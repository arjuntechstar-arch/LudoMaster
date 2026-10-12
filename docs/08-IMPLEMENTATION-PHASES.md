# Implementation Phases

## Phase 0 --- Foundation

Monorepo, architecture decisions, environments, CI, lint/test,
contracts, Docker Compose, Postgres/Redis, logging, config, Flutter
shell, admin shell.

## Phase 1 --- Deterministic Ludo Core

Board model, ruleset config, pure game state machine, legal moves,
captures, home, turn rules, unit/property tests, simulation CLI. No
network dependency.

Exit: Classic 2--4 player game can be simulated to completion without
invalid state.

## Phase 2 --- Offline Product

Original board UI, animation adapter, local pass-and-play, computer
bots, settings, pause/save/load local game.

Exit: fully playable offline build.

## Phase 3 --- Accounts & Backend

Auth/guest upgrade, profile, DB migrations, remote config, REST
foundation, observability.

## Phase 4 --- Realtime Online

Websocket gateway, server-authoritative engine, rooms, 2--4 player
online, reconnect, timers, persistence, result stats.

Exit: multiple real devices complete matches through
disconnect/reconnect.

## Phase 5 --- Matchmaking & 5/6 Players

Queues, rating/region strategy, 5/6-seat board behavior/UI, recent
players, history.

## Phase 6 --- Private/Friends/Social

Room codes/deep links, friends, invites, emoji/preset chat,
block/report. Add text/voice only after moderation/privacy controls
exist.

## Phase 7 --- Quick & Team

Versioned Quick rules, 2v2 rules, matchmaking/private support, tests.

## Phase 8 --- Progression & Economy

XP, levels, stats, ledger, daily rewards, missions, achievements,
inventory/customization.

## Phase 9 --- Tournament & Seasons

8-player tournament flow, season lifecycle, leaderboards, rewards.

## Phase 10 --- Admin & Live Ops

Admin RBAC, catalog, missions, seasons, tournament config,
announcements, feature flags, audit tools.

## Phase 11 --- Store/Notifications

Permitted in-app purchases, receipt validation, push notifications, deep
links. Ads optional behind consent/config.

## Phase 12 --- Hardening & Release

Load/security/accessibility/localization testing, backup/restore,
dashboards/alerts, store compliance, privacy/delete/export, staged
rollout.

### AI Coding Agent Instruction

At the start of each phase: 1. Read this phase and all referenced
architecture documents. 2. Produce a file-level implementation plan. 3.
Implement only that phase and required prerequisites. 4. Add
migrations/tests/docs. 5. Run all relevant commands. 6. Fix failures. 7.
Report files changed, commands run, test results, remaining risks. 8.
Stop and wait for approval before the next phase unless explicitly
instructed to continue.
