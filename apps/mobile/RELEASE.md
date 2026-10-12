# Android release build

## Current release: Ludo Play 1.0.5+6

Package: `com.ludomaster.app.mobile`. Upload the signed bundle at
`build/app/outputs/bundle/release/app-release.aab` to the existing Play Console
app's internal testing track. Version name `1.0.5`, version code `6`, minimum
Android API `24`, target API `36`. Bundle size: 59,241,659 bytes. SHA-256:
`E237FB21344F58BD3BFB39D98597FD56A836278B1D258583F1D5936F3A1B330F`.
JAR signature verification passed. Production endpoints are embedded:
`https://api-ludo.freefiremobile.space/api/v1` and
`wss://api-ludo.freefiremobile.space`.

### Fixes in this release

- Privacy Policy is available in Settings and the sign-in/sign-up dialog, with
  the complete text included offline and a link to the public HTTPS page.
  The bundle contains the confirmed privacy contact `arjuntechstar@gmail.com`.
- Account deletion removes login/session/device details, username, personal
  progress, inventory, invitations and social connections; shared room/club
  ownership transfers. Match profile/chat fields are redacted, sockets close,
  and deleted accounts cannot reconnect or have personal progress recreated by
  match settlement. Limited transaction, safety and shared result records remain
  as disclosed in the policy.
- The local player's quadrant and player panel are always at bottom left.
  Other quadrants, token coordinates, and hit targets rotate together.
- Dice animation lasts 1.1 seconds; token movement lasts 1 second and follows
  the track tiles. The moving player's color stays active until movement ends.
  Roll counters only change on a roll, including repeated rolls of the same value.
- Input is locked while animating or awaiting a multiplayer action. Auto-move
  only selects a single legal move after an additional 0.8-second pause.
  Multiple yard tokens stay manual. Old timers are cancelled on quit/reconnect.
- Display names appear in the dashboard and offline games. Profile editing
  provides unique, case-insensitive usernames with availability checks and eight
  free avatars. Friends can be added by username; player IDs are not shown in UI.
- Signed-in accounts show Edit profile instead of Sign In / Up. Account loading
  publishes the profile before optional rewards, inventory, or notifications.
- Settings switches refresh inside the open sheet, update immediately, and save
  changes in order. Initial loading cannot overwrite a toggle the user changed.
- Rewards retry expired sessions and offer a Retry action for temporary errors.
  Daily rewards use UTC dates and serialize duplicate claims on PostgreSQL.

### API deployment and Google status

Deployed on 2026-10-09 to `/opt/api-ludo`. PostgreSQL migration
`007_progression_usernames` adds the missing progression tables and nullable
unique username. Production rewards previously failed because
`user_daily_rewards` did not exist. The live rewards endpoint now returns its
seven-day calendar successfully. `/health` returns healthy.

Private backups were saved before migration and deployment:
`/opt/api-ludo-backups/database-20261009T072916Z.dump` and
`/opt/api-ludo-backups/code-20261009T072916Z.tar.gz`.

The account-deletion correction was deployed without a schema/dependency change.
Final deployment backups: `/opt/api-ludo-backups/database-20261009T100528Z.dump`
and `/opt/api-ludo-backups/code-20261009T100528Z.tar.gz`.
The API health check passed after restart.

Public URLs for Play Console:

- Privacy policy: `https://api-ludo.freefiremobile.space/privacy-policy`
- Account deletion: `https://api-ludo.freefiremobile.space/delete-account`

Both are unauthenticated standard HTML pages with valid HTTPS. Cloudflare email
rewriting is disabled for these pages so the support contact is readable without
scripts. Nginx backup: `/opt/api-ludo-backups/privacy-20261009T095621Z/`.
See [Privacy policy and deletion notes](../../docs/11-PRIVACY-POLICY.md).

The Google provider endpoint previously returned 404; it now works. It reports
`google_enabled=false` and `play_games_enabled=false` because the API's client
IDs are empty. Play Games project ID still defaults to `0` in this bundle.
Follow [Google accounts and payment setup](../../docs/10-GOOGLE-ACCOUNTS-PAYMENTS.md).
Configure OAuth clients with the Play **app signing certificate** SHA-1, add test
players, set the API environment, and rebuild with the numeric Play Games ID.
Native sign-in, real purchases, vibration, and Android audio still require a
physical Android device check. Google Play Billing remains disabled until setup
and real payment verification are ready. Real rewarded ads are not integrated.

### Verification

Validation: 79 API/realtime tests and 53 Flutter tests passed, including account
deletion. The three deletion checks also passed after the restart-restoration fix.
Flutter analysis reported no issues. Browser screenshots under `build/ludo-play-review-*`
confirm signed-in home, free avatar selection/save, settings changes while the
sheet stays open, and both red and blue local-player board orientation.

Privacy review screenshots under `build/ludo-play-privacy-*.png` and
`build/public-*.png` confirm the in-app policy, public policy/deletion pages,
contact links, all policy sections and no editable fields or scripts. Disposable
production QA accounts verified rewards, deletion and old-token rejection.

