@echo off
title SERVIO Mobile Stop
color 0C
echo.
echo  ==========================================
echo       SERVIO - Stopping Mobile Services
echo  ==========================================
echo.

echo  [1/4] Stopping Main AI Service ...
taskkill /fi "WINDOWTITLE eq SERVIO AI Main*" /t /f >nul 2>&1
if %errorlevel%==0 (
    echo         Done.
) else (
    echo         Not running.
)

echo  [2/4] Stopping Mobile AI Service ...
taskkill /fi "WINDOWTITLE eq SERVIO Mobile AI*" /t /f >nul 2>&1
if %errorlevel%==0 (
    echo         Done.
) else (
    echo         Not running.
)

echo  [3/4] Stopping Backend ...
taskkill /fi "WINDOWTITLE eq SERVIO Backend*" /t /f >nul 2>&1
if %errorlevel%==0 (
    echo         Done.
) else (
    echo         Not running.
)

echo  [4/4] Stopping Flutter Mobile App ...
taskkill /fi "WINDOWTITLE eq SERVIO Mobile App" /t /f >nul 2>&1
if %errorlevel%==0 (
    echo         Done.
) else (
    echo         Not running.
)

echo.
echo  All mobile services stopped.
echo.
pause >nul
