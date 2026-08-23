#Requires -Version 5.1

<#
.SYNOPSIS
    Bring a new Windows machine to the point where chezmoi can take over.

.DESCRIPTION
    The counterpart to setup.sh. Gets a package manager and chezmoi onto the
    machine, then hands over to `chezmoi init --apply`, which clones this
    repository and runs everything chezmoi finds under `.chezmoiscripts/`.
    Running it again on a machine that is already set up is a no-op.

    Unlike setup.sh there is no `bootstrap_os` here. This file only ever runs on
    one operating system, so it needs none of that structure.

    scoop rather than winget. Both work on the target machine, but scoop
    installs per-user and never needs elevation, which is what an
    Intune-managed laptop can be relied on to allow; it is also already the
    package manager in use there. Swapping it means rewriting
    `Install-Chezmoi` and `Install-Scoop` and nothing else.

    Written for Windows PowerShell 5.1, which is the only PowerShell on the
    target machine. That rules out `pwsh`-era conveniences: no ternaries, no
    null-coalescing, and no `$PSNativeCommandUseErrorActionPreference` — a
    failing executable does not throw here, so it is checked by hand.

    Configured through the environment rather than parameters, the same as
    setup.sh, because the documented invocation pipes the script into
    `Invoke-Expression` and there is nothing to bind parameters to:

      DOTFILES_DEBUG      trace every statement
      DOTFILES_REPO_URL   clone somewhere other than the default
      DOTFILES_BRANCH     clone a branch other than the default

.EXAMPLE
    irm https://raw.githubusercontent.com/cyrildewit/dotfiles/main/setup.ps1 | iex

    The `irm | iex` shape is deliberate and not just the local idiom for
    `curl | bash`. A downloaded .ps1 carries a mark-of-the-web and will not run
    under the default execution policy. Piping the response into the parser
    never writes a file, so there is no mark and no policy to argue with.
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
        Report whether a console is attached. chezmoi reads its prompts from
        the console, which CI does not have; `--no-tty` sends it to stdin
        instead. The direct counterpart to setup.sh's `[ -t 0 ]`.
    #>

    return (-not [Console]::IsInputRedirected)
}

function Test-Administrator {
    <#
    .DESCRIPTION
        Report whether this session is elevated. Only CI is; the target laptop
        runs unelevated and MDM-managed.
    #>

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Command {
    <#
    .DESCRIPTION
        Check whether a command can be resolved, the way `command -v` is used
        in setup.sh.
    #>

    param([Parameter(Mandatory = $true)][string] $Name)

    return [bool] (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

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

function Install-Scoop {
    <#
    .DESCRIPTION
        Install scoop when it is missing. It installs into the user profile and
        asks for nothing, so there is no unattended-mode flag to set the way
        the Homebrew installer needs NONINTERACTIVE.
    #>

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

function Install-Chezmoi {
    <#
    .DESCRIPTION
        Install chezmoi through scoop.

        Deliberately not the standalone installer: that leaves a binary in
        ~/.local/bin that nothing maintains afterwards. Letting the package
        manager own it means `scoop update` keeps it current — the same
        reasoning setup.sh gives for using Homebrew rather than the standalone
        installer.
    #>

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
    <#
    .DESCRIPTION
        Get scoop and chezmoi onto the machine.
    #>

    Install-Scoop
    Enable-Scoop
    Install-Chezmoi
}

function Invoke-ChezmoiApply {
    <#
    .DESCRIPTION
        Clone the repository and apply it.

        `init` prompts for the machine type and the optional toolchains, then
        `--apply` writes the dotfiles and runs the scripts.

        Without a console chezmoi reads its answers from stdin instead, which is
        how CI drives the prompts.
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
    <#
    .DESCRIPTION
        Bootstrap this machine.
    #>

    Install-Dependencies
    Invoke-ChezmoiApply
}

# Dot-sourcing the file gets the functions and nothing else, so it can be
# tested without bootstrapping the machine running the tests. `iex` reports the
# invocation name of Invoke-Expression rather than '.', so the documented
# one-liner still runs.
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Main
}
