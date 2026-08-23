#Requires -Version 5.1

<#
.SYNOPSIS
    Applications the dotfiles expect to find.

.DESCRIPTION
    The Windows counterpart to install/macos/common/applications.sh. scoop has
    no formula and cask split, so keeping the GUI applications apart from the
    command-line packages in tools.ps1 is a convention rather than something
    scoop enforces.

    Every entry needs the extras bucket, which is cloned with git. That comes
    from dependencies.ps1, since chezmoi runs every run_once_before_ script
    ahead of the unprefixed ones whatever their numbers say. A CI run gets git
    from the runner image instead.

    The 1Password desktop app is the one thing missing from this list: no
    bucket carries it, so onepassword.ps1 installs it with winget.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:DOTFILES_DEBUG) {
    Set-PSDebug -Trace 1
}

$Buckets = @(
    'extras'
)

$Packages = @(
    'brave'
    'bruno'
    'claude'
    'jetbrains-toolbox'
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

function Test-BucketAdded {
    <#
    .DESCRIPTION
        Report whether a bucket is already known. Read off disk rather than
        from `scoop bucket list`, whose output has been a list of names in some
        versions and a table of objects in others.
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
        Report whether scoop installed a package. Read off disk rather than
        from `scoop list`, which prints a formatted table and, being a script
        rather than a process, leaves $LASTEXITCODE saying nothing about how it
        went.

        Windows has no /Applications convention to check besides that, so an
        application installed by hand is invisible here and scoop installs its
        own copy alongside it.
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
        Write-Host 'Applications are already present.'
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

    Add-MissingBuckets
    Install-MissingPackages
}

# Dot-sourcing gets the functions and nothing else, so the tests can load this
# file without installing anything on the machine running them.
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Main
}
