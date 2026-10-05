# Publish Tiny Town and connect its destinations

## Required Roblox setup

1. Publish this lobby as the experience's **start place**.
2. In the same experience, create and publish four other places: Arena, Dojo,
   Rooftops and Training Lab. Use distinct places, rather than four IDs pointing
   to the same place. Build each destination's gameplay separately.
3. Copy each destination's **Place ID**, not its Universe/Experience ID.
4. Edit the four `PlaceId = 0` fields in
   `src/ReplicatedStorage/TownShared/TownConfig.lua`, commit, sync and publish the
   lobby. Changing place IDs/group sizes uses a new queue namespace; old tickets
   expire. Deploy queue configuration consistently across lobby servers.
5. Set each destination's maximum players at least as high as its `MaxPlayers`.
   Configure the lobby capacity in Creator Dashboard; a script cannot set it.
6. Choose the destination access settings you need. **Secure within universe
   only** is appropriate for places entered through this server teleport flow.
7. Launch the lobby in the **Roblox app**, rather than Studio, for real travel.

The lobby code belongs only in the start place. Syncing this same lobby project
to every destination would put another town there rather than your destination
gameplay. Do not enable third-party teleports for this same-experience setup.

`MinPlayers` and `MaxPlayers` control grouping, not round rules or win conditions.
There is no round system or destination combat implementation in this project.

## Studio checks

1. In edit view, confirm all four buildings, roads and trees are present.
2. Press Play; confirm the spawn faces the plaza and all signs are readable.
3. Walk into each building. Join via the entrance prompt, then via the inner pad.
4. Cancel; confirm you remain out of the queue while standing on the pad. Step
   out and back in to rejoin.
5. Open the directory and follow a destination marker.
6. Start a local server with two players. Confirm one player cannot remove the
   other's ticket and queues remain independent.
7. Use Studio's device emulator for phone, tablet and gamepad layouts. Test
   portrait and landscape, directory scrolling, movement and Leave controls.

Studio preview uses the same queue reducer with a local in-memory adapter and a
minimum of one player. It does not require live API access to preview the town.

## Published cross-server checks

1. Use separate test accounts in **two different live lobby server instances**.
   A local multi-client Studio test does not prove cross-server matching.
2. Join Dojo from each server. Confirm the shared waiting count and that both
   players arrive in the same reserved destination server (`game.JobId`).
3. Repeat for the other destinations, including the single-player Training Lab.
4. Join different destinations simultaneously; confirm no group crosses queues.
5. Cancel before departure, then reconnect. Confirm no stale ticket teleports
   the new session.
6. Disconnect a queued client; confirm its ticket disappears within 45 seconds
   even if graceful cleanup fails.
7. Check server Output and MemoryStore observability for throttling. Counts are
   cached (up to about 20 seconds on otherwise idle lobbies) and are not exact
   instantaneous global presence counts.

The queue checks minimum size again when committing a reservation. Players can
still disconnect after that point, so a departure group can arrive below its
original minimum. Roblox can also separate console users who disable cross-play
from other platforms; a shared reserved code cannot override Roblox's policy.

## Failures and operational limits

- Unconfigured, duplicate or same-as-lobby Place IDs keep that live queue closed.
- A failed reservation releases the group in its original queue order.
- Source-server heartbeat expiry removes abandoned tickets after 45 seconds.
- A crashed reservation owner releases claims after its 30-second lease expires.
- Ready assignments expire after 120 seconds; they are removed rather than
  recycled while a teleport could still be in flight.
- Temporary MemoryStore failures back off and expose a reconnecting state.
- A failed teleport retries the **same** reserved server, with a longer delay
  for `Flooded`, up to three attempts. A final failure requires rejoining.
- Queue state TTL is 150 seconds and refreshed while active. Graceful shutdown
  removes local tickets; expiration handles crashes.
- Capacity is deliberately 48 tickets and 4 active groups per destination. This
  is a small-launch design, not an unlimited matchmaking service.
- No player currency, purchases, profile storage, external HTTP service or paid
  hosting is required. Only Roblox's native services are used.

## Current official references

Checked October 5, 2026:

- [Memory stores and quotas](https://create.roblox.com/docs/cloud-services/memory-stores)
- [MemoryStoreHashMap](https://create.roblox.com/docs/reference/engine/classes/MemoryStoreHashMap)
- [Teleport between places](https://create.roblox.com/docs/projects/teleport)
- [TeleportService](https://create.roblox.com/docs/reference/engine/classes/TeleportService)
- [ProximityPrompt](https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt)
- [UI position and size](https://create.roblox.com/docs/ui/position-and-size)
- [Rojo project format](https://rojo.space/docs/v7/project-format/)

Reserved server access codes are never placed in our client remotes or teleport
data. Teleport data includes routing labels only; do not use it to grant secure
progress, inventory or currency at a destination.
