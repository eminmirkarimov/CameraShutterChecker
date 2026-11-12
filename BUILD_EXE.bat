@echo off
setlocal
chcp 65001 >nul
title Build Camera Shutter Checker EXE
set "ROOT=%~dp0"
if not exist "%ROOT%CameraShutterCheck.ps1" (
  echo ERROR: CameraShutterCheck.ps1 is missing.
  pause
  exit /b 1
)
echo.
echo Camera Shutter Checker 2.4.1
echo EXE build by Emin Mirkarimov
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%Build-EXE.ps1" -Version "2.4.1"
if errorlevel 1 (
 echo.
 echo EXE build failed. See the error above.
  pause
  exit /b 1
)
echo.
echo Build completed.
pause
endlocal
