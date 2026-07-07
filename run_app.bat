@echo off
echo ========================================================
echo MVP Sound Engine - Run Script
echo ========================================================

echo.
echo [1/2] Cleaning up old background processes...
taskkill /F /IM MPV_Sound_Engine.exe /T 2>nul
taskkill /F /IM dart.exe /T 2>nul
taskkill /F /IM dartaotruntime.exe /T 2>nul

echo.
echo [2/2] Launching Flutter application...
c:\Users\Dai\dev\flutter\bin\flutter.bat run -d windows

echo.
pause
