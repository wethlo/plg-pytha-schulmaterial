@echo off
setlocal
title PLG PYTHA-Schulmaterial aktualisieren
mode con: cols=100 lines=34 >nul 2>&1
chcp 65001 >nul 2>&1
color F0
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
rem aus einem 32-Bit-Prozess heraus trotzdem die 64-Bit-PowerShell nehmen (Registry!)
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "PS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Schulmaterial-Update.ps1" %*
if /i "%~1"=="-Einrichten" exit /b
echo.
pause
