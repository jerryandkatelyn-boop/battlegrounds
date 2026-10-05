# Shatterbound

Anime-inspired 12-player arena PvP built with Roblox + Rojo.

## Launch fighter

**Kairo — The Impact Heir**

- 4-hit M1 chain with uppercut/downslam variants
- Breakpoint Rush
- Rising Comet
- Faultline Crash
- Heavenbreaker ultimate

Players keep their own Roblox avatar. Fighters define combat kits rather than replacing avatar appearance.

## Architecture

GitHub is the source of truth for Rojo-managed code.

```text
ChatGPT -> GitHub -> local git pull -> Rojo -> Roblox Studio
```

Server authority owns damage, cooldowns, stuns, blocking, ultimate state, progression and purchases. Clients own input, HUD, camera presentation and disposable visual effects.

## Repository

```text
src/
  ReplicatedStorage/Shared/
    GameConfig.lua
    CharacterCatalog.lua
    QuestConfig.lua
    MonetizationConfig.lua
  ServerScriptService/
    Bootstrap.server.lua
    Services/
      ArenaService.lua
      CombatService.lua
      LeaderboardService.lua
      MonetizationService.lua
      ProfileService.lua
  StarterPlayer/StarterPlayerScripts/
    ClientMain.client.lua
    Client/
      HUD.lua
      Effects.lua
```

See `docs/ROBLOX_SETUP.md` before publishing.

## Local development

```powershell
rojo serve
```

Optional automatic GitHub pull watcher:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\watch-github.ps1
```
