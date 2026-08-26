# PowerShell aliases. Add one line per alias.
#
# Set-Alias maps a name to a command and forwards arguments, so `c chat` runs
# `claude chat`. An alias cannot carry its own arguments; when you need that,
# write a function in functions.ps1 and point the alias at it.

Set-Alias -Name c -Value claude
