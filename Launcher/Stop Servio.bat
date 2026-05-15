@echo off
echo Stopping Servio services...

taskkill /f /im python.exe >nul 2>&1
taskkill /f /im python3.exe >nul 2>&1
taskkill /f /im node.exe >nul 2>&1

echo Done. All services stopped.
timeout /t 2 >nul
