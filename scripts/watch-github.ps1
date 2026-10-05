$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host ""
Write-Host "Battlegrounds GitHub watcher"
Write-Host "Repository: $repoRoot"
Write-Host "Press Ctrl+C to stop."
Write-Host ""

while ($true) {
    try {
        $branch = (git branch --show-current).Trim()

        if ([string]::IsNullOrWhiteSpace($branch)) {
            $branch = "main"
        }

        git fetch origin $branch --quiet

        $local = (git rev-parse HEAD).Trim()
        $remote = (git rev-parse "origin/$branch").Trim()

        if ($local -ne $remote) {
            $changes = git status --porcelain

            if ([string]::IsNullOrWhiteSpace($changes)) {
                Write-Host "New GitHub changes found. Pulling $branch..."
                git pull --ff-only origin $branch

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Updated successfully. Rojo will sync the changed files to Studio."
                }
                else {
                    Write-Warning "git pull failed. Resolve the Git problem before automatic syncing can continue."
                }
            }
            else {
                Write-Warning "GitHub has new changes, but this PC has uncommitted local changes."
                Write-Warning "Automatic pull was skipped to prevent overwriting your work."
            }
        }
    }
    catch {
        Write-Warning $_.Exception.Message
    }

    Start-Sleep -Seconds 5
}
