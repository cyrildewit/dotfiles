#Requires -Version 5.1

<#
.SYNOPSIS
    Install the 1Password desktop app.

.DESCRIPTION
    The Windows counterpart to the 1password cask in
    install/macos/common/applications.sh, and the only thing installed with
    winget rather than scoop. No official bucket carries the app, so it gets a
    file of its own rather than a line in applications.ps1.

    --scope machine is load-bearing. The package carries an msix that installs
    per user under WindowsApps and a machine-scope msi that installs into
    Program Files\1Password. .chezmoi.toml.tmpl points onepassword_signer at
    app\8\op-ssh-sign.exe underneath the msi, so naming the scope is what keeps
    that path true.

    A machine-scope msi needs elevation, which chezmoi run from an ordinary
    shell does not have. That is checked before the install so the message
    names the cause, and being a run_once_ script it runs again on the next
    apply, so an elevated shell is the whole retry. Failing rather than
    skipping is deliberate: git signs commits through op-ssh-sign, so a skipped
    install leaves signing broken with nothing in the output to say why.

    Presence is checked twice, the way docker.sh checks Homebrew and then the
    app bundle. winget answers whether it installed the app, and the directory
    under Program Files answers whether anything did. The directory is what
    gets checked rather than op-ssh-sign.exe itself, since the exe sits under a
    major-version segment that moves when the next major version ships.

    winget comes with App Installer, which a Windows Server image does not
    carry, so a CI run with no winget to resolve through says so and returns.
    The workflow reads the manifest out of microsoft/winget-pkgs instead.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:DOTFILES_DEBUG) {
    Set-PSDebug -Trace 1
}

$Package = 'AgileBits.1Password'
$AppDirectory = '1Password'

function Test-CI {
    <#
    .DESCRIPTION
        Report whether this is a continuous integration run. CI resolves the
        package rather than installing it, which still catches a renamed or
        withdrawn package without paying for the download.
    #>

    return ($env:CI -eq 'true')
}

function Get-ProgramFiles {
    <#
    .DESCRIPTION
        Print the 64-bit Program Files directory. ProgramW6432 is set only in a
        32-bit process, where ProgramFiles names the x86 directory instead, so
        reading it first keeps this on the directory a machine-scope installer
        writes to whichever powershell.exe ran the script.
    #>

    if ($env:ProgramW6432) {
        return $env:ProgramW6432
    }

    return $env:ProgramFiles
}

function Get-AppPath {
    return (Join-Path (Get-ProgramFiles) $AppDirectory)
}

function Test-AppPresent {
    <#
    .DESCRIPTION
        Report whether the app is on the machine, whoever installed it, which
        is what bundle_path_for answers on the macOS side.
    #>

    return (Test-Path -LiteralPath (Get-AppPath) -PathType Container)
}

function Test-WingetPresent {
    return [bool] (Get-Command -Name 'winget' -ErrorAction SilentlyContinue)
}

function Test-WingetManaged {
    <#
    .DESCRIPTION
        Report whether winget already manages the package, which is what
        `brew list --cask` answers on the macOS side. The exit code is the part
        worth reading: zero when something matched and non-zero when nothing
        did. No --source, so a copy that arrived some other way still
        correlates through Programs and Features.
    #>

    winget list --id $Package --exact --accept-source-agreements | Out-Null

    return ($LASTEXITCODE -eq 0)
}

function Test-Elevated {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Resolve-Package {
    <#
    .DESCRIPTION
        Ask winget for the package without installing it, the counterpart to
        `brew info --cask`.
    #>

    Write-Host "Resolving $Package."

    $arguments = @(
        'show'
        '--id', $Package
        '--exact'
        '--source', 'winget'
        '--accept-source-agreements'
    )

    winget @arguments | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "winget show $Package exited with $LASTEXITCODE."
    }
}

function Install-App {
    Write-Host "Installing $Package."

    $arguments = @(
        'install'
        '--id', $Package
        '--exact'
        '--source', 'winget'
        '--scope', 'machine'
        '--accept-package-agreements'
        '--accept-source-agreements'
        # chezmoi runs this with nothing on the other end of stdin, so a prompt
        # would hang the apply rather than ask anyone anything.
        '--disable-interactivity'
    )

    winget @arguments

    if ($LASTEXITCODE -ne 0) {
        throw "winget install $Package exited with $LASTEXITCODE."
    }

    # Checked by outcome, the way the scoop scripts check theirs. A winget that
    # reported success after installing the per-user msix would leave the app
    # on the machine and onepassword_signer pointing at nothing, and that only
    # surfaces at the next signed commit.
    if (-not (Test-AppPresent)) {
        throw "winget installed $Package somewhere other than $(Get-AppPath)."
    }
}

function Invoke-Main {
    if (Test-AppPresent) {
        Write-Host "The 1Password app is already installed at $(Get-AppPath)."
        return
    }

    # Ahead of the winget check rather than after it, unlike every other branch
    # here, because a run with no winget to resolve through is the one case CI
    # has to survive.
    if (Test-CI) {
        if (-not (Test-WingetPresent)) {
            Write-Host 'winget is absent, so there is nothing to resolve against.'
            return
        }

        Resolve-Package
        return
    }

    if (-not (Test-WingetPresent)) {
        throw 'winget is not on PATH. It ships with App Installer, which comes from the Microsoft Store.'
    }

    if (Test-WingetManaged) {
        Write-Host 'The 1Password app is already managed by winget.'
        return
    }

    if (-not (Test-Elevated)) {
        throw "installing $Package machine-wide needs elevation. Run chezmoi apply from an elevated shell, or install the app by hand."
    }

    Install-App
}

# Dot-sourcing gets the functions and nothing else, so the tests can load this
# file without installing anything on the machine running them.
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Main
}
