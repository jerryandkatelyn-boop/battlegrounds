# Battlegrounds

Roblox Battlegrounds project using GitHub + Rojo.

## Source of truth

GitHub is the source of truth for Rojo-managed scripts.

Workflow:

```text
ChatGPT -> GitHub -> git pull on development PC -> Rojo -> Roblox Studio
```

Avoid editing Rojo-managed scripts directly in Roblox Studio unless you also copy those changes back into the repository.

## Project layout

```text
default.project.json
src/
  ReplicatedStorage/
    Shared/
  ServerScriptService/
  ServerStorage/
  StarterGui/
  StarterPlayer/
    StarterPlayerScripts/
    StarterCharacterScripts/
scripts/
  watch-github.ps1
```

### File naming

Rojo maps files to Roblox script types:

- `Name.server.lua` -> Script
- `Name.client.lua` -> LocalScript
- `Name.lua` -> ModuleScript

## Safety

The Rojo project sets `$ignoreUnknownInstances` to `true` on mapped services so connecting Rojo does not remove unrelated instances that already exist in the Roblox place.

## Starting Rojo

From the repository folder:

```powershell
rojo serve
```

Then open the Rojo plugin in Roblox Studio and connect to the local server.

## Pulling ChatGPT changes automatically

Open a second PowerShell window in the repository and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\watch-github.ps1
```

The watcher checks GitHub for changes and performs a fast-forward pull when the local working tree is clean. Rojo will then detect the changed files and sync them into Studio.
