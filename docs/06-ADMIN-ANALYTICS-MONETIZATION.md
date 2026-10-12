# Admin, Analytics & Monetization

## Admin Dashboard

-   KPI overview.
-   User lookup and safe account actions.
-   Match lookup with event timeline for disputes.
-   Reports/moderation queue.
-   Suspend/unsuspend with reason and expiry.
-   Economy catalog management.
-   Cosmetic/theme configuration.
-   Missions/daily reward configuration.
-   Season management.
-   Tournament configuration.
-   Announcement/inbox/push composer.
-   Feature flags and remote config with environment separation.
-   App version/minimum-version/maintenance controls.
-   Audit logs. Never provide an admin control to predetermine a
    specific player's dice.

## Analytics Events

app_open, signup, login, mode_selected, matchmaking_started,
matchmaking_completed, matchmaking_cancelled, match_started, roll, move,
capture, reconnect, match_finished, match_abandoned, mission_claimed,
item_viewed, purchase_started, purchase_completed, report_submitted.

Avoid sending unnecessary PII. Define event schema/version.

## Metrics

DAU/MAU, D1/D7/D30 retention, match starts/completion, queue time, match
duration, disconnect/reconnect, crash-free sessions, websocket errors,
latency percentiles, mode popularity, bot usage, reward/economy
sources/sinks and purchase funnel.

## Monetization

Prefer cosmetics, themes, ad-removal and optional season content. Ads,
if enabled, must not interrupt a live turn or cause gameplay
disadvantage. Purchases are validated server-side. Clearly separate paid
cosmetics from game fairness.
