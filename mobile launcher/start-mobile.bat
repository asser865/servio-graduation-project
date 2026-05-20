@echo off
setlocal

set "ROOT=%~dp0.."
for %%I in ("%ROOT%") do set "ROOT=%%~fI"

set "AI_DIR=%ROOT%\ai-service"
set "MOBILE_AI_DIR=%AI_DIR%\ai_recommender_mobile"
set "BACKEND_DIR=%ROOT%\backend"
set "MOBILE_APP_DIR=%ROOT%\mobile-app"

if /I "%~1"=="main-ai" goto :main_ai
if /I "%~1"=="mobile-ai" goto :mobile_ai
if /I "%~1"=="ai-test" goto :ai_test
if /I "%~1"=="backend" goto :backend
if /I "%~1"=="mobile-app" goto :mobile_app

title SERVIO Mobile Launcher
color 0A
echo.
echo  ==========================================
echo       SERVIO - Starting Mobile Services
echo  ==========================================
echo.

echo  [1/5] Starting Mobile Main AI Service on port 8002 ...
call :port_in_use 8002
if not errorlevel 1 (
    echo        Port 8002 is already in use. Reusing the running mobile main AI service.
) else (
    start "SERVIO Mobile Main AI | Port 8002" /min cmd /k ""%~f0" main-ai"
)

timeout /t 5 /nobreak >nul

echo  [2/5] Starting Mobile AI Service on port 8001 ...
call :port_in_use 8001
if not errorlevel 1 (
    echo        Port 8001 is already in use. Reusing the running mobile AI service.
) else (
    start "SERVIO Mobile AI | Port 8001" /min cmd /k ""%~f0" mobile-ai"
)

timeout /t 4 /nobreak >nul

echo  [3/5] Running AI hard scenarios test ...
start "SERVIO AI Test Results" /min cmd /k ""%~f0" ai-test"

timeout /t 2 /nobreak >nul

echo  [4/5] Starting Backend on port 5000 ...
call :port_in_use 5000
if not errorlevel 1 (
    echo        Port 5000 is already in use. Reusing the running backend.
) else (
    start "SERVIO Backend | Port 5000" /min cmd /k ""%~f0" backend"
)

timeout /t 3 /nobreak >nul

echo  [5/5] Starting Flutter Mobile App ...
start "SERVIO Mobile App" /min cmd /k ""%~f0" mobile-app"

echo.
echo  All mobile services launched in separate windows.
echo.
echo  Mobile Main AI -^>  http://localhost:8002  (analyze-room)
echo  Mobile AI      -^>  http://localhost:8001  (legacy recommender)
echo  Backend    -^>  http://localhost:5000
echo  Mobile     -^>  Check the Flutter window for device status
echo.
echo  Note: First analyze-room request downloads large Stable Diffusion
echo        weights and is slow on CPU. GPU strongly recommended.
echo.
echo  Press any key to close this launcher window.
echo  (Closing this window does NOT stop the services)
echo  To stop everything, run: stop-mobile.bat
echo.
pause >nul
exit /b 0

:main_ai
title SERVIO Mobile Main AI ^| Port 8002
call :select_python "%AI_DIR%\requirements.txt"
if errorlevel 1 exit /b 1
cd /d "%AI_DIR%" || exit /b 1
"%PYTHON_EXE%" -m uvicorn main:app --port 8002 --reload
exit /b %errorlevel%

:mobile_ai
title SERVIO Mobile AI ^| Port 8001
call :select_python "%MOBILE_AI_DIR%\requirements.txt"
if errorlevel 1 exit /b 1
cd /d "%MOBILE_AI_DIR%" || exit /b 1
"%PYTHON_EXE%" -m uvicorn api:app --port 8001 --reload
exit /b %errorlevel%

:ai_test
title SERVIO AI Test Results
call :select_python "%MOBILE_AI_DIR%\requirements.txt"
if errorlevel 1 exit /b 1
cd /d "%MOBILE_AI_DIR%" || exit /b 1
"%PYTHON_EXE%" hard_scenarios_test.py
echo.
echo Press any key to close...
pause >nul
exit /b %errorlevel%

:backend
title SERVIO Backend ^| Port 5000
cd /d "%BACKEND_DIR%" || exit /b 1
npm run dev
exit /b %errorlevel%

:mobile_app
title SERVIO Mobile App
cd /d "%MOBILE_APP_DIR%" || exit /b 1
flutter run
exit /b %errorlevel%

:select_python
set "REQUIREMENTS_FILE=%~1"
set "PYTHON_EXE="

if exist "%AI_DIR%\venv\Scripts\python.exe" (
    set "PYTHON_EXE=%AI_DIR%\venv\Scripts\python.exe"
) else if exist "%AI_DIR%\venv\Scripts\py.exe" (
    set "PYTHON_EXE=%AI_DIR%\venv\Scripts\py.exe"
) else (
    echo No shared Python venv found at "%AI_DIR%\venv".
    where python >nul 2>&1
    if not errorlevel 1 set "PYTHON_EXE=python"
    if not defined PYTHON_EXE (
        where py >nul 2>&1
        if not errorlevel 1 set "PYTHON_EXE=py"
    )
    if defined PYTHON_EXE (
        echo Using "%PYTHON_EXE%" from PATH.
        echo.
    ) else (
        echo Python was not found on PATH.
        echo Install Python or create the shared venv first.
        echo.
    )
    echo If dependencies are missing, create the venv:
    echo   py -m venv "%AI_DIR%\venv"
    echo Then install requirements:
    echo   "%AI_DIR%\venv\Scripts\python.exe" -m pip install -r "%REQUIREMENTS_FILE%"
    echo.
)
if not defined PYTHON_EXE exit /b 1
exit /b 0

:port_in_use
powershell -NoProfile -Command "if (Get-NetTCPConnection -LocalPort %~1 -State Listen -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }"
exit /b %errorlevel%
