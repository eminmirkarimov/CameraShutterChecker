@echo off
setlocal
chcp 65001 >nul
title Camera Shutter Checker 2.4.1
set "SCRIPT=%~dp0CameraShutterCheck.ps1"
if not exist "%SCRIPT%" (
  echo ERROR: CameraShutterCheck.ps1 not found next to this BAT.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
endlocal
