#Requires -Version 5.1

<#
.SYNOPSIS
    Bring a new Windows machine to the point where chezmoi can take over.

.DESCRIPTION
    The counterpart to setup.sh. Gets a package manager and chezmoi onto the
    machine, then hands over to `chezmoi init --apply`, which clones this
    repository and runs everything chezmoi finds under `.chezmoiscripts/`.
    Running it again on a machine that is already set up is a no-op.

    Written for Windows PowerShell 5.1, the one PowerShell every Windows
    machine has, so a failing executable does not throw and is checked by hand.

    Read from the environment rather than taken as parameters, because the
    documented invocation pipes this script into `Invoke-Expression` and there
    is nothing to bind parameters to:

      DOTFILES_DEBUG      trace every statement
      DOTFILES_REPO_URL   clone somewhere other than the default
      DOTFILES_BRANCH     clone a branch other than the default

.EXAMPLE
    irm https://raw.githubusercontent.com/cyrildewit/dotfiles/main/setup.ps1 | iex

    A downloaded .ps1 carries a mark-of-the-web and will not run under the
    default execution policy. Piping the response into the parser never writes
    a file, so there is no mark and no policy to argue with.
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

$DotfilesRepoUrl = if ($env:DOTFILES_REPO_URL) {
    $env:DOTFILES_REPO_URL
} else {
    'https://github.com/cyrildewit/dotfiles.git'
}

$DotfilesBranch = $env:DOTFILES_BRANCH
$ScoopInstallerUrl = 'https://get.scoop.sh'

function Test-Interactive {
    <#
    .DESCRIPTION
        chezmoi reads its prompts from the console, which CI does not have;
        `--no-tty` sends it to stdin instead.
    #>

    return (-not [Console]::IsInputRedirected)
}

function Test-Administrator {
    <#
    .DESCRIPTION
        The scoop installer has to be told, rather than discovering this
        itself.
    #>

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Command {
    param([Parameter(Mandatory = $true)][string] $Name)

    return [bool] (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

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

function Install-Scoop {
    if (Test-Command -Name 'scoop') {
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
        The installer writes the shims to the user environment, which this
        process read when it started and will not read again.
    #>

    $shims = Join-Path (Get-ScoopRoot) 'shims'

    if (-not (Test-Path -LiteralPath $shims -PathType Container)) {
        return
    }

    if (($env:Path -split ';') -notcontains $shims) {
        $env:Path = "$shims;$env:Path"
    }
}

function Install-Chezmoi {
    if (Test-Command -Name 'chezmoi') {
        return
    }

    Write-Host 'Installing chezmoi.'
    scoop install chezmoi

    # Checked by outcome rather than by exit code: `scoop` resolves to a .ps1
    # in the shims directory, so it is a script and not a process, and
    # $LASTEXITCODE says nothing about it. Failing here rather than at
    # `chezmoi init` names the actual problem.
    Enable-Scoop

    if (-not (Test-Command -Name 'chezmoi')) {
        throw 'scoop install chezmoi did not put chezmoi on PATH.'
    }
}

function Install-Dependencies {
    Install-Scoop
    Enable-Scoop
    Install-Chezmoi
}

function Invoke-ChezmoiApply {
    <#
    .DESCRIPTION
        Without a console chezmoi reads its answers from stdin, which is how
        CI drives the prompts.
    #>

    $options = @()

    if (-not (Test-Interactive)) {
        $options += '--no-tty'
    }

    if ($DotfilesBranch) {
        $options += @('--branch', $DotfilesBranch)
    }

    Write-Host "Applying $DotfilesRepoUrl."
    chezmoi init --apply $DotfilesRepoUrl @options

    if ($LASTEXITCODE -ne 0) {
        throw "chezmoi init --apply exited with $LASTEXITCODE."
    }
}

function Invoke-Main {
    Install-Dependencies
    Invoke-ChezmoiApply
}

# Dot-sourcing gets the functions and nothing else, so the tests can load this
# file without bootstrapping the machine running them. `iex` reports the
# invocation name of Invoke-Expression rather than '.', so the documented
# one-liner still runs.
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Main
}
