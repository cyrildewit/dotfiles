#Requires -Version 5.1

# Point the PowerShell profile at the chezmoi-managed one in ~/.config/powershell.
#
# The path comes from $PROFILE, not a fixed ~/Documents location, because
# Documents here redirects into OneDrive under a localised name ("Documenten"),
# so chezmoi cannot place the file by a static source path. This resolves
# $PROFILE on the machine it runs on and writes a bootstrap line there.
#
# The bootstrap only dot-sources the real profile, so it never changes as
# aliases and functions come and go: those live in files this never touches. It
# sits in a marked block, so a re-run replaces it in place rather than appending
# a second copy. The Test-Path guard keeps a shell that OneDrive synced to a
# machine chezmoi has not set up from erroring on a profile that is not there.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$beginMarker = '# >>> chezmoi powershell-profile >>>'
$endMarker = '# <<< chezmoi powershell-profile <<<'

$block = @(
    $beginMarker
    '$chezmoiProfile = Join-Path $env:USERPROFILE ''.config\powershell\profile.ps1'''
    'if (Test-Path -LiteralPath $chezmoiProfile) { . $chezmoiProfile }'
    $endMarker
) -join "`r`n"

$profilePath = $PROFILE.CurrentUserCurrentHost
$profileDir = Split-Path -Parent $profilePath

New-Item -ItemType Directory -Path $profileDir -Force | Out-Null

$existing = if (Test-Path -LiteralPath $profilePath) {
    Get-Content -LiteralPath $profilePath -Raw
} else {
    ''
}
if ($null -eq $existing) { $existing = '' }

$blockPattern = "(?s)$([regex]::Escape($beginMarker)).*?$([regex]::Escape($endMarker))"

if ($existing -match $blockPattern) {
    # A script block evaluator, so a `$` in the block is never read as a regex
    # replacement token.
    $updated = [regex]::Replace($existing, $blockPattern, { $block })
} else {
    $trimmed = $existing.TrimEnd()
    $updated = if ($trimmed.Length -gt 0) { "$trimmed`r`n`r`n$block`r`n" } else { "$block`r`n" }
}

if ($updated -eq $existing) {
    Write-Host "set-powershell-profile: the bootstrap is already in $profilePath"
    return
}

# UTF-8 without a BOM: a profile is code, and 5.1 reads a BOM-less UTF-8 file fine.
[System.IO.File]::WriteAllText($profilePath, $updated, (New-Object System.Text.UTF8Encoding $false))
Write-Host "set-powershell-profile: wrote the bootstrap to $profilePath"
