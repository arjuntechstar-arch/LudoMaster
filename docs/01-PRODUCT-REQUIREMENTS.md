# Product Requirements

## Player Journey

Launch -\> splash/version check -\> guest/login -\> home -\> choose mode
-\> configure/join -\> matchmaking/lobby -\> ready -\> match -\> results
-\> rewards/progression -\> rematch/home.

## Home

Show player avatar/name/level/currency, primary Play action, Online,
Friends/Private, Computer, Local, Quick, Team, Tournament, Missions,
Season, Inventory, Leaderboard, Friends/Club, Shop, Inbox and Settings.

## Authentication & Account

-   Guest account with generated identity.
-   Upgrade guest to verified account without losing progress.
-   Email/OTP or supported identity provider.
-   Google and Apple sign-in where supported.
-   Unique public player ID and editable display name with moderation.
-   Avatar selection/upload with moderation strategy.
-   Session/device management and logout.
-   Account deletion/export flows.
-   Age gate/consent hooks and privacy settings.

## Game Modes

### Classic Online

2, 3, 4, 5 or 6 players. Matchmaking by mode, region/latency and
reasonable skill/rating buckets.

### Private Room

Host selects player count, rules preset and optional spectators/chat.
Generate short room code and deep link. Joining player sees lobby and
readiness. Host cannot control dice.

### Offline Computer

1 human + bots or configurable seats. Entire game works without network
after required assets exist locally.

### Local Multiplayer

2--6 humans on one device, pass-and-play. Hide private prompts when
device changes hands.

### Quick Mode

A shorter ruleset controlled by server configuration. Keep it as a
separately versioned rules preset so balancing can change without
corrupting Classic.

### Team Mode

2v2. Teammates have defined seat order, shared win condition and
configurable teammate capture/block rules.

### Tournament

Initial target: 8 players, bracket or staged format configurable from
backend. Registration -\> seeding -\> round -\> result -\> advancement
-\> final -\> reward. Support disconnect policy and tournament expiry.

## Standard Ludo Rules Engine

Make every rule configurable by `RuleSetVersion`.

Default Classic preset: - Each player has four tokens. - A token leaves
yard on a six. - Dice produces 1--6 using cryptographically secure
server randomness for online games. - Token advances by rolled count. -
Exact roll is required to enter final home where applicable. - Landing
on a vulnerable opponent token captures it and returns it to its yard. -
Safe cells cannot be captured. - Same-color stacking/block behavior is
controlled by rules configuration. - Rolling a six grants another roll
unless restricted by consecutive-six rule. - Capture/home completion
bonus turn is configurable. - Define the three-consecutive-six policy
explicitly. - A player finishes after all required tokens reach home. -
Continue to determine remaining placements when the mode requires it. -
Illegal moves are rejected by engine and server. - If only one legal
move exists, optional auto-move after a delay. - If no legal move
exists, automatically end the turn after animation window. - Turn
timeout invokes configurable auto-play/skip policy. - Repeated
inactivity may convert the seat to bot/forfeit according to mode.

Do not encode board movement as scattered UI conditionals. Model a
canonical path, per-color entry offsets, safe squares, home lanes,
yard/home states, legal-move generator and transition reducer.

## Match UX

-   Board centered and responsive.
-   Player panels indicate active turn, connection and timer.
-   Animated dice with final value determined by server.
-   Highlight only legal tokens.
-   Smooth step movement.
-   Capture, home and victory effects.
-   Haptics and sound toggles.
-   Emoji/preset messages.
-   Optional voice/text according to room safety settings.
-   Network quality/reconnecting indicator.
-   Background/resume support.
-   Match history/result screen.

## Friends & Social

-   Search by player ID/name.
-   Friend request, accept/reject/remove/block.
-   Online/presence status with privacy controls.
-   Invite friend to room.
-   Recent players.
-   Clubs/social rooms as a later gated module.
-   Report/mute/block.
-   Rate limits and abuse moderation.

## Progression

-   XP and levels.
-   Match statistics: played, wins, placements, captures, tokens home,
    streaks.
-   Daily login calendar.
-   Daily/weekly missions.
-   Season track and seasonal leaderboard.
-   Achievements/badges.
-   Server-authoritative reward claims.
-   Inventory: board themes, dice skins, token skins, frames, emojis.
-   Cosmetic rarity is visual only; no gameplay advantage.

## Economy

Use virtual soft currency and optional premium currency. Keep an
immutable wallet ledger. Never update a balance without a ledger
transaction. Support earn/spend/refund/admin-adjustment with audit
reason and idempotency key.

## Leaderboards

Daily/weekly/seasonal/all-time scopes as configured. Ranking inputs must
be server-derived. Define tie-breaking deterministically.

## Settings

Sound/music/haptics, language, notifications, privacy, chat/voice,
blocked users, account, support, terms/privacy, app version.

## Localization

Externalize all strings. Start with English; architecture must support
Indian and international languages without UI redesign.
