# Functions backing aliases that need arguments, which Set-Alias cannot carry.
# The counterpart to the shell functions in ~/.aliases (for example ltree).
#
# Add a function here, then point an alias at it in aliases.ps1.

function Start-HerdrServer {
    # herdr normally spawns its background server through WMI
    # (Win32_Process.Create). On this Defender for Endpoint machine the ASR rule
    # D1E49AAC-8F56-4280-B9BA-993A6D77406C ("Block process creations originating
    # from PSExec and WMI commands") blocks that call, so after a reboot the
    # client can never start its own server. Start-Process uses CreateProcess
    # instead of WMI, which the rule does not touch. Run this once per boot.
    if ((& herdr status server 2>$null) -match 'running') {
        Write-Host 'herdr server already running.'
        return
    }
    Start-Process herdr -ArgumentList server -WindowStyle Hidden
    Write-Host 'herdr server started.'
}
