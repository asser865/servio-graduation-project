@echo off
setlocal
title SERVIO Mobile Launcher

color 0A
echo.
echo  ==========================================
echo       SERVIO - Starting Mobile Services
echo  ==========================================
echo.

:: ── Mobile AI Service ──────────────────────────────────────────────────────────
echo  [1/4] Starting Mobile AI Service on port 8001 ...
start "SERVIO Mobile AI ^| Port 8001" /min cmd /k ^
  "title SERVIO Mobile AI ^| Port 8001 && cd /d "%~dp0..\ai-service\ai_recommender_mobile" && python -m uvicorn api:app --port 8001 --reload"

timeout /t 4 /nobreak >nul

:: ── AI Hard Scenarios Test ────────────────────────────────────────────────────
echo  [2/4] Running AI hard scenarios test ...
start "SERVIO AI Test Results" /min cmd /k ^
  "title SERVIO AI Test Results && cd /d "%~dp0..\ai-service\ai_recommender_mobile" && python hard_scenarios_test.py && echo. && echo Press any key to close... && pause >nul"

timeout /t 2 /nobreak >nul

:: ── Backend ────────────────────────────────────────────────────────────────────
echo  [3/4] Starting Backend on port 5000 ...
start "SERVIO Backend ^| Port 5000" /min cmd /k ^
  "title SERVIO Backend ^| Port 5000 && cd /d "%~dp0..\backend" && npm run dev"

timeout /t 3 /nobreak >nul

:: ── Flutter Mobile App ─────────────────────────────────────────────────────────
echo  [4/4] Starting Flutter Mobile App ...
start "SERVIO Mobile App" /min cmd /k ^
  "title SERVIO Mobile App && cd /d "%~dp0..\mobile-app" && flutter run"

:: ── Done ───────────────────────────────────────────────────────────────────────
echo.
echo  All mobile services launched in separate windows.
echo.
echo  Mobile AI  -^>  http://localhost:8001
echo  Backend    -^>  http://localhost:5000
echo  Mobile     -^>  Check the Flutter window for device status
echo.
echo  Press any key to close this launcher window.
echo  (Closing this window does NOT stop the services)
echo  To stop everything, run: stop-mobile.bat
echo.
pause >nul
endlocal
