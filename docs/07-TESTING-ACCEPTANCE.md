# Testing & Acceptance

## Game Engine Unit Tests

Cover every die value, yard exit, all board boundaries, color offsets,
safe cells, capture, stacks/blocks, home lane, exact finish, bonus
turns, consecutive six policy, no-legal-move, timeout, all-tokens-home,
placements and invariant checks.

Use property-based tests: - tokens never occupy invalid logical
positions, - move distance equals allowed transition, - opponent token
can only be returned by a valid capture, - finished token never leaves
home, - non-current player cannot act.

## Simulation

Run at least tens of thousands of bot-vs-bot games in CI/nightly jobs to
detect deadlocks, impossible states and rules regressions.

## API Tests

Authentication/authorization, room lifecycle, matchmaking,
profile/friends, wallet idempotency, reward claim duplication,
purchases, moderation.

## Realtime Integration

2--6 simulated clients: - join/start, - simultaneous invalid requests, -
disconnect/reconnect, - duplicate messages, - stale sequence, - app
resume, - timeout, - match completion.

## Mobile

Widget/UI tests and end-to-end smoke flows on representative Android/iOS
sizes. Test low-memory/background scenarios.

## Load

Measure concurrent sockets, matchmaking throughput, events/sec, Redis
and DB latency. Establish SLOs before production. Target p95 realtime
command acknowledgement under an explicitly measured regional threshold
rather than hiding lag with animations.

## Security

OWASP-style API review, dependency scan, auth/session tests, rate-limit
tests, websocket authorization, receipt tampering and admin RBAC.

## Release Gates

No critical/high known security defect. No deterministic rules failure.
No wallet duplication bug. No known client-authoritative gameplay path.
Crash-free target met in staged rollout. Rollback procedure verified.
