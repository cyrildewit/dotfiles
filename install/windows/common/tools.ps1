#Requires -Version 5.1

<#
.SYNOPSIS
    Optional scoop packages.

.DESCRIPTION
    The Windows counterpart to install/macos/common/tools.sh. Installs packages
    that are wanted on the machine but that nothing in this repository requires,
    so a machine without them still gets a working configuration.

    Every entry comes from main, the bucket scoop ships with, so unlike
    applications.ps1 and fonts.ps1 this adds none. Anything needing another
    bucket belongs in one of those or in a script of its own.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:DOTFILES_DEBUG) {
    Set-PSDebug -Trace 1
}

$Packages = @(
    'claude-code'
    'eza'
    'nodejs-lts'
    'vim'
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

    # USERPROFILE rather than $HOME, which is built from HOMEDRIVE and HOMEPATH
    # and can point at a network share on a managed machine.
    return (Join-Path $env:USERPROFILE 'scoop')
}

function Enable-Scoop {
    <#
    .DESCRIPTION
        Put the scoop shims on PATH for the remainder of this script. Repeated
        from scoop.ps1 rather than shared with it: chezmoi runs the install
        scripts as siblings, so a scoop that script installed mid-apply is not
        on the PATH this one inherited.
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
        packages rather than installing them, which still catches a renamed or
        misspelled name without paying for the download.
    #>

    return ($env:CI -eq 'true')
}

function Test-PackageInstalled {
    <#
    .DESCRIPTION
        Report whether scoop installed a package. Read off disk rather than
        from `scoop list`, which prints a formatted table and, being a script
        rather than a process, leaves $LASTEXITCODE saying nothing about how it
        went.
    #>

    param([Parameter(Mandatory = $true)][string] $Name)

    $current = Join-Path (Get-ScoopRoot) "apps\$Name\current"

    return (Test-Path -LiteralPath $current)
}

function Test-ManifestKnown {
    <#
    .DESCRIPTION
        Report whether an added bucket carries a manifest for a package, which
        is what `brew info` answers on the macOS side. Read off disk rather
        than from `scoop cat` or `scoop info`, which print through the host in
        some versions rather than down the pipeline, and host output is nothing
        a script can capture. Official buckets keep manifests under `bucket`
        and third-party ones sometimes at the root, so both are searched.
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
        Write-Host 'Optional tools are already present.'
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
    Enable-Scoop

    if (-not (Get-Command -Name 'scoop' -ErrorAction SilentlyContinue)) {
        throw 'scoop is not on PATH. install/windows/common/scoop.ps1 runs before this and should have installed it.'
    }

    Install-MissingPackages
}

# Dot-sourcing gets the functions and nothing else, so the tests can load this
# file without installing anything on the machine running them.
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Main
}
