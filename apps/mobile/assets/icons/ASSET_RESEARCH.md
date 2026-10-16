# 3D UI asset selection

Reviewed 2026-10-16 against the supplied royal-blue Ludo screenshots.

## Integrated: Microsoft Fluent UI Emoji, 3D

- Source: https://github.com/microsoft/fluentui-emoji
- License: MIT; full notice bundled in fluent_3d/LICENSE.txt.
- Selected 19 transparent PNG renders: game dice, coin, gem, crown, gift, trophy,
  globe, shield, heart, robot, friends, house, calendar, chat, sparkles, medal,
  target, money bag, controller.
- Each source URL is pinned to a commit and has a SHA-256 digest in
  fluent_3d/manifest.json. These are rendered 3D images, not live mesh models.
- Served from Flutter assets, with no remote image requests or extra runtime.
- Integrated in GameSymbol, RoyalMode, RoyalNavigation, ArenaHero, and the daily
  treasure card. Utility glyphs retain the existing vector/Material fallback.

## Other suitable packages researched

| Pack | Fit | Decision |
| --- | --- | --- |
| [Glossy 3D Game Icons, The Crypt Studios](https://semajh.itch.io/glossy-3d-icons) | 70 game-shop/reward/menu icons, clean and outlined transparent PNG variants | Strong arcade-style option; paid download, not purchased or bundled |
| [3D Game Icon Set, Flat Icons](https://flat-icons.com/downloads/3d-game-icon-set/) | 30 gaming props, including crowns, treasure chests, gems; PNG and editable 3D formats | Suitable for a larger custom-art pipeline; paid, not purchased or bundled |
| [Icons8 3D Fluency](https://icons8.com/icons/3d-fluency) | Broad, consistent dimensional UI coverage | Not bundled; confirm chosen license and attribution requirements before adoption |
| [Kenney Game Icons](https://kenney.nl/assets/game-icons) | CC0 utility assets | Useful for supporting UI, but its 2D style is less close to the supplied glossy screenshots |

## Animation research and implementation

- [Rive](https://www.rive.app/editor): interactive animation/state-machine authoring
  with Flutter runtime support. Suitable for future bespoke chest-open and
  character animations; not installed because no matching authored .riv file
  is part of this project.
- [Coins Money Reward Prize, Mr.Futuristic](https://lottiefiles.com/free-animation/coins-money-reward-prize-qXAw3qhcL0):
  reward-motion reference listed under the Lottie Simple License. Not bundled;
  a standalone reward clip would not replace the interactive lobby behavior.
- Implemented native Flutter motion: slow floating and rocking for decorative
  props; pointer-driven perspective tilt on mode artwork; press and hover
  feedback from existing surfaces; perspective lift/tumble of the lobby dice.
- The dice remains cosmetic and does not alter match state or wallets.
- Decorative art is excluded from semantics and hit testing where appropriate.
  Floating controllers respect reduced motion and TickerMode; dice tumbling
  respects reduced motion. No new animation package dependency.