Previous releases are archived under `build/release-archive/`, including
`ludo-play-1.0.4-5.aab`, `ludo-play-1.0.3-4.aab` and `ludomaster-1.0.2-3.aab`.
Version `1.0.4+5` contains the gameplay/profile fixes and has no privacy links.

The local preview is served at `http://localhost:8080`; its API runs at
`http://127.0.0.1:8000` using `ludo-play-review.db`, separate from production data.

### Play Console release notes

```text
<en-US>
Added a Privacy Policy and clearer account deletion controls.
Your color now stays at the bottom left of the board.
Smoother dice rolls and token movement, with improved turn timing.
Choose a display name, unique username, and free profile avatar.
Fixed rewards loading, signed-in profile controls, and settings switches.
</en-US>
```

## Build and local preview

Use Chrome for local development and testing. Start the local development API
on `127.0.0.1:8000` with browser origin `http://localhost:8080` allowed, then run
this command from `apps/mobile`:

```powershell
flutter run -d chrome --web-hostname=localhost --web-port=8080 `
  --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

If Flutter's Chrome debugger connection fails, serve the app with the same
settings using `-d web-server` and open `http://localhost:8080` in Chrome.

The local web API uses `ludomaster-web-dev.db` for development accounts and
progress. It is separate from production player data.

The emulator development default points at `10.0.2.2:8000`. Before publishing,
build with the HTTPS URL for the deployed API. If realtime runs on a different
host, also set `REALTIME_BASE_URL` to its secure `wss://` endpoint.

```powershell
flutter build appbundle --release `
  --dart-define=API_BASE_URL=https://api-ludo.freefiremobile.space/api/v1
```

Realtime uses `wss://api-ludo.freefiremobile.space` automatically. Set
`REALTIME_BASE_URL` only if realtime is hosted on a different hostname.

Release signing is configured locally in the ignored file
`android/key.properties`, using the keystore `android/ludomaster-upload.jks`.
Keep both files backed up in a private place and out of source control. Losing
the upload key can block future updates; if the app was already uploaded, reset
the Play Console upload key before using a replacement.

Increase the `+buildNumber` in `pubspec.yaml` for every Play upload.

## Previous internal-test release: 1.0.2+3

The previous internal-test update was `1.0.2+3`. Upload updates to the same
Play Console app (`com.ludomaster.app.mobile`). This update connects online match
results to player rewards, daily and weekly missions, badges, and season XP.
Championship registration now creates playable semifinal and final matches;
players enter their active board from the bracket and receive in-app notices
when their semifinal or final is ready. The Store applies equipped
board, dice, and profile frame cosmetics. The Royal Pass can be unlocked with
100 earned gems for the current season. Hall of Fame now has separate weekly,
current-season, and all-time rankings.

Online match rewards require the updated API on the VPS. Local games against
bots do not grant server currency or online mission progress. Championship
players should coordinate to join their four-player match; the board waits for
all four. Paid currency bundles remain disabled. Invite alerts appear while
the app is open. Android system push notifications for invites require Firebase
Cloud Messaging setup and are not included in this build.

Before promoting the internal-test build, install it on two different phones.
Sign in with different accounts, invite one account from a room, accept from the
Invites tab, mark the guest ready, and start the match. Confirm both phones enter
the same board, see the correct token move after each roll, and can reconnect.
Also check profile access, the three-second notices, sound and vibration on a
real device. Automated tests cannot verify device audio, haptics, or Android
system push delivery.

For the new progression features, complete an online match and confirm the
profile statistics, daily/weekly mission progress, unlocked badges, and season
XP refresh. Claim an available reward once and confirm a second claim is rejected.
Buy and equip a board or dice cosmetic and confirm it appears in a game. Check
the Royal Pass unlock cost and premium tier claims. Test a full Championship
with eight accounts: two semifinals, four finalists, the final prize awards,
and the match-ready notices. All four players must enter each board before play
starts. Check weekly and seasonal Hall of Fame rankings separately.

The backend update is deployed on the VPS; its public HTTPS health check passes.
Local validation passed 45 API tests, 19 realtime tests, and 3 relevant Flutter
widget tests; Flutter analysis reports no issues. Additional focused tests cover
mission resets, Championship notices, and unsupported Store currencies.

The previous signed `1.0.2+3` bundle is archived at
`build/release-archive/ludomaster-1.0.2-3.aab` (55,357,801 bytes).
Its SHA-256 is
`AB870EB1778C2D59E70EAC772F9318436A4B6A65776C04535EE478E5C0E51A9B`.
The generated manifest has package `com.ludomaster.app.mobile`, version code
`3`, and version name `1.0.2`; the bundle embeds the production API for all
three included architectures. Signature verification passed.

Realtime game state during active play is currently held in the API process.
A server restart interrupts active boards; verify games without deploying or
restarting the service during play. Persistent recovery of an unfinished board
still needs to be added before relying on unattended Championships.

Release builds hide the simulated rewarded-ad entry and disable paid currency
bundles until real ad verification and Google Play Billing are configured. The
production API also rejects these unverified claims. Voice chat controls are
hidden until an actual voice transport SDK is integrated; rooms and clubs remain
available.
