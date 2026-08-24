#Requires -Version 5.1

<#
.SYNOPSIS
    Optional npm packages.

.DESCRIPTION
    Global installs for tools that ship on npm and that no scoop bucket
    carries a manifest for. A script of its own rather than lines in
    tools.ps1, because that one speaks scoop and this one needs the npm that
    it installs through nodejs-lts. Nothing in this repository requires these,
    so a machine without them still gets a working configuration.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:DOTFILES_DEBUG) {
    Set-PSDebug -Trace 1
}

$Packages = @(
    'ccusage'
)

function Get-ScoopRoot {
    <#
    .DESCRIPTION
        Honours a pre-set SCOOP, which is how an existing install can already
        have been moved off the profile.
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
        chezmoi runs the install scripts as siblings, so the nodejs-lts that
        tools.ps1 installed mid-apply is not on the PATH this one inherited.
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
        CI resolves packages rather than installing them: enough to catch a
        renamed name without paying for the download.
    #>

    return ($env:CI -eq 'true')
}

function Resolve-RegistryPackage {
    <#
    .DESCRIPTION
        Asks the npm registry rather than npm, because in CI the scoop scripts
        also only resolved, so there is no npm on the machine to ask.
    #>

    param([Parameter(Mandatory = $true)][string] $Name)

    try {
        Invoke-RestMethod -Uri "https://registry.npmjs.org/$Name/latest" | Out-Null
    } catch {
        throw "the npm registry does not carry $Name."
    }
}

function Install-MissingPackages {
    # Read off disk rather than from `npm ls -g`, which exits nonzero over
    # dependency complaints that say nothing about whether a package is there.
    $globalRoot = npm root -g

    $pending = @($Packages | Where-Object {
        -not (Test-Path -LiteralPath (Join-Path $globalRoot $_))
    })

    if ($pending.Count -eq 0) {
        Write-Host 'Optional npm tools are already present.'
        return
    }

    Write-Host "Installing: $($pending -join ' ')"
    npm install --global @pending

    if ($LASTEXITCODE -ne 0) {
        throw "npm install exited with $LASTEXITCODE."
    }

    $failed = @($pending | Where-Object {
        -not (Test-Path -LiteralPath (Join-Path $globalRoot $_))
    })

    if ($failed.Count -gt 0) {
        throw "npm install did not install: $($failed -join ' ')"
    }
}

function Invoke-Main {
    if (Test-CI) {
        # Every package rather than just the pending ones, because without npm
        # there is no global root to read the installed ones off.
        Write-Host "Resolving: $($Packages -join ' ')"

        foreach ($package in $Packages) {
            Resolve-RegistryPackage -Name $package
        }

        return
    }

    Enable-Scoop

    if (-not (Get-Command -Name 'npm' -ErrorAction SilentlyContinue)) {
        throw 'npm is not on PATH. install/windows/common/tools.ps1 runs before this and should have installed nodejs-lts.'
    }

    Install-MissingPackages
}

# Dot-sourcing gets the functions and nothing else, so the tests can load this
# file without installing anything on the machine running them.
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Main
}
