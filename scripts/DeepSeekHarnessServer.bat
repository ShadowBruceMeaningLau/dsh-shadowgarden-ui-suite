@echo off

setlocal

set URL=http://127.0.0.1:3080

rem If the local harness server is already running, skip to theme re-apply.

curl.exe -s -o NUL --max-time 2 %URL%

if not errorlevel 1 goto apply



rem Otherwise start it in a minimized window; retry once if the first launch fails.

start "DeepSeekHarnessServer" /min cmd /k "cd /d "%~dp0.." && (npx -y @deepseek-ai/dsh web || (timeout /t 15 /nobreak >nul & npx -y @deepseek-ai/dsh web))"

set tries=0

:waitloop

timeout /t 2 /nobreak >nul

set /a tries+=1

curl.exe -s -o NUL --max-time 2 %URL%

if not errorlevel 1 goto apply

if %tries% LSS 30 goto waitloop



:apply

rem The server re-extracts the official frontend on startup, which wipes the Shadow theme.
rem Re-apply it after the server (and its frontend) is up.

powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0apply-shadow-theme.ps1" >nul 2>&1

endlocal
