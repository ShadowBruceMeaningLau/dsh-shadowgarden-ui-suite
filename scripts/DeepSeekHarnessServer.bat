@echo off

setlocal

set URL=http://127.0.0.1:3080

rem If the local harness server is already running, do nothing.

curl.exe -s -o NUL --max-time 2 %URL%

if not errorlevel 1 exit /b 0

rem Otherwise start it in a minimized window; retry once if the first launch fails.

start "DeepSeekHarnessServer" /min cmd /k "cd /d "%~dp0.." && (npx -y @deepseek-ai/dsh web || (timeout /t 15 /nobreak >nul & npx -y @deepseek-ai/dsh web))"

endlocal
