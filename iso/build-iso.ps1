<#
.SYNOPSIS
    build-iso.ps1 - slipstream LuxeOS tools into an official Windows 8.1 ISO
    and rebuild a bootable ISO. Requires: Administrator + Windows ADK (oscdimg).

.NOTES
    You must supply a LEGAL copy of a Windows 8.1 ISO (e.g. from
    https://www.microsoft.com/en-us/software-download/windows8ISO or UUP dump).
    This script only customizes it; it does not download or redistribute Windows.

.EXAMPLE
    .\build-iso.ps1 -SourceISO "C:\iso\Win8.1.iso" -WorkDir "C:\work" -OutputISO "C:\LuxeOS.iso"
#>
param(
    [Parameter(Mandatory=$true)]  [string]$SourceISO,
    [Parameter(Mandatory=$true)]  [string]$WorkDir,
    [Parameter(Mandatory=$true)]  [string]$OutputISO
)

$ErrorActionPreference = "Stop"
function Msg($m){ Write-Host ">> $m" }

# 0) admin check
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this script as Administrator."
}

$projRoot = Split-Path $MyInvocation.MyCommand.Path
$toolsSrc = Join-Path (Split-Path $projRoot) "tools"
$iso     = Join-Path $WorkDir "iso"
$mount   = Join-Path $WorkDir "mount"
$scripts = Join-Path $mount "Windows\Setup\Scripts"
$pd      = Join-Path $mount "ProgramData\LuxeOS\tools"

# 1) extract stock ISO
Msg "Mounting source ISO..."
$img = Mount-DiskImage -ImagePath $SourceISO -PassThru
$drive = ($img | Get-Volume).DriveLetter + ":"
Msg "Source drive: $drive"
if (Test-Path $iso) { Remove-Item $iso -Recurse -Force }
New-Item -ItemType Directory -Force $iso | Out-Null
Msg "Copying ISO contents (this takes a while)..."
robocopy "$drive\" $iso /E /NFL /NDL /NJH | Out-Null
Msg "Stripping read-only attributes from copied files (ISO sources are read-only)..."
Get-ChildItem -Path $iso -Recurse | ForEach-Object { if (-not $_.PSIsContainer -and $_.IsReadOnly) { $_.IsReadOnly = $false } }
Dismount-DiskImage -ImagePath $SourceISO | Out-Null

# 2) locate install image
$wim = Join-Path $iso "sources\install.wim"
$esd = Join-Path $iso "sources\install.esd"
if ((Test-Path $esd) -and -not (Test-Path $wim)) {
    Msg "Converting install.esd -> install.wim (index 1)..."
    dism.exe /Export-Image /SourceImageFile:$esd /SourceIndex:1 /DestinationImageFile:$wim /DestinationName:"Windows 8.1 Pro (LuxeOS)" /Compress:max
    if ($LASTEXITCODE -ne 0) { throw "dism Export-Image failed (exit $LASTEXITCODE)" }
}

# 3) mount and inject
Msg "Mounting install image..."
New-Item -ItemType Directory -Force $mount | Out-Null
dism.exe /Mount-Image /ImageFile:$wim /Index:1 /MountDir:$mount /Optimize
if ($LASTEXITCODE -ne 0) { throw "dism Mount-Image failed (exit $LASTEXITCODE)" }

Msg "Injecting LuxeOS tools into ProgramData\LuxeOS\tools ..."
New-Item -ItemType Directory -Force $pd | Out-Null
Copy-Item "$toolsSrc\*" $pd -Recurse -Force

Msg "Injecting Setup scripts into Windows\Setup\Scripts ..."
New-Item -ItemType Directory -Force $scripts | Out-Null
Copy-Item (Join-Path $projRoot "SetupComplete.cmd") $scripts -Force
Copy-Item (Join-Path $projRoot "postinstall.ps1")   $scripts -Force

Msg "Committing image..."
dism.exe /Unmount-Image /MountDir:$mount /Commit
if ($LASTEXITCODE -ne 0) { throw "dism Unmount-Image failed (exit $LASTEXITCODE)" }

# 4) drop autounattend.xml at ISO root
Copy-Item (Join-Path $projRoot "autounattend.xml") $iso -Force

# 5) rebuild bootable ISO with oscdimg (from ADK)
$oscdimg = @(
    "${env:ProgramFiles(x86)}\Windows Kits\8.1\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
    "${env:ProgramFiles}\Windows Kits\8.1\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
    "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $oscdimg) { throw "oscdimg.exe not found. Install Windows ADK (Deployment Tools)." }

$etfs  = Join-Path $iso "boot\etfsboot.com"
$efisys = Join-Path $iso "efi\microsoft\boot\efisys.bin"
$bootdata = "2#p0,e,b$etfs#pEF,e,b$efisys"
Msg "Building bootable ISO -> $OutputISO"
& $oscdimg -m -o -u2 -udfver102 -bootdata:$bootdata $iso $OutputISO
if ($LASTEXITCODE -ne 0) { throw "oscdimg failed (exit $LASTEXITCODE)" }
if (-not (Test-Path $OutputISO)) { throw "Output ISO was not created: $OutputISO" }

Msg "DONE. LuxeOS ISO: $OutputISO"
