@echo off
title SERVIO Stop
color 0C
echo.
echo  ==========================================
echo       SERVIO - Stopping All Services
echo  ==========================================
echo.

:: Kill by window title - /t kills child processes too (node, dart, flutter)
echo  [1/2] Stopping Backend ...
taskkill /fi "WINDOWTITLE eq SERVIO Backend*" /t /f >nul 2>&1
if %errorlevel%==0 (
    echo         Done.
) else (
    echo         Not running.
)

echo  [2/2] Stopping Flutter Mobile App ...
taskkill /fi "WINDOWTITLE eq SERVIO Mobile App" /t /f >nul 2>&1
if %errorlevel%==0 (
    echo         Done.
) else (
    echo         Not running.
)

echo.
echo  All SERVIO services stopped.
echo.
pause >nul
