<#
.SYNOPSIS
    rebrand.ps1 - deep branding of LuxeOS 8.
    SAFE part (default): registry ProductName/Owner/OEM + OEM logo in System control panel.
    DEEP part (-Deep): patch winver/shell32/bootmgr bitmaps. BREAKS SIGNATURES - use only in a VM.
#>
param([switch]$Deep)

$ErrorActionPreference = "Stop"
function Msg($m){ Write-Host ">> $m" }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run rebrand.ps1 as Administrator."
}

$toolDir = Split-Path $MyInvocation.MyCommand.Path
$logoSrc = Join-Path $toolDir "branding\logo.bmp"

# ---------- SAFE rebrand ----------
Msg "Setting product name -> LuxeOS 8"
$cv = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
$cv32 = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion"
Set-ItemProperty $cv -Name ProductName -Value "LuxeOS 8"
Set-ItemProperty $cv -Name RegisteredOwner -Value "LuxeOS"
Set-ItemProperty $cv -Name RegisteredOrganization -Value "LuxeOS"
if (Test-Path $cv32) {
    Set-ItemProperty $cv32 -Name ProductName -Value "LuxeOS 8"
    Set-ItemProperty $cv32 -Name RegisteredOwner -Value "LuxeOS"
    Set-ItemProperty $cv32 -Name RegisteredOrganization -Value "LuxeOS"
}

Msg "Installing OEM branding (logo in System control panel)"
$oem = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation"
if (-not (Test-Path $oem)) { New-Item -Path $oem -Force | Out-Null }
$logoDst = Join-Path $env:SystemRoot "LuxeOS\logo.bmp"
New-Item -ItemType Directory -Force (Split-Path $logoDst) | Out-Null
if (Test-Path $logoSrc) { Copy-Item $logoSrc $logoDst -Force }
Set-ItemProperty $oem -Name Manufacturer -Value "LuxeOS"
Set-ItemProperty $oem -Name Model -Value "LuxeOS 8"
Set-ItemProperty $oem -Name Logo -Value $logoDst
Set-ItemProperty $oem -Name SupportURL -Value "https://luxeos.local"
Set-ItemProperty $oem -Name SupportPhone -Value "+0 (000) 000-00-00"
Set-ItemProperty $oem -Name SupportHours -Value "24/7"

# ---------- Wallpaper/lock hint (reuse LuxeTweak if present) ----------
$lk = Join-Path $env:SystemRoot "LuxeOS"
if (Test-Path (Join-Path $toolDir "LuxeTweak.ps1")) {
    & (Join-Path $toolDir "LuxeTweak.ps1") preset apply LuxeGlass 2>$null
}
Msg "SAFE rebrand done. System panel / Win+Pause now show LuxeOS 8."

# ---------- DEEP rebrand (optional, dangerous) ----------
if (-not $Deep) { return }

Msg "DEEP rebrand requested. This modifies system files and breaks digital signatures."
Write-Host "[!] Ensure Secure Boot is OFF and testsigning is allowed before rebooting." -ForegroundColor Red

# 1) winver / shell32 string + bitmap via Resource Hacker (rh.exe) if available
$rh = Get-Command rh.exe -ErrorAction SilentlyContinue
if ($rh) {
    Msg "Resource Hacker found - patching winver.exe / shell32.dll bitmaps"
    $sys32 = Join-Path $env:SystemRoot "System32"
    & rh.exe -open "$sys32\winver.exe" -save "$sys32\winver.exe" -action addoverwrite -res $logoSrc -mask "BITMAP,1," -log c:\luxeos_rh.log
    & rh.exe -open "$sys32\shell32.dll" -save "$sys32\shell32.dll" -action addoverwrite -res $logoSrc -mask "BITMAP,1," -log c:\luxeos_rh.log
    # replace the "Windows" string in shell32 string table (id 1) - example for English:
    & rh.exe -open "$sys32\shell32.dll" -save "$sys32\shell32.dll" -action modify -res "STRINGTABLE,1," -mask "Windows,LuxeOS" -log c:\luxeos_rh.log
} else {
    Write-Host "[~] rh.exe (Resource Hacker) not found - skipping winver/shell32 patch. Download it and rerun with -Deep." -ForegroundColor Yellow
}

# 2) Boot logo via HackBGRT (UEFI) if present
$hb = Get-Command HackBGRT.exe -ErrorAction SilentlyContinue
if ($hb) {
    Msg "HackBGRT found - installing custom boot logo"
    & HackBGRT.exe install
} else {
    Write-Host "[~] HackBGRT not found - skipping boot logo. For BIOS use a bootmgr bitmap patcher." -ForegroundColor Yellow
}

Msg "DEEP rebrand attempted. Reboot to see changes. If system fails to boot, restore originals from DISM/WinRE."
