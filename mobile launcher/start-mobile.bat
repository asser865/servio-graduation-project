@echo off
setlocal
title SERVIO Mobile Launcher

color 0A
echo.
echo  ==========================================
echo       SERVIO - Starting Mobile Services
echo  ==========================================
echo.

:: ── Main AI Service (Gemini + Stable Diffusion) ────────────────────────────────
echo  [1/5] Starting Main AI Service on port 8000 ...
start "SERVIO AI Main ^| Port 8000" /min cmd /k ^
  "title SERVIO AI Main ^| Port 8000 && cd /d "%~dp0..\ai-service" && call venv\Scripts\activate && python -m uvicorn main:app --port 8000 --reload"

timeout /t 5 /nobreak >nul

:: ── Mobile AI Service ──────────────────────────────────────────────────────────
echo  [2/5] Starting Mobile AI Service on port 8001 ...
start "SERVIO Mobile AI ^| Port 8001" /min cmd /k ^
  "title SERVIO Mobile AI ^| Port 8001 && cd /d "%~dp0..\ai-service\ai_recommender_mobile" && call ..\venv\Scripts\activate && python -m uvicorn api:app --port 8001 --reload"

timeout /t 4 /nobreak >nul

:: ── AI Hard Scenarios Test ────────────────────────────────────────────────────
echo  [3/5] Running AI hard scenarios test ...
start "SERVIO AI Test Results" /min cmd /k ^
  "title SERVIO AI Test Results && cd /d "%~dp0..\ai-service\ai_recommender_mobile" && call ..\venv\Scripts\activate && python hard_scenarios_test.py && echo. && echo Press any key to close... && pause >nul"

timeout /t 2 /nobreak >nul

:: ── Backend ────────────────────────────────────────────────────────────────────
echo  [4/5] Starting Backend on port 5000 ...
start "SERVIO Backend ^| Port 5000" /min cmd /k ^
  "title SERVIO Backend ^| Port 5000 && cd /d "%~dp0..\backend" && npm run dev"

timeout /t 3 /nobreak >nul

:: ── Flutter Mobile App ─────────────────────────────────────────────────────────
echo  [5/5] Starting Flutter Mobile App ...
start "SERVIO Mobile App" /min cmd /k ^
  "title SERVIO Mobile App && cd /d "%~dp0..\mobile-app" && flutter run"

:: ── Done ───────────────────────────────────────────────────────────────────────
echo.
echo  All mobile services launched in separate windows.
echo.
echo  Main AI    -^>  http://localhost:8000  (recommend + analyze-room)
echo  Mobile AI  -^>  http://localhost:8001  (legacy recommender)
echo  Backend    -^>  http://localhost:5000
echo  Mobile     -^>  Check the Flutter window for device status
echo.
echo  Note: First analyze-room request downloads ~4 GB Stable Diffusion
echo        weights and is slow on CPU. GPU strongly recommended.
echo.
echo  Press any key to close this launcher window.
echo  (Closing this window does NOT stop the services)
echo  To stop everything, run: stop-mobile.bat
echo.
pause >nul
endlocal
