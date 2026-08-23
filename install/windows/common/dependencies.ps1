#Requires -Version 5.1

<#
.SYNOPSIS
    Core scoop packages these dotfiles rely on.

.DESCRIPTION
    The Windows counterpart to install/macos/common/dependencies.sh. Installs
    the command-line packages the configuration in this repository expects to
    find. Anything that needs a bucket other than main, or any setup after the
    install, gets its own script rather than a line here.

    chezmoi is listed even though it is what runs this script. setup.ps1 has
    already installed it through scoop, and naming it here means the two agree
    about who owns it, so `scoop update` keeps it current. That is the same
    reasoning dependencies.sh gives for listing the chezmoi formula.

    git earns its line twice over. chezmoi needs it to clone and update this
    repository, and home/dot_config/git is written for it.

    gh matches the macOS list, so the same tooling answers on either system.

    1password-cli is what home/dot_config/git/config-personal.tmpl needs.
    That template calls onepasswordRead, so chezmoi shells out to op while it
    renders the file, and a machine without op fails the apply outright rather
    than skipping something. Installing it from a run_once_before_ script puts
    op on disk before any file is written. A CI run never reaches that branch,
    since the template checks .ci first.

    op is found because the scoop shims directory is already on the PATH
    chezmoi inherited, and a new shim inside a directory that is already there
    needs no PATH change. The one case that breaks is a scoop this same apply
    installed, which is the wrinkle scoop.ps1 documents.

    The 1Password desktop app that sits beside the CLI on macOS has no line
    here, because no bucket carries a manifest for it. onepassword.ps1 installs
    it with winget instead, and sets out what that costs.

    zsh is the one entry on the macOS list with no counterpart here. Nothing on
    a Windows host reads the zsh configuration, which is why
    chezmoiignore.d/windows drops it.

    Written for Windows PowerShell 5.1. No ternaries and no null-coalescing.

    Reads DOTFILES_DEBUG to trace every statement and CI to resolve packages
    instead of installing them, the same as its bash counterpart.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:DOTFILES_DEBUG) {
    Set-PSDebug -Trace 1
}

$Packages = @(
    '1password-cli'
    'chezmoi'
    'gh'
    'git'
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

function Test-PackageInstalled {
    <#
    .DESCRIPTION
        Report whether a package is already present.

        Read off disk rather than from `scoop list`, which prints a formatted
        table and, being a script rather than a process, leaves $LASTEXITCODE
        saying nothing about how it went. An app directory with a `current`
        link is what an installed package is.

        Only the per-user root is searched. scoop is used here precisely
        because it needs no elevation, so nothing installs --global.
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
        Write-Host 'scoop dependencies are already present.'
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
        Ensure the scoop dependencies are installed.
    #>

    Enable-Scoop

    if (-not (Get-Command -Name 'scoop' -ErrorAction SilentlyContinue)) {
        throw 'scoop is not on PATH. install/windows/common/scoop.ps1 runs before this and should have installed it.'
    }

    Install-MissingPackages
}

# Dot-sourcing the file gets the functions and nothing else, so it can be
# tested without installing anything on the machine running the tests.
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Main
}
