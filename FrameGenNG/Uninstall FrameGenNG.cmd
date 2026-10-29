@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0manager\FrameGenNG-Manager.ps1" -Action Uninstall
pause

