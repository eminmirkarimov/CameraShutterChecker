param(
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version = '2.4.1'
)

# Camera Shutter Checker EXE builder
# Project author / product owner: Emin Mirkarimov
# PS2EXE is used only as a build-time compiler; it is not required at runtime.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceFile = Join-Path $ProjectRoot 'CameraShutterCheck.ps1'
$DistDir = Join-Path $ProjectRoot 'dist'
$OutputFile = Join-Path $DistDir 'CameraShutterChecker.exe'

Write-Host ''
Write-Host 'CAMERA SHUTTER CHECKER — EXE BUILD' -ForegroundColor Cyan
Write-Host ("Build version: $Version") -ForegroundColor Cyan
Write-Host 'Project author: Emin Mirkarimov' -ForegroundColor White
Write-Host 'Copyright (c) 2026 Emin Mirkarimov' -ForegroundColor Gray
Write-Host ''

if (-not (Test-Path -LiteralPath $SourceFile -PathType Leaf)) {
    throw "Source file not found: $SourceFile"
}

if (-not (Test-Path -LiteralPath $DistDir -PathType Container)) {
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
}

$module = Get-Module -ListAvailable -Name ps2exe | Select-Object -First 1
if (-not $module) {
    Write-Host 'PS2EXE build module is not installed.' -ForegroundColor Yellow
    Write-Host 'It will be downloaded from the PowerShell Gallery for compilation only.' -ForegroundColor Yellow
    Write-Host 'The resulting program will not need the PS2EXE module.' -ForegroundColor Gray

    try {
        $nuget = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue
        if (-not $nuget) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
        }
        Install-Module -Name ps2exe -Repository PSGallery -Scope CurrentUser -Force -AllowClobber
    }
    catch {
        throw "Could not install the PS2EXE build module. Check internet/PowerShell Gallery access and retry. Details: $($_.Exception.Message)"
    }
}

Import-Module ps2exe -ErrorAction Stop
$compiler = Get-Command -Name Invoke-PS2EXE -ErrorAction Stop

Write-Host "Source: $SourceFile" -ForegroundColor Gray
Write-Host "Output: $OutputFile" -ForegroundColor Gray
Write-Host ''
Write-Host 'Compiling. The console window is intentionally kept visible because the app prints its report there.' -ForegroundColor Yellow

& $compiler `
    -inputFile $SourceFile `
    -outputFile $OutputFile `
    -x64 `
    -STA `
    -supportOS `
    -title 'Camera Shutter Checker' `
    -description 'Offline camera shutter-count metadata analyzer' `
    -company 'Emin Mirkarimov' `
    -product 'Camera Shutter Checker' `
    -copyright 'Copyright (c) 2026 Emin Mirkarimov. All rights reserved.' `
    -trademark 'Camera Shutter Checker' `
    -version ("$Version.0")

if (-not (Test-Path -LiteralPath $OutputFile -PathType Leaf)) {
    throw 'Compiler finished without producing the expected EXE file.'
}

$file = Get-Item -LiteralPath $OutputFile
Write-Host ''
Write-Host 'BUILD SUCCESSFUL' -ForegroundColor Green
Write-Host ("EXE: {0}" -f $file.FullName) -ForegroundColor Green
Write-Host ("Size: {0:N2} MB" -f ($file.Length / 1MB)) -ForegroundColor Gray
Write-Host ''
Write-Host 'The EXE contains the PowerShell script. Keep the source files in your GitHub repository.' -ForegroundColor Yellow
Write-Host 'Windows may show SmartScreen because this EXE is not digitally signed.' -ForegroundColor Gray
