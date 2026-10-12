# Security, Anti-Cheat & Safety

## Security

-   TLS everywhere.
-   Passwords, if supported, hashed with Argon2id/bcrypt.
-   Short-lived access tokens and rotating/revocable refresh sessions.
-   Store mobile secrets only in platform secure storage.
-   Strict authorization per endpoint and websocket event.
-   Rate limits for login, OTP, search, friend requests, room join, chat
    and gameplay spam.
-   Validate payload sizes/types/enums.
-   Parameterized ORM/query layer.
-   CORS and admin CSP appropriately configured.
-   Secrets manager in production.
-   Encrypt sensitive data at rest where appropriate.
-   Audit admin/economy/moderation actions.
-   Dependency/container scanning.
-   Backups and restore drills.

## Anti-Cheat

Server controls dice, legal moves, turn order, timers, outcome, XP and
wallet. Detect: - impossible move requests, - excessive event rate, -
replayed requests, - concurrent conflicting sessions, - tampered
purchase receipts, - suspicious collusion/boosting patterns, - repeated
disconnect exploitation. Do not expose hidden server controls through
client remote config.

## Chat & Voice Safety

Mute/block/report. Preset-chat-only option. Profanity/abuse filtering
for text. Voice must have mute/report controls and clear
consent/permissions. Retention must follow documented privacy policy.
Protect minors with age-appropriate defaults and regional compliance
hooks.

## Privacy

Data minimization, purpose limitation, retention schedule, account
deletion, export workflow, consent logs where required, privacy policy
and third-party processor inventory.

## Admin Security

Separate admin authentication, MFA-ready, RBAC, audit trail, IP/device
alerts where appropriate. No production "god mode" that can secretly
alter live dice.
