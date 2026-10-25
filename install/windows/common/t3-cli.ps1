#Requires -Version 5.1

<#
.SYNOPSIS
    Install the T3 Code CLI, the server half of T3 Code without the app.

.DESCRIPTION
    The Windows counterpart to install/macos/common/t3_cli.sh. The t3code
    package in applications.ps1 already carries a server. The CLI adds
    `t3 serve` and `t3 connect`, which make the agents on this machine
    reachable from other devices without the desktop app open.

    No scoop bucket carries the CLI, so this runs T3's own installer. The
    installer is downloaded to a file and run in a child powershell, because
    its Fail calls `exit 1`, which under `irm | iex` would end this script as
    well.

    The installer writes t3.cmd to ~\.local\bin and only prints a hint when
    that directory is not on PATH. This adds it to the user PATH, so that cmd,
    PowerShell and GUI apps all find `t3`, and not only a profile that loads.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:DOTFILES_DEBUG) {
    Set-PSDebug -Trace 1
}

$InstallerUrl = 'https://t3.codes/install.ps1'

function Test-CI {
    <#
    .DESCRIPTION
        CI fetches the installer rather than running it: enough to catch a
        moved URL without paying for the download.
    #>

    return ($env:CI -eq 'true')
}

function Get-BinDirectory {
    # USERPROFILE rather than $HOME, for the reason applications.ps1 gives.
    return (Join-Path $env:USERPROFILE '.local\bin')
}

function Test-T3Installed {
    return (Test-Path -LiteralPath (Join-Path (Get-BinDirectory) 't3.cmd'))
}

function Add-BinDirectoryToPath {
    <#
    .DESCRIPTION
        Written to the user scope in the registry, which new processes read.
        The current process gets it too, so a later script in the same apply
        finds `t3` without a new shell.
    #>

    $bin = Get-BinDirectory
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entries = @(if ($userPath) { $userPath -split ';' | Where-Object { $_ } })

    if ($entries -notcontains $bin) {
        Write-Host "Adding $bin to the user PATH."
        [Environment]::SetEnvironmentVariable('Path', (($entries + $bin) -join ';'), 'User')
    }

    if (($env:Path -split ';') -notcontains $bin) {
        $env:Path = "$env:Path;$bin"
    }
}

function Install-T3 {
    $installer = Join-Path ([IO.Path]::GetTempPath()) "t3-install-$([guid]::NewGuid()).ps1"

    try {
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $installer -UseBasicParsing

        if (Test-CI) {
            Write-Host "Resolved $InstallerUrl."
            return
        }

        Write-Host 'Installing t3.'
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer

        if ($LASTEXITCODE -ne 0) {
            throw "the T3 Code installer exited with $LASTEXITCODE."
        }
    } finally {
        Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
    }

    if (-not (Test-T3Installed)) {
        throw "the T3 Code installer did not write t3.cmd to $(Get-BinDirectory)."
    }
}

function Invoke-Main {
    if (Test-T3Installed) {
        Write-Host 't3 is already installed.'
    } else {
        Install-T3
    }

    if (-not (Test-CI)) {
        Add-BinDirectoryToPath
    }
}

# Dot-sourcing gets the functions and nothing else, so the tests can load this
# file without installing anything on the machine running them.
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Main
}
