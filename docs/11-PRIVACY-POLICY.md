# Ludo Play privacy policy

## Publication status

Published on 9 October 2026. The policy covers the actual account, device,
gameplay, support, optional purchase, and local-diagnostics implementation.
The user confirmed `arjuntechstar@gmail.com` as the public privacy contact.
The policy names Ludo Play and its existing Android package.

Public URLs for Play Console:

- Privacy policy: `https://api-ludo.freefiremobile.space/privacy-policy`
- External deletion instructions: `https://api-ludo.freefiremobile.space/delete-account`

These are standard HTML pages with no login, tracking script, editable policy,
PDF download, or geographic access rule. The existing domain supplies HTTPS.
They are served by Nginx separately from the game API.

The app opens the policy from Settings and the sign-in/sign-up dialog. It includes
the text offline and a link to the public page. The JSON file is the single source
for both the app and the HTML page:

- `apps/mobile/assets/legal/privacy_policy.json`
- `tools/render_privacy_policy.py`
- Generated output: `web/legal/privacy-policy.html` and `web/legal/delete-account.html`
- VPS publisher: `tools/publish_privacy_policy.py`

The previous signed build `1.0.4+5` does not include these links. The new
`1.0.5+6` release includes the final offline policy, public policy link, privacy
contact, and external deletion link. See `apps/mobile/RELEASE.md` for the bundle
verification and upload path.

To update the text or contact, edit the JSON and generate the HTML using
`python tools/render_privacy_policy.py`. Upload both pages to
`/tmp/ludo-legal/`, then run the publisher on the VPS. It backs up the Nginx
configuration, checks it before reloading, and leaves the API process running.
The pages use `Cache-Control: no-transform` and `email_off` HTML comments so
Cloudflare does not hide the privacy email or insert its email decoder script.

Use the public policy URL in Play Console's Privacy policy field. Because the app
creates accounts, also use the external deletion URL in the account-deletion
field. [Google's User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311)
requires both and requires the Data safety answers to match actual behavior.

## Account deletion correction

The user authorized the correction with “Do what is correct.” It was deployed
to `/opt/api-ludo` after backing up the database and code. The endpoint operates
only when the account owner confirms deletion; deployment does not delete
existing player accounts.

Deletion removes login identities and hashes, device/installation and session
records, username, inventory, personal reward/mission/achievement/season progress,
notifications, invitations, friendships, blocks, matchmaking tickets and room/club
memberships. The profile becomes Deleted User with default avatar/country and
reset levels/statistics. Counterpart notifications for removed invitations are
also removed.

Shared room and club ownership transfers to remaining members; empty rooms and
clubs are removed. Unstarted championship registrations are withdrawn. Match
payloads lose the deleting player's profile/chat fields, and live sockets close
with a bot replacing that seat. Deleted accounts cannot reconnect to WebSockets.
Settlement checks and locks account status so it does not recreate their personal
progress. Championship brackets preserve results for other players; deleted
participants become bots and cannot receive new prizes or final invitations.

A closed internal account/profile record, inaccessible wallet balance and ledger,
purchase receipts, safety reports, shared match results and started championship
references remain for reconciliation, fraud/safety investigations and shared-game
integrity. There is no automatic expiry for these retained records; the policy
states this and provides a contact for further requests. Earlier backup copies
expire under the hosting provider's rotation. Reapply account deletions when
restoring an old backup before reopening affected accounts.

## Verification and backups

- 79 API/realtime tests passed, including private-record cleanup, room/club
  ownership transfer, match/chat redaction, token rejection, socket closure,
  reconnect rejection and settlement after deletion.
- Flutter analysis passed for the privacy screen, settings and auth dialog.
- All 53 existing Flutter regression tests passed.
- Chrome displayed the in-app policy and contact/deletion actions.
- Both unauthenticated HTTPS public routes returned `200 text/html; charset=utf-8`.
  Chrome found all sections, the correct mailto contact, no editable fields and
  no scripts. Screenshots are under `apps/mobile/build/public-*.png` and
  `apps/mobile/build/ludo-play-privacy-*.png`.
- Disposable production QA accounts verified daily rewards (`200`), deletion
  (`200`), rejected old access tokens (`403`) and refresh tokens (`401`).
- API health remained healthy after deployment.

Backups:

- `/opt/api-ludo-backups/database-20261009T095308Z.dump`
- `/opt/api-ludo-backups/code-20261009T095308Z.tar.gz`
- Final code/database backups after restart restoration check:
  `/opt/api-ludo-backups/code-20261009T100528Z.tar.gz` and
  `/opt/api-ludo-backups/database-20261009T100528Z.dump`
- `/opt/api-ludo-backups/privacy-20261009T095621Z/`

Use the confirmed contact mailbox to handle privacy and external deletion
requests. Verify account ownership before acting on an email request. Review
Google Play Data safety and audience declarations against the actual release.
Google OAuth/Play Games and real purchases are still pending configuration;
update the policy and declarations if new SDK collection is enabled.
