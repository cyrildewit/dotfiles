#Requires -Version 5.1

<#
.SYNOPSIS
    Fonts the configuration asks for by name.

.DESCRIPTION
    The Windows counterpart to install/macos/common/fonts.sh. A missing font is
    not an error anywhere, it just leaves an application falling back to a
    default without saying so.

    Homebrew ships the whole JetBrains Mono Nerd Font family as one cask. The
    nerd-fonts bucket splits it into three manifests, one per variant, each
    installing the files its own name matches. All three are listed so the
    family is the same on both systems and no application asks for a variant
    that is not there. The cost is the same zip downloaded three times, since
    scoop caches per app rather than per url.

    NFM, the monospace variant, is the one this repository names anywhere.
    home/dot_config/ghostty/config asks for `JetBrainsMono NFM Regular`, though
    that file never reaches a Windows host, since chezmoiignore.d/windows drops
    it.

    The manifests install per user and register the font under HKCU, so this
    needs no elevation on Windows 10 1809 or later. Anything older can only
    install a font for all users, and the manifest aborts and says so rather
    than half-installing.

    nerd-fonts is a bucket beyond the one scoop ships with. Adding it clones it
    with git, which dependencies.ps1 has installed by the time this runs, since
    chezmoi runs every run_once_before_ script ahead of the unprefixed ones
    whatever their numbers say. A CI run gets git from the runner image instead.

    Written for Windows PowerShell 5.1. No ternaries and no null-coalescing.

    Reads DOTFILES_DEBUG to trace every statement and CI to resolve packages
    instead of installing them, the same as its bash counterpart.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:DOTFILES_DEBUG) {
    Set-PSDebug -Trace 1
}

$Buckets = @(
    'nerd-fonts'
)

$Packages = @(
    'JetBrainsMono-NF'
    'JetBrainsMono-NF-Mono'
    'JetBrainsMono-NF-Propo'
)

function Get-ScoopRoot {
    <#
    .DESCRIPTION
        Print where scoop keeps itself. Honours a pre-set SCOOP, which is how
        an existing install can already have been moved off the profile.
    #>

    if ($env:SCOOP) {
        return $env:SCOOP
    }

    # USERPROFILE rather than $HOME, for the reason the skills linker gives:
    # $HOME is built from HOMEDRIVE and HOMEPATH, which a managed machine can
    # point at a network share.
    return (Join-Path $env:USERPROFILE 'scoop')
}

function Enable-Scoop {
    <#
    .DESCRIPTION
        Put the scoop shims on PATH for the remainder of this script.

        Repeated from scoop.ps1 rather than shared with it. The scripts under
        install/ are standalone, and chezmoi runs them as siblings, so a scoop
        that script installed mid-apply is not on the PATH this one inherited.
    #>

    $shims = Join-Path (Get-ScoopRoot) 'shims'

    if (-not (Test-Path -LiteralPath $shims -PathType Container)) {
        return
    }

    if (($env:Path -split ';') -notcontains $shims) {
        $env:Path = "$shims;$env:Path"
    }
}

function Test-CI {
    <#
    .DESCRIPTION
        Report whether this is a continuous integration run. CI resolves
        packages rather than installing them. That still catches a renamed or
        misspelled name without paying for the download.
    #>

    return ($env:CI -eq 'true')
}

function Test-BucketAdded {
    <#
    .DESCRIPTION
        Report whether a bucket is already known.

        Read off disk rather than from `scoop bucket list`, whose output has
        been a list of names in some versions and a table of objects in others.
        A bucket is a clone under the scoop root either way.
    #>

    param([Parameter(Mandatory = $true)][string] $Name)

    $bucket = Join-Path (Get-ScoopRoot) "buckets\$Name"

    return (Test-Path -LiteralPath $bucket -PathType Container)
}

function Add-MissingBuckets {
    <#
    .DESCRIPTION
        Add whichever entries of $Buckets are not known yet. Adding one that is
        already there is an error rather than a no-op, so each is checked first.
    #>

    foreach ($bucket in $Buckets) {
        if (Test-BucketAdded -Name $bucket) {
            continue
        }

        Write-Host "Adding the $bucket bucket."
        scoop bucket add $bucket

        # Checked by outcome, for the reason Test-PackageInstalled gives.
        # Failing here rather than at the install names the actual problem,
        # which is usually that git is missing.
        if (-not (Test-BucketAdded -Name $bucket)) {
            throw "scoop bucket add $bucket did not add the bucket."
        }
    }
}

function Test-PackageInstalled {
    <#
    .DESCRIPTION
        Report whether a package is already present.

        Read off disk rather than from `scoop list`, which prints a formatted
        table and, being a script rather than a process, leaves $LASTEXITCODE
        saying nothing about how it went. An app directory with a `current`
        link is what an installed package is.

        This answers whether scoop installed the font, not whether the font is
        on the machine. A family dropped into the user font directory by hand
        is invisible here and gets installed again alongside itself, which
        costs a download and changes nothing.
    #>

    param([Parameter(Mandatory = $true)][string] $Name)

    $current = Join-Path (Get-ScoopRoot) "apps\$Name\current"

    return (Test-Path -LiteralPath $current)
}

function Test-ManifestKnown {
    <#
    .DESCRIPTION
        Report whether an added bucket carries a manifest for a package, which
        is what `brew info` is used to answer on the macOS side.

        Read off disk rather than from `scoop cat` or `scoop info`. Both print
        through the host in some versions rather than down the pipeline, and
        host output is nothing a script can capture, so a check built on it
        would report every package missing. A manifest is a json file in a
        bucket clone. Official buckets keep them under `bucket` and third-party
        ones sometimes at the root, so both are searched.
    #>

    param([Parameter(Mandatory = $true)][string] $Name)

    $buckets = Join-Path (Get-ScoopRoot) 'buckets'

    foreach ($pattern in @("*\bucket\$Name.json", "*\$Name.json")) {
        $found = Get-ChildItem -Path (Join-Path $buckets $pattern) -ErrorAction SilentlyContinue

        if ($found) {
            return $true
        }
    }

    return $false
}

function Install-MissingPackages {
    <#
    .DESCRIPTION
        Install whichever entries of $Packages are still missing, batched into
        a single scoop invocation.
    #>

    $pending = @($Packages | Where-Object { -not (Test-PackageInstalled -Name $_) })

    if ($pending.Count -eq 0) {
        Write-Host 'Fonts are already present.'
        return
    }

    if (Test-CI) {
        Write-Host "Resolving: $($pending -join ' ')"

        foreach ($package in $pending) {
            if (-not (Test-ManifestKnown -Name $package)) {
                throw "no bucket carries a manifest for $package."
            }
        }

        return
    }

    Write-Host "Installing: $($pending -join ' ')"
    scoop install @pending

    $failed = @($pending | Where-Object { -not (Test-PackageInstalled -Name $_) })

    if ($failed.Count -gt 0) {
        throw "scoop install did not install: $($failed -join ' ')"
    }
}

function Invoke-Main {
    <#
    .DESCRIPTION
        Ensure the fonts are installed.
    #>

    Enable-Scoop

    if (-not (Get-Command -Name 'scoop' -ErrorAction SilentlyContinue)) {
        throw 'scoop is not on PATH. install/windows/common/scoop.ps1 runs before this and should have installed it.'
    }

    Add-MissingBuckets
    Install-MissingPackages
}

# Dot-sourcing the file gets the functions and nothing else, so it can be
# tested without installing anything on the machine running the tests.
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Main
}
