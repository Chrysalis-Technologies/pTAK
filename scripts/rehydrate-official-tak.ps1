<#
.SYNOPSIS
    Rebuilds the official TAK Docker bundle structure from the offline-transfer snapshots.

.DESCRIPTION
    Copies the contents of official-tak/offline-transfer back into the live folders that
    the Docker stack expects:
        - takdata-runtime  -> official-tak/takdata
        - takdata-bundle   -> official-tak/takserver-docker-5.2-RELEASE-16/takdata
        - tak-certs        -> official-tak/takserver-docker-5.2-RELEASE-16/tak/certs/files

    By default the script refuses to overwrite existing payloads unless -Force is supplied.
    Use -SourceRoot if the offline-transfer directory is located elsewhere (for example on
    a removable drive).
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$SourceRoot,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path (Join-Path $scriptRoot '..')

if (-not $SourceRoot) {
    $SourceRoot = Join-Path $repoRoot 'official-tak/offline-transfer'
}

if (-not (Test-Path $SourceRoot)) {
    throw "Source root '$SourceRoot' was not found. Provide -SourceRoot pointing to the offline-transfer directory."
}
$SourceRoot = (Resolve-Path $SourceRoot).Path

$targets = @(
    @{
        Name     = 'Runtime takdata volume'
        Source   = 'takdata-runtime'
        Dest     = 'official-tak/takdata'
        Preserve = @('README.md')
    },
    @{
        Name     = 'Bundle takdata seed'
        Source   = 'takdata-bundle'
        Dest     = 'official-tak/takserver-docker-5.2-RELEASE-16/takdata'
        Preserve = @('README.md')
    },
    @{
        Name     = 'TAK cert material'
        Source   = 'tak-certs'
        Dest     = 'official-tak/takserver-docker-5.2-RELEASE-16/tak/certs/files'
        Preserve = @('README.md')
    }
)

$summary = @()
foreach ($target in $targets) {
    $src = Join-Path $SourceRoot $target.Source
    if (-not (Test-Path $src)) {
        Write-Warning "Skipping '$($target.Name)' because '$src' is missing."
        continue
    }

    $dest = Join-Path $repoRoot $target.Dest
    if (-not (Test-Path $dest)) {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
    }

    $existingPayload = Get-ChildItem -Path $dest -Force | Where-Object { $target.Preserve -notcontains $_.Name }
    if ($existingPayload.Count -gt 0 -and -not $Force) {
        throw "Destination '$($target.Dest)' already contains files. Re-run with -Force once you have a backup."
    }

    if ($PSCmdlet.ShouldProcess($dest, "Sync from $src")) {
        if ($existingPayload) {
            $existingPayload | Remove-Item -Recurse -Force
        }

        $sourceItems = Get-ChildItem -Path $src -Force
        foreach ($item in $sourceItems) {
            $targetPath = Join-Path $dest $item.Name
            if ($item.PSIsContainer) {
                Copy-Item -Path $item.FullName -Destination $targetPath -Recurse -Force
            } else {
                Copy-Item -Path $item.FullName -Destination $targetPath -Force
            }
        }
    }

    $summary += [PSCustomObject]@{
        Target      = $target.Name
        SourcePath  = $src
        DestPath    = $dest
    }
}

if ($summary.Count -eq 0) {
    Write-Warning 'No directories were synchronized. Verify that your offline-transfer snapshot contains data.'
} else {
    Write-Host ''
    Write-Host 'Rehydration summary:' -ForegroundColor Cyan
    $summary | Format-Table -AutoSize
}
