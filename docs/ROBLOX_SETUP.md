# Shatterbound — Roblox setup checklist

The codebase is live-ready, but several Roblox experience settings and asset IDs live outside GitHub.

## Required before public launch

1. Publish the place/experience.
2. In Creator Dashboard, set the place **maximum players to 12**. Roblox documents that `Players.MaxPlayers` is configured through place settings, not runtime scripts.
3. Keep Avatar settings compatible with player avatars. The combat fallback supports both common R6/R15 shoulder rigs, although R15 is the recommended visual target.
4. Enable private servers if desired. Private-server owners automatically receive the Shatterbound control panel.
5. For persistent-data testing in Studio, enable Studio access to API services only on an appropriate test version. Never casually point destructive test code at production data.
6. Create original animations, sounds, icons, thumbnails, gamepasses, and developer products before launch. The game has procedural/fallback combat presentation, but bespoke assets are still needed for true final-release production polish.

## Monetization IDs

Edit:

`src/ReplicatedStorage/Shared/MonetizationConfig.lua`

All IDs intentionally default to `0`.

Suggested non-pay-to-win offers:

- VIP Fighter pass — cosmetic status / visual rewards.
- Emote Pack pass — cosmetic emotes.
- 500 / 1,700 / 6,000 coin developer products.
- Paid private servers through Creator Dashboard.

Developer-product receipts are granted on the server through `MarketplaceService.ProcessReceipt`.

## Current controls

### Keyboard / mouse

- M1 — basic attack.
- F — hold block.
- 1 / 2 / 3 — character abilities.
- G — ultimate.
- T — optional lock-on.
- M — fighter hub.
- V — emote wheel.
- Hold jump during fourth M1 — uppercut.
- Fourth M1 while airborne — downslam.

### Gamepad

- RT — M1.
- LT — block.
- X / Y / B — abilities.
- LB — ultimate.
- R3 — lock-on.
- View/Select — fighter hub.
- D-pad down — emotes.

### Touch

Combat HUD provides attack, block, all three abilities, ultimate, lock-on, menus, and emotes.

## Data

Persistent profile:

- kills
- deaths
- playtime
- best streak
- coins
- level / XP
- owned / selected fighters
- daily reward streak
- daily and weekly quests

Global kills use an OrderedDataStore.

## Testing order

1. Start `rojo serve`.
2. Connect Studio.
3. Start a 2-player local server test.
4. Verify both players appear in the safe pavilion.
5. Walk into the courtyard and test block direction.
6. Test the full 4-M1 string, uppercut and downslam.
7. Test all three Kairo abilities.
8. Fill ultimate through damage and use Heavenbreaker.
9. Verify death, 3-second respawn, kills and streaks.
10. Verify mobile/controller emulation before publishing.
