# LudoMaster Quality Gate

This document defines the mandatory validation process for LudoMaster changes. The goal is to detect functional regressions, multiplayer synchronization bugs, security issues, UI/layout problems, dependency vulnerabilities, and load/performance regressions before a change reaches `main`.

## 1. Developer workflow

Use the root PowerShell runner from Windows PowerShell 7+:

```powershell
./scripts/test.ps1 -Mode Quick
```

Run this after normal development changes. Before opening or updating a pull request, run:

```powershell
./scripts/test.ps1 -Mode Full
```

Individual suites are also available:

```powershell
./scripts/test.ps1 -Mode Security
./scripts/test.ps1 -Mode Multiplayer
./scripts/test.ps1 -Mode UI
./scripts/test.ps1 -Mode Load
```

Equivalent direct scripts:

```powershell
./scripts/test-security.ps1
./scripts/test-multiplayer.ps1
./scripts/test-ui.ps1
./scripts/test-load.ps1
```

The master runner writes `test-results/quality-gate.json`. A non-zero exit code means the quality gate failed.

## 2. What each mode validates

### Quick

- Dart static analysis for the deterministic game engine.
- Dart game-engine unit/simulation tests.
- FastAPI backend pytest suite.
- Realtime/WebSocket pytest suite.
- Flutter static analysis.
- Flutter unit/widget tests.
- Admin dashboard dependency restore and production build.

### Security

- Bandit Python static security analysis.
- `pip-audit` for API and realtime Python dependencies.
- `npm audit --audit-level=high` for the admin application.
- API authentication/security regression tests.
- Optional local Gitleaks scan when Gitleaks is installed.
- Optional local Trivy filesystem scan when Trivy is installed.
- GitHub CI always runs dedicated Trivy and Gitleaks steps.

The security regression tests verify protected endpoints reject anonymous/malformed authentication, invalid realtime authentication is rejected, authentication tokens are not reflected in response headers, and dangerous credentialed wildcard CORS is not enabled.

### Multiplayer

- Existing realtime unit/integration tests.
- Full-game server-engine simulation across 2, 3, 4 and 6 player matches.
- State invariants after every action.
- Duplicate dice-roll rejection.
- Duplicate/stale move rejection.
- Completion/placement integrity.
- Existing reconnect race regression coverage under `services/realtime/tests`.

Default local run:

```powershell
./scripts/test-multiplayer.ps1 -SimulationGames 200
```

CI runs a larger simulation.

### UI

- Dedicated responsive Flutter game-screen checks.
- Screen sizes currently include 360x640, 360x800, 390x844, 412x915, 768x1024 and 1366x768.
- Flutter exceptions/overflow failures cause the suite to fail.
- Full Flutter widget suite is rerun.
- Admin production build is checked.

The current UI gate detects programmatic layout/overflow failures. Pixel/golden baselines can be added later for selected stable screens when the UI design is considered visually locked.

### Load

- Existing in-process REST/API concurrent load simulation.
- Larger multiplayer full-game stress simulation.
- Failure-rate threshold from the existing load test remains enforced.

## 3. Required local tools

Normal Quick/Full development requires:

- PowerShell 7 (`pwsh` recommended)
- Python 3.11+
- Flutter/Dart matching the project toolchain
- Node.js 20+
- npm

For local Security mode install:

```powershell
python -m pip install bandit pip-audit pytest pytest-asyncio httpx
```

Gitleaks and Trivy are optional locally but recommended. CI runs them independently.

Backend dependencies must also be installed:

```powershell
python -m pip install -r services/api/requirements.txt
python -m pip install -r services/realtime/requirements.txt
```

## 4. GitHub Actions automation

`.github/workflows/quality-gate.yml` runs automatically for:

1. Every pull request whose target/base branch is `main`.
2. Every direct push/commit to `main`.
3. Manual `workflow_dispatch` runs.

Therefore, if a developer works directly on `main` and pushes a commit, the complete CI quality gate runs automatically. A pull request into `main` also receives the same quality gate before merge.

The workflow contains these jobs:

- `Quick Validation`
- `Multiplayer & Reconnect`
- `Flutter UI Quality`
- `Security Gate`
- `Load & Stress Smoke`
- `Required Quality Gate`

The final `Required Quality Gate` succeeds only when all preceding quality jobs succeed.

## 5. Important: prevent merging failed code

A workflow running on a pull request does not, by itself, prevent an administrator/developer from merging a failed PR. Configure a GitHub Ruleset or branch protection rule for `main`.

Recommended repository settings:

1. Open **GitHub repository > Settings > Rules > Rulesets** (or Branches > Branch protection rules).
2. Create a rule targeting branch `main`.
3. Enable **Require a pull request before merging**.
4. Enable **Require status checks to pass**.
5. Select the status check named **Required Quality Gate** from the `LudoMaster Quality Gate` workflow.
6. Enable **Require branches to be up to date before merging**.
7. Enable **Block force pushes**.
8. Enable **Block deletions**.
9. Prefer disabling bypasses except for an emergency administrator role.

If your team intentionally allows direct pushes to `main`, CI will still run after every direct push, but it cannot stop a bad commit that has already landed. For strongest protection, disallow direct pushes and require pull requests.

## 6. Recommended policy

| Development event | Validation |
| --- | --- |
| During coding | `./scripts/test.ps1 -Mode Quick` |
| Before push | Quick |
| Pull request to `main` | Full automated GitHub quality gate |
| Direct push to `main` | Full automated GitHub quality gate after push |
| Release candidate | Full local gate + GitHub gate + manual multiplayer/device exploratory pass |

## 7. Failure handling

Do not bypass failed quality checks without documenting the reason. Fix the underlying issue or explicitly update the test when product behavior intentionally changed.

For multiplayer failures, preserve the failing seed/game count and reproduce using `tests/multiplayer/full_game_simulator.py --seed <seed> --games <count> --stress`.

For UI failures, reproduce with `flutter test test/ui_quality_test.dart --reporter=expanded` from `apps/mobile`.

For security failures, determine whether the result is a vulnerable application dependency, transitive dependency, false positive, or accepted temporary risk before suppressing it.

## 8. What automation cannot completely replace

Automated validation substantially reduces regressions but does not guarantee zero bugs. Before production releases, still perform exploratory testing on representative Android/iOS devices and real network conditions, particularly background/resume, Wi-Fi-to-mobile switching, low-memory devices, push/voice/payment platform integrations, and store-specific behavior.
