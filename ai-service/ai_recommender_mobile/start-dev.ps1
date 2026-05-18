param(
    [string]$PythonCommand = "python"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ApiPort     = 8001
$UiPort      = 7860

function Stop-PortProcess {
    param([int]$Port)
    $connections = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    foreach ($conn in $connections) {
        if ($conn.OwningProcess) {
            Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
        }
    }
}

function Resolve-Python {
    param([string]$CommandName)
    if (Test-Path $CommandName) { return (Resolve-Path $CommandName).Path }
    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "Python not found. Pass -PythonCommand with the full python.exe path."
}

$PythonExe = Resolve-Python -CommandName $PythonCommand

Write-Host "Using Python : $PythonExe"
Write-Host "Stopping anything on ports $ApiPort and $UiPort..."
Stop-PortProcess -Port $ApiPort
Stop-PortProcess -Port $UiPort

Write-Host "Starting API on http://127.0.0.1:$ApiPort ..."
Start-Process powershell -ArgumentList @(
    "-NoExit", "-Command",
    "Set-Location '$ProjectRoot'; & '$PythonExe' -m uvicorn api:app --host 127.0.0.1 --port $ApiPort"
)

Start-Sleep -Seconds 3

Write-Host "Starting UI on http://127.0.0.1:$UiPort ..."
Start-Process powershell -ArgumentList @(
    "-NoExit", "-Command",
    "Set-Location '$ProjectRoot'; & '$PythonExe' ui.py"
)

Write-Host ""
Write-Host "Both services launched."
Write-Host "  API : http://localhost:$ApiPort"
Write-Host "  UI  : http://localhost:$UiPort"
