@echo off

setlocal

set URL=http://127.0.0.1:3080



rem If the local harness server is not answering, start it in a minimized window.

curl.exe -s -o NUL --max-time 2 %URL%

if not errorlevel 1 goto open



echo Starting DeepSeek Harness server...

start "DeepSeekHarnessServer" /min cmd /k "cd /d "%~dp0.." && (npx -y @deepseek-ai/dsh web || (timeout /t 15 /nobreak >nul & npx -y @deepseek-ai/dsh web))"

set tries=0



:waitloop

timeout /t 2 /nobreak >nul

set /a tries+=1

curl.exe -s -o NUL --max-time 2 %URL%

if not errorlevel 1 goto open

if %tries% LSS 30 goto waitloop

echo Server did not start within 60 seconds. Check the minimized server window.

pause

exit /b 1



:open

rem Re-apply the Shadow theme in case the server re-extracted the official frontend.

powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0apply-shadow-theme.ps1" >nul 2>&1

start "" "%~dp0..\runtime\dsh-hub.exe" dsh

endlocal