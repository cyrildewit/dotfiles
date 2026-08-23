#Requires -Version 5.1

# Subscribe each tool's skills directory to the shared skills pool at ~/.agents/skills.
# Links every pool entry into each tool dir, never overwrites a real (installer-written)
# entry, and prunes dangling pool links left after a skill is removed from the pool.
#
# Junctions rather than symlinks: a symlink needs Developer Mode or
# SeCreateSymbolicLinkPrivilege, and a managed machine grants neither. Junctions need
# no privilege, and every pool entry is a directory.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# USERPROFILE rather than $HOME: $HOME is built from HOMEDRIVE and HOMEPATH, which
# a managed machine can point at a network share.
$pool = Join-Path $env:USERPROFILE '.agents\skills'
$toolDirs = @(
    (Join-Path $env:USERPROFILE '.claude\skills')
)

function Test-Link {
    param([string] $Path)

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return $false }
    return [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
}

function Get-LinkTarget {
    param([string] $Path)

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return $null }

    # 5.1 exposes Target as a collection, 6+ as a string.
    return @($item.Target)[0]
}

function Remove-Link {
    param([string] $Path)

    # Remove-Item can follow a junction and delete what it points at, which here
    # would be skills inside the chezmoi source tree. Deleting the reparse point
    # directly cannot.
    [IO.Directory]::Delete($Path, $false)
}

if (-not (Test-Path -LiteralPath $pool -PathType Container)) {
    Write-Host "run_after_40-link-shared-skills: $pool is not a directory, skipping"
    exit 0
}

foreach ($toolDir in $toolDirs) {
    New-Item -ItemType Directory -Path $toolDir -Force | Out-Null

    foreach ($entry in Get-ChildItem -LiteralPath $pool -Force) {
        # A pool entry is itself a link into the source tree. Skip it when it no
        # longer resolves, rather than failing on a link to nothing.
        if (-not (Test-Path -LiteralPath $entry.FullName)) { continue }

        # A junction cannot point at a file. The bash half uses ln -s and does not
        # care, so skip rather than take the apply down over one stray entry.
        if (-not (Test-Path -LiteralPath $entry.FullName -PathType Container)) {
            Write-Host "run_after_40-link-shared-skills: $($entry.Name) is not a directory, skipping"
            continue
        }

        $target = Join-Path $toolDir $entry.Name

        if ((Test-Path -LiteralPath $target) -and -not (Test-Link $target)) {
            Write-Host "run_after_40-link-shared-skills: $target is a real entry, keeping it and skipping the pool link for $($entry.Name)"
            continue
        }

        if (Test-Link $target) { Remove-Link $target }
        New-Item -ItemType Junction -Path $target -Value $entry.FullName | Out-Null
    }

    foreach ($link in Get-ChildItem -LiteralPath $toolDir -Force) {
        if (-not (Test-Link $link.FullName)) { continue }

        $linkTarget = Get-LinkTarget $link.FullName
        if (-not $linkTarget) { continue }
        if (-not $linkTarget.StartsWith($pool, [StringComparison]::OrdinalIgnoreCase)) { continue }

        if (-not (Test-Path -LiteralPath $linkTarget)) { Remove-Link $link.FullName }
    }
}
