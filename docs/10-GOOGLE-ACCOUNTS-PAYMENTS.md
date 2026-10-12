# Ludo Play: Google accounts and purchases

## Implementation and deployment status

The API integration is deployed to `api-ludo.freefiremobile.space` as of
2026-10-09. `/api/v1/auth/providers` now responds successfully; it currently
reports both providers disabled because no client IDs are configured. The signed
Android bundle is `1.0.4+5`. Its Play Games project ID defaults to `0` until the
numeric project ID is supplied at build time.

Google setup requires your public Web OAuth client ID, Android credentials
matching package `com.ludomaster.app.mobile` and the Play **app signing** SHA-1,
and the Play Games numeric project ID. Keep client secrets and service account
keys only in the private VPS configuration. Internal-track testers also need
access to unpublished Play Games credentials. See
[Play Games setup](https://developer.android.com/games/pgs/console/setup).

- App name, launcher artwork, browser loading screen, in-app startup loader, and
  Android splash artwork use Ludo Play. The existing package stays
  `com.ludomaster.app.mobile` so Play Console updates go to the same app.
- Google sign-in is available from login and profile. Connecting a new Google
  identity preserves the current player ID, wallet, inventory, and progress.
  Signing into an already connected Google identity opens that existing player;
  guest progress is not merged into it. Email accounts are never automatically
  linked by matching an email address.
- Google Play Games has an Android native sign-in bridge and server code exchange.
  It is a separate identity provider; connect both providers from the same player
  profile to use the same progress. Play Games sign-in runs on Android.
- Android coin, gem, bundle, and cosmetic checkout uses Google Play Billing.
  Displayed prices come from Google Play in the player's local currency.
  The API verifies purchase state, app package, product, and the hashed player
  account before delivering. Pending, cancelled, and invalid payments do not
  grant anything. A token retry does not grant currency twice. Consumables are
  consumed and permanent items acknowledged only after fulfillment.
- Get Coins offers a Store link when ads are unavailable or the daily ad cap is
  reached. Five rewards per UTC day is the default cap. Real rewarded ads are
  currently unavailable: no AdMob SDK or server reward verification is installed.
  The simulated ad flow is allowed only with an explicit development setting.

Google Play Billing is the payment gateway for digital purchases in the Play
app. Google's [Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738)
requires it unless an applicable enrolled exception permits another billing
method. Web checkout is not enabled. Chrome can preview the shop and account UI;
native Play checkout and Play Games sign-in require a real Android device.

## 1. Google account sign-in

In Google Cloud Console, configure the OAuth consent screen and create:

1. A **Web application** OAuth client. Add `http://localhost:8080` as an authorized
   JavaScript origin for local Chrome testing, plus the eventual web app's origin.
   This is the frontend origin, not automatically the API hostname.
2. Android OAuth clients with package `com.ludomaster.app.mobile` and the SHA-1
   fingerprints for the debug certificate, upload certificate if sideloading,
   and Play Console **App integrity > App signing key certificate** for installs
   from Google Play. The app signing certificate differs from the upload key.
3. Set `GOOGLE_WEB_CLIENT_ID` on the API to the public Web client ID. Additional
   accepted ID token audiences may be listed in `GOOGLE_CLIENT_IDS` as a JSON list.

The app fetches public configuration from `/api/v1/auth/providers`; OAuth secrets
are never returned. Google verifies signatures, expiry, issuer, and audience on
the API. See [Google backend verification](https://developers.google.com/identity/sign-in/web/backend-auth).

## 2. Google Play Games

Configure Play Games Services in the Play Console for this package, link the
Android OAuth credentials and a server Web OAuth client, and add test players
before publishing those credentials. See [server access](https://developer.android.com/games/pgs/android/server-access).

- API: set `GOOGLE_PLAY_GAMES_CLIENT_ID` and its private
  `GOOGLE_PLAY_GAMES_CLIENT_SECRET` in the VPS environment.
- Android: set `PLAY_GAMES_APP_ID` to the numeric Play Games project ID in the
  local `android/gradle.properties`, or pass the Gradle project property via
  `ORG_GRADLE_PROJECT_PLAY_GAMES_APP_ID`. It defaults to `0`, which disables
  the native integration until configured. Rebuild after changing it.
- Play Games Services publishing and the app release track are separate setups.
  Verify both with accounts included in their tester lists.

## 3. Google Play Billing

1. Complete the payments profile in Play Console. Enable Android Publisher API
   in Google Cloud, create a service account, and grant that account the app's
   required purchase/order access in Play Console. Store its JSON key privately
   on the VPS at `/opt/api-ludo/secrets/google-play-service-account.json`, readable
   by the API service user only. Never include this file in the app or repository.
2. Create and activate these **one-time products** with purchase options available
   to the intended countries. Set final prices in Play Console; API USD catalog
   values are reference metadata and never replace the Play checkout price.

| Product ID | Delivery | Type |
| --- | --- | --- |
| `coin_pouch_5k` | 5,000 coins | Consumable |
| `coin_sack_30k` | 30,000 coins | Consumable |
| `coin_chest_100k` | 100,000 coins | Consumable |
| `gem_handful_50` | 50 gems | Consumable |
| `gem_bag_300` | 300 gems | Consumable |
| `gem_vault_1000` | 1,000 gems | Consumable |
| `starter_bundle` | 20,000 coins + 100 gems | Consumable |
| `cosmetic_neon_board` | Neon Cyber Board | Permanent |
| `cosmetic_marble_board` | Royal Marble Board | Permanent |
| `cosmetic_gold_dice` | Golden Luxury Dice | Permanent |
| `cosmetic_crystal_dice` | Crystal Prism Dice | Permanent |
| `cosmetic_crown_frame` | Crown of Kings | Permanent |

3. Merge [the configuration template](../services/api/google-payments.env.example)
   into the API's existing private environment, install updated requirements,
   and set `GOOGLE_PLAY_BILLING_ENABLED=true` after access and products are ready.
   Schedule deployment/restart outside active games because current realtime
   boards are held in memory.
4. Upload a new signed bundle to internal testing. Add license testers and
   internal-track testers, opt in with the account used by Google Play, and
   install through the Play testing link. Use Google's test payment methods.
   See [billing tests](https://developer.android.com/google/play/billing/test).
5. Verify a successful coin purchase, pending payment, cancellation, reopening
   after a dropped connection, another purchase of a consumed coin product,
   permanent item restoration, equipment after buying, and rejection when a
   different player attempts to redeem the same token. Restore applies to
   permanent products and purchases still pending completion; consumed coins
   remain in the server wallet rather than being restored by the store.

## Release limits

Provider credentials, active products, native account flows, and actual checkout
have not been verified until console setup is completed. Purchases remain disabled
by default. The previous `1.0.2+3` bundle does not contain these changes.
Refund/chargeback synchronization via Google real-time developer notifications
and a voided-purchase reconciliation job still need implementation before broad
paid production rollout. Consumable refunds cannot simply be undone if the coins
have already been spent; define that policy before enabling public purchases.

iOS Google sign-in URL schemes and App Store payment verification are not configured.
The current release target is Android; web payments are a separate integration.

## Artwork

The [logo](../apps/mobile/assets/branding/ludo_play_logo.png) was created with the
built-in image generation tool. The exact final prompt and generated icon command
are recorded in [branding notes](../apps/mobile/assets/branding/README.md).
