# Deployment & DevOps

## Local

Docker Compose: postgres, redis, api/realtime, admin dependencies.
Mobile points to environment-configured API endpoint.

## Environments

dev, staging, production. Separate databases, secrets, OAuth/payment
credentials, push keys and analytics projects.

## Production

Load balancer -\> API/realtime instances. Managed PostgreSQL with PITR.
Managed Redis. Object storage/CDN. Central logs, metrics, traces and
alerts. Autoscaling based on CPU plus socket/event metrics. Sticky
sessions should not be required for correctness; use shared
routing/presence/pub-sub architecture.

## CI/CD

PR: format, lint, type checks, unit/integration tests, game simulations,
security/dependency scans. Main: build immutable images/artifacts.
Staging: migrations -\> deploy -\> smoke/E2E. Production: approval -\>
backward-compatible migration -\> canary/staged rollout -\> health
validation.

## Mobile Release

Build flavors for dev/staging/prod. Signing keys protected. Crash
reporting. Remote minimum supported version. Store listing assets are
original. Privacy declarations match actual SDK behavior.

## Observability

Structured logs include request/connection/match correlation IDs but not
secrets. Dashboards: API error/latency, websocket connections/events,
matchmaking time, Redis, DB, game completion, disconnect rate, purchase
validation and crash-free sessions.
