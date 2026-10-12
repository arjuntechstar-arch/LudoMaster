# Game Engine & Realtime Specification

## Domain Model

GameState: - match_id - ruleset_version - status - seats\[\] -
current_seat - phase: WAITING \| ROLL_REQUIRED \| MOVE_REQUIRED \|
RESOLVING \| FINISHED - dice_value - consecutive_sixes - tokens per
player - placements - turn_deadline - sequence - rng metadata safe for
audit - last_action

TokenState: YARD \| TRACK \| HOME_LANE \| HOME. Never infer
authoritative token position from animation coordinates.

## Pure Functions

-   initialize_game(config, players)
-   roll_allowed(state, player)
-   legal_moves(state, player, dice)
-   apply_roll(state, player, generated_value)
-   apply_move(state, player, token_id)
-   resolve_capture(...)
-   resolve_bonus_turn(...)
-   resolve_timeout(...)
-   calculate_placements(...)
-   validate_invariants(state)

Every transition returns a new state + domain events. Create exhaustive
tests for boundaries, safe cells, capture, sixes, home entry and finish.

## Online Authority

Client sends intent: `ROLL_REQUEST`, `MOVE_REQUEST`, `READY`, `CHAT`,
`EMOJI`, `LEAVE`, `RECONNECT`.

Server validates identity, seat, match status, turn, sequence and
legality. Server generates dice. Server commits transition, increments
sequence, persists required state/events, then broadcasts canonical
result.

## Realtime Event Envelope

{ "event": "MOVE_APPLIED", "version": 1, "matchId": "...", "sequence":
123, "serverTime": "...", "payload": {} }

Required events include: CONNECTED, AUTHENTICATED, ROOM_STATE,
PLAYER_JOINED, PLAYER_LEFT, READY_CHANGED, MATCH_STARTED, TURN_STARTED,
DICE_ROLLED, LEGAL_MOVES, MOVE_APPLIED, TOKEN_CAPTURED, TOKEN_HOME,
BONUS_TURN, TURN_TIMEOUT, PLAYER_DISCONNECTED, PLAYER_RECONNECTED,
PLAYER_FORFEITED, STATE_SNAPSHOT, MATCH_FINISHED, CHAT_MESSAGE,
EMOJI_SENT, ERROR.

## Reconnect

-   Heartbeat/ping-pong.
-   Grace period after disconnect.
-   Client reconnects with auth + match ID + last received sequence.
-   Server either replays missing events or sends canonical snapshot.
-   Client discards stale/out-of-order duplicate events.
-   Reconnect cannot extend turn indefinitely.
-   App kill/background and network switch must be tested.

## Matchmaking

Queues keyed by mode/player-count/rules/region/rating band. Flow:
enqueue -\> ticket -\> candidate grouping -\> reservation -\>
accept/timeout -\> room creation -\> websocket join. Expand
rating/region constraints gradually, not instantly. Use Redis atomic
operations/locks as needed. Prevent duplicate queue entries.

## Bots

Three configurable difficulties. Bot uses the same legal-move API as
humans and never bypasses rules. It receives no future random
information. Difficulty changes move evaluation, not dice probability.

Possible heuristic factors: - complete token - capture - leave yard -
move to safety - escape capture risk - advance progress - block
creation - opponent threat Use seeded deterministic tests.

## Fair Dice

For online play use OS/CSPRNG server-side. Log sufficient non-sensitive
audit metadata and statistical telemetry. Never let the mobile client
choose/override a roll. Add distribution monitoring and automated
chi-square style sanity tests over large simulation samples, while
recognizing such tests do not prove individual-roll fairness.
