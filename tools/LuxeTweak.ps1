<#
.SYNOPSIS
    LuxeTweak - customization center for LuxeOS 8.
    Registry-driven theming: wallpaper, accent color, taskbar, transparency, presets.
    Pure PowerShell, runs natively on LuxeOS 8 (based on Windows 8 / 10 / 11).
#>
param(
    [string]$Command = "help",
    [string]$Arg1,
    [string]$Arg2
)

$Version = "1.0.0"
$DWM = "HKCU:\Software\Microsoft\Windows\DWM"
$CP  = "HKCU:\Control Panel\Desktop"
$Accent = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent"

$Presets = @{
    LuxeDark   = @{ color = 0xC41F1F1F; autohide = $false; glass = $true;  wp = "" }
    LuxeLight  = @{ color = 0xC4D97800; autohide = $false; glass = $false; wp = "" }
    LuxeGlass  = @{ color = 0x80337BA0; autohide = $true;  glass = $true;  wp = "" }
    LuxeRetro  = @{ color = 0xC4009E88; autohide = $false; glass = $false; wp = "" }
}

function Apply-Wallpaper($p) {
    if (-not (Test-Path $p)) { Write-Host "[!] Wallpaper not found: $p"; return }
    Set-ItemProperty $CP -Name Wallpaper -Value $p
    Add-Type @"
using System; using System.Runtime.InteropServices;
public class WP { [DllImport("user32.dll")] public static extern int SystemParametersInfo(int a,int b,string c,int d); }
"@ -ErrorAction SilentlyContinue
    try { [WP]::SystemParametersInfo(20, 0, $p, 3) | Out-Null; Write-Host "[v] Wallpaper applied: $p" }
    catch { Write-Host "[~] Set in registry (log off/on to apply): $p" }
}

function Apply-Color($c) {
    if (-not (Test-Path $DWM)) { New-Item -Path $DWM -Force | Out-Null }
    Set-ItemProperty $DWM -Name ColorizationColor -Value $c
    if (-not (Test-Path $Accent)) { New-Item -Path $Accent -Force | Out-Null }
    Set-ItemProperty $Accent -Name AccentColor -Value $c
    # notify shell
    rundll32.exe user32.dll,UpdatePerUserSystemParameters 1,True 2>$null
    Write-Host "[v] Accent color set: 0x$($c.ToString('X8'))"
}

function Apply-Autohide($on) {
    # StuckRects2 Settings binary: byte 8 (0-based) = 3 -> autohide on
    $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects2"
    if (-not (Test-Path $key)) { Write-Host "[~] Taskbar settings not present yet."; return }
    $data = (Get-ItemProperty $key).Settings
    if ($on) { $data[8] = 3 } else { $data[8] = 2 }
    Set-ItemProperty $key -Name Settings -Value $data
    $state = if ($on) { "ON" } else { "OFF" }
    Write-Host "[v] Taskbar autohide: $state (restart explorer to apply)"
}

function Apply-Glass($on) {
    if (-not (Test-Path $DWM)) { New-Item -Path $DWM -Force | Out-Null }
    Set-ItemProperty $DWM -Name ColorizationGlassAttribute -Value $(if ($on) { 1 } else { 0 })
    Set-ItemProperty $DWM -Name EnableAeroPeek -Value $(if ($on) { 1 } else { 0 })
    $state = if ($on) { "ON" } else { "OFF" }
    Write-Host "[v] Glass/transparency: $state"
}

function Preset-Apply($name) {
    if (-not $Presets.ContainsKey($name)) { Write-Host "[!] Unknown preset: $name"; return }
    $p = $Presets[$name]
    Apply-Color $p.color
    Apply-Autohide $p.autohide
    Apply-Glass $p.glass
    if ($p.wp) { Apply-Wallpaper $p.wp }
    Write-Host "[v] Applied preset: $name"
}

function Status {
    Write-Host "LuxeTweak $Version"
    Write-Host "  Accent color : $((Get-ItemProperty $DWM -ErrorAction SilentlyContinue).ColorizationColor)"
    Write-Host "  Wallpaper    : $((Get-ItemProperty $CP -ErrorAction SilentlyContinue).Wallpaper)"
    Write-Host "  Glass        : $((Get-ItemProperty $DWM -ErrorAction SilentlyContinue).ColorizationGlassAttribute)"
}

switch ($Command) {
    "wallpaper" { if ($Arg1 -eq "set") { Apply-Wallpaper $Arg2 } else { Write-Host "usage: LuxeTweak.ps1 wallpaper set <path>" } }
    "color"     { if ($Arg1) { Apply-Color ([uint32]::Parse($Arg1, 'HexNumber')) } else { Write-Host "usage: LuxeTweak.ps1 color <AARRGGBB-hex>" } }
    "taskbar"   { if ($Arg1 -in @("on","off")) { Apply-Autohide ($Arg1 -eq "on") } else { Write-Host "usage: LuxeTweak.ps1 taskbar on|off" } }
    "glass"     { if ($Arg1 -in @("on","off")) { Apply-Glass ($Arg1 -eq "on") } else { Write-Host "usage: LuxeTweak.ps1 glass on|off" } }
    "preset"    { if ($Arg1 -eq "list") { Write-Host "Presets: $($Presets.Keys -join ', ')" } elseif ($Arg1 -eq "apply") { Preset-Apply $Arg2 } else { Write-Host "usage: LuxeTweak.ps1 preset list|apply <name>" } }
    "status"    { Status }
    default     { Write-Host "LuxeTweak $Version"; Write-Host "wallpaper set <path> | color <AARRGGBB> | taskbar on|off | glass on|off | preset list|apply <name> | status" }
}
