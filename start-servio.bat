@echo off
setlocal
title SERVIO Launcher

color 0A
echo.
echo  ==========================================
echo       SERVIO - Starting All Services
echo  ==========================================
echo.

:: ── Backend ───────────────────────────────────────────────────────────────────
echo  [1/2] Starting Backend on port 5000 ...
start "SERVIO Backend ^| Port 5000" cmd /k ^
  "color 0B && title SERVIO Backend ^| Port 5000 && cd /d "%~dp0backend" && npm run dev"

:: Brief pause so backend starts before Flutter tries to connect
timeout /t 3 /nobreak >nul

:: ── Mobile App ────────────────────────────────────────────────────────────────
echo  [2/2] Starting Flutter Mobile App ...
start "SERVIO Mobile App" cmd /k ^
  "color 0E && title SERVIO Mobile App && cd /d "%~dp0mobile-app" && flutter run"

:: ── Done ──────────────────────────────────────────────────────────────────────
echo.
echo  Both services launched in separate windows.
echo.
echo  Backend  -^>  http://localhost:5000
echo  Mobile   -^>  Check the Flutter window for device status
echo.
echo  Press any key to close this launcher window.
echo  (Closing this window does NOT stop the services)
echo  To stop everything, run: stop-servio.bat
echo.
pause >nul
endlocal
