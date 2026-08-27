@echo off
REM SetupComplete.cmd - runs automatically at the end of LuxeOS Setup (as SYSTEM).
REM Deploys LuxeOS tools: applies default theme preset and installs real-time antivirus.
powershell -ExecutionPolicy Bypass -NoProfile -File "%SystemRoot%\Setup\Scripts\postinstall.ps1"
exit /b 0
