Option Explicit

Dim wsh, fso
Dim baseDir, repoDir, aiDir, backendDir, frontendDir, logsDir
Dim python

Set wsh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

baseDir     = fso.GetParentFolderName(WScript.ScriptFullName)
repoDir     = fso.GetAbsolutePathName(baseDir & "\..")
aiDir       = repoDir & "\ai-service\ai_recommender"
backendDir  = repoDir & "\backend"
frontendDir = repoDir & "\servio_frontend"
logsDir     = baseDir & "\logs"

If Not fso.FolderExists(logsDir) Then fso.CreateFolder(logsDir)

' ── Find Python with uvicorn ──────────────────────────────────────────────────
python = FindPython()
If python = "" Then
    MsgBox "Python with uvicorn not found." & vbCrLf & _
           "Run: pip install uvicorn fastapi groq gradio python-dotenv", _
           16, "Servio Launcher"
    WScript.Quit 1
End If

' ── Kill stale processes ──────────────────────────────────────────────────────
KillPort 8001
KillPort 7860
KillPort 5000
KillPort 5502
WScript.Sleep 1000

' ── Start services ────────────────────────────────────────────────────────────
RunHidden "cmd /c cd /d """ & aiDir & """ && """ & python & """ -m uvicorn api:app --host 127.0.0.1 --port 8001 >> """ & logsDir & "\ai_api.log"" 2>&1"
WScript.Sleep 1500

RunHidden "cmd /c cd /d """ & aiDir & """ && """ & python & """ ui.py >> """ & logsDir & "\ai_ui.log"" 2>&1"
WScript.Sleep 1500

RunHidden "cmd /c cd /d """ & backendDir & """ && node src/server.js >> """ & logsDir & "\backend.log"" 2>&1"
WScript.Sleep 1500

RunHidden "cmd /c cd /d """ & frontendDir & """ && """ & python & """ -m http.server 5502 >> """ & logsDir & "\frontend.log"" 2>&1"
WScript.Sleep 1500

' ── Open browser ─────────────────────────────────────────────────────────────
wsh.Run "http://127.0.0.1:5502/html/index.html", 1, False

MsgBox "Servio is running." & vbCrLf & vbCrLf & _
       "  Frontend  ->  http://127.0.0.1:5502/html/index.html" & vbCrLf & _
       "  Backend   ->  http://localhost:5000" & vbCrLf & _
       "  AI API    ->  http://localhost:8001" & vbCrLf & _
       "  AI UI     ->  http://localhost:7860" & vbCrLf & vbCrLf & _
       "To stop all services, run  Stop Servio.bat", _
       64, "Servio"

' ── Helpers ──────────────────────────────────────────────────────────────────
Function FindPython()
    Dim localApp, i, pyExe, pyDir, sitePackages
    localApp = wsh.ExpandEnvironmentStrings("%LOCALAPPDATA%")

    Dim c(7)
    c(0) = localApp & "\Programs\Python\Python39\python.exe"
    c(1) = localApp & "\Programs\Python\Python310\python.exe"
    c(2) = localApp & "\Programs\Python\Python311\python.exe"
    c(3) = localApp & "\Programs\Python\Python312\python.exe"
    c(4) = localApp & "\Programs\Python\Python38\python.exe"
    c(5) = "C:\Python39\python.exe"
    c(6) = "C:\Python310\python.exe"
    c(7) = "C:\Python311\python.exe"

    For i = 0 To 7
        pyExe = c(i)
        If fso.FileExists(pyExe) Then
            pyDir = fso.GetParentFolderName(pyExe)
            sitePackages = pyDir & "\Lib\site-packages\uvicorn"
            If fso.FolderExists(sitePackages) Then
                FindPython = pyExe
                Exit Function
            End If
        End If
    Next
    FindPython = ""
End Function

Sub RunHidden(cmd)
    wsh.Run cmd, 0, False
End Sub

Sub KillPort(port)
    wsh.Run "cmd /c for /f ""tokens=5"" %a in ('netstat -aon ^| findstr :" & port & "') do taskkill /f /pid %a >nul 2>&1", 0, True
End Sub
