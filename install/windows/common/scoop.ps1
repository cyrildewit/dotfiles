#Requires -Version 5.1

<#
.SYNOPSIS
    Make sure scoop exists before anything else needs it.

.DESCRIPTION
    The Windows counterpart to install/macos/common/homebrew.sh. Runs the
    upstream installer when scoop is absent, then puts the shims on PATH so the
    rest of this script can call scoop without a fresh session.

    A machine bootstrapped with setup.ps1 already has scoop, so this does
    nothing there. It is here for the other way in, a `chezmoi apply` on a
    machine that got chezmoi some other way and has no package manager yet.

    Enable-Scoop only widens PATH for this process. The chezmoi scripts that
    run after this one are siblings rather than children, so a scoop installed
    here is not on their PATH and each has to enable it for itself. setup.ps1
    avoids that entirely by enabling scoop before chezmoi starts, which leaves
    every script it runs with the shims already inherited.

    setup.ps1 repeats the install and enable steps, for the reason setup.sh
    gives about Homebrew: the bootstrap has to work on a machine where this
    repository has not been cloned, so it cannot include anything from it.

    Written for Windows PowerShell 5.1. No ternaries and no null-coalescing.

    Reads DOTFILES_DEBUG from the environment to trace every statement, the
    same as its bash counterparts.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:DOTFILES_DEBUG) {
    Set-PSDebug -Trace 1
}

# 5.1 negotiates whatever .NET Framework was configured to allow, which can
# still exclude TLS 1.2. The symptom is a closed connection rather than
# anything that names the cause, so widen it before the first download.
[Net.ServicePointManager]::SecurityProtocol =
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$ScoopInstallerUrl = 'https://get.scoop.sh'

function Test-ScoopInstalled {
    <#
    .DESCRIPTION
        Check whether scoop is already available, the way `command -v brew` is
        used in homebrew.sh.
    #>

    return [bool] (Get-Command -Name 'scoop' -ErrorAction SilentlyContinue)
}

function Test-Administrator {
    <#
    .DESCRIPTION
        Report whether this session is elevated, which is the one thing the
        scoop installer needs told rather than left to discover.
    #>

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ScoopRoot {
    <#
    .DESCRIPTION
        Print where scoop keeps itself, the counterpart to homebrew_prefix.
        Honours a pre-set SCOOP, which is how an existing install can already
        have been moved off the profile.
    #>

    if ($env:SCOOP) {
        return $env:SCOOP
    }

    # USERPROFILE rather than $HOME, for the reason the skills linker gives:
    # $HOME is built from HOMEDRIVE and HOMEPATH, which a managed machine can
    # point at a network share.
    return (Join-Path $env:USERPROFILE 'scoop')
}

function Install-Scoop {
    <#
    .DESCRIPTION
        Install scoop when it is missing. It installs into the user profile and
        asks for nothing, so there is no unattended-mode flag to set the way
        the Homebrew installer needs NONINTERACTIVE.
    #>

    if (Test-ScoopInstalled) {
        return
    }

    Write-Host 'Installing scoop.'

    # `irm | iex` cannot pass arguments, so the response becomes a script block
    # instead. scoop installs per-user and refuses an elevated session unless
    # told that was the intent.
    $installer = [scriptblock]::Create((Invoke-RestMethod -Uri $ScoopInstallerUrl))

    if (Test-Administrator) {
        & $installer -RunAsAdmin
    } else {
        & $installer
    }
}

function Enable-Scoop {
    <#
    .DESCRIPTION
        Put the scoop shims on PATH for the remainder of this script. The
        installer writes them to the user environment, which this process read
        when it started and will not read again.
    #>

    $shims = Join-Path (Get-ScoopRoot) 'shims'

    if (-not (Test-Path -LiteralPath $shims -PathType Container)) {
        return
    }

    if (($env:Path -split ';') -notcontains $shims) {
        $env:Path = "$shims;$env:Path"
    }
}

function Invoke-Main {
    <#
    .DESCRIPTION
        Ensure scoop is installed and usable.
    #>

    # Enabled before the install check as well as after it. chezmoi inherits
    # the environment of the shell that started it, which on a machine where
    # scoop was installed after that shell opened does not have the shims. The
    # installer refuses to run over an existing install, so mistaking that for
    # a missing one would fail the apply rather than do nothing.
    Enable-Scoop
    Install-Scoop
    Enable-Scoop

    if (-not (Test-ScoopInstalled)) {
        throw 'scoop is not on PATH after the install step.'
    }
}

# Dot-sourcing the file gets the functions and nothing else, so it can be
# tested without installing anything on the machine running the tests.
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Main
}
