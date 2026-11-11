@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Harvest Pocket - Build
set "SCRIPT=%~dp0tools\build_harvest_pocket.ps1"
if not exist "%SCRIPT%" (
    echo [ERROR] Missing: %SCRIPT%
    pause
    exit /b 2
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
set "E=%ERRORLEVEL%"
echo.
if "%E%"=="0" (
    echo [OK] Harvest Pocket build complete.
) else (
    echo [ERROR] Harvest Pocket build failed. Exit code: %E%
)
pause
exit /b %E%
