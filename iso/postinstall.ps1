<#
.SYNOPSIS
    postinstall.ps1 - first-boot deployment of LuxeOS 8.
    Runs from SetupComplete.cmd / FirstLogon. Applies the default theme preset
    and installs the LuxeMalware real-time protection task.
#>
$ErrorActionPreference = "SilentlyContinue"
$tools = Join-Path $env:ProgramData "LuxeOS\tools"

if (-not (Test-Path $tools)) {
    # Fallback: tools were placed elsewhere; search common locations.
    $tools = Join-Path $env:SystemRoot "Setup\Scripts"
}

Write-Host "== LuxeOS first-boot setup =="
& "$tools\LuxeTweak.ps1" preset apply LuxeGlass
& "$tools\LuxeMalware.ps1" install
& "$tools\rebrand.ps1"
& "$tools\LuxeMalware.ps1" status

# Pin launchers to Start for convenience
$ws = New-Object -ComObject WScript.Shell
foreach ($t in @("LuxeTweak.ps1","LuxeMalware.ps1")) {
    $lnk = $ws.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\LuxeOS-$t.lnk")
    $lnk.TargetPath = "powershell.exe"
    $lnk.Arguments = "-ExecutionPolicy Bypass -File `"$tools\$t`""
    $lnk.Save()
}
Write-Host "== LuxeOS setup done =="
