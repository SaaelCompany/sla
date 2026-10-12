@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-DesktopFailover.ps1"
set ERR=%ERRORLEVEL%
if "%~1"=="--no-pause" exit /b %ERR%
echo.
pause
exit /b %ERR%
