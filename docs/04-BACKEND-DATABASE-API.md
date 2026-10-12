# Backend, Database & API

## Services / Modules

Auth, Users, Profiles, Friends, Presence, Matchmaking, Rooms, Game
Session, Tournament, Economy, Inventory, Missions, Seasons,
Leaderboards, Chat/Moderation, Notifications, Purchases, Admin,
Analytics/Audit.

## Core Tables

users user_identities devices refresh_sessions profiles friendships
blocks matchmaking_tickets rooms room_members matches match_players
game_snapshots game_events player_stats wallets wallet_ledger
catalog_items user_inventory purchase_orders purchase_receipts missions
user_missions seasons season_progress leaderboard_entries (or derived
store) tournaments tournament_entries tournament_matches chat_messages
reports moderation_actions notifications admin_users admin_audit_logs
feature_flags remote_config

Use UUID/ULID identifiers as appropriate. Add created_at/updated_at and
indexes based on query paths. Never use a mutable currency balance
without ledger reconciliation.

## REST API Groups

/auth/* /me/* /players/* /friends/* /rooms/* /matchmaking/* /matches/*
/tournaments/* /inventory/* /shop/* /wallet/* /missions/* /seasons/*
/leaderboards/* /notifications/* /reports/* /config/* /admin/*

Publish OpenAPI. Define request/response schemas and structured error
codes.

## Example Private Room

POST /rooms POST /rooms/{code}/join POST /rooms/{id}/ready POST
/rooms/{id}/leave GET /rooms/{id} POST /rooms/{id}/invite

## Persistence Strategy

Persist match metadata immediately. Keep active state optimized for
realtime access; checkpoint snapshots and append meaningful game events.
At completion persist final canonical result and derived stats/rewards
transactionally/outbox-driven where cross-module side effects occur.

## Redis

Presence, websocket routing metadata, matchmaking queues, ephemeral
rooms/cache, rate limits, distributed locks where justified, pub/sub or
streams. Redis is not the sole durable source for
purchases/wallet/history.

## Background Jobs

Expired rooms, abandoned matchmaking, push delivery, leaderboard
aggregation, mission resets, season rollover, receipt retry, moderation
pipelines, analytics export and data retention.
