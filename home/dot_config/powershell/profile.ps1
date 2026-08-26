# Real PowerShell profile, kept here under ~/.config so chezmoi manages it as a
# normal file. The profile that Windows loads holds only a bootstrap line that
# dot-sources this one, injected by scripts/windows/set-powershell-profile.ps1.
#
# Functions load before aliases, because an alias can point at a function.

foreach ($part in 'functions.ps1', 'aliases.ps1') {
    $path = Join-Path $PSScriptRoot $part
    if (Test-Path -LiteralPath $path) { . $path }
}
