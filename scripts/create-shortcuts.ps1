$ErrorActionPreference = 'Stop'
# Create desktop shortcuts for the whole Shadow suite (icons shipped with this package)
# Layout: desktop root keeps only 旗舰版 + 极速版; everything else lives in "DeepSeek 工具"
$ws = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath('Desktop')
$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path $edge)) { $edge = "C:\Program Files\Microsoft\Edge\Application\msedge.exe" }
if (-not (Test-Path $edge)) { Write-Output "Edge not found, skipping shortcut creation"; exit 1 }

function New-AppShortcut {
  param([string]$Name, [string]$AppUrl, [string]$Icon, [string]$Args = "", [string]$Dir = "")
  $targetDir = if ($Dir -ne "") { $Dir } else { $desktop }
  $lnk = $ws.CreateShortcut((Join-Path $targetDir "$Name.lnk"))
  $lnk.TargetPath = $edge
  $lnk.Arguments = if ($Args -ne "") { $Args } else { "--app=$AppUrl" }
  $lnk.IconLocation = "$Icon,0"
  $lnk.WorkingDirectory = $desktop
  $lnk.Description = $Name
  $lnk.Save()
}

$pkg = $PSScriptRoot
$root = Join-Path $pkg ".."
$assetDir = Join-Path $root "assets"
$webDir = Join-Path $root "web"
$runtimeDir = Join-Path $root "runtime"
$toolDir = Join-Path $desktop "DeepSeek 工具"
New-Item -Path $toolDir -ItemType Directory -Force | Out-Null

# 桌面根目录：仅两个主入口
# 旗舰版入口：服务中心窗口（DSH+用量+Chat 标签、多开，经 VBS 隐藏启动器，避免黑色控制台闪屏）
$hubVbs = Join-Path $pkg "DeepSeekHarnessHub.vbs"
$wscript = Join-Path $env:WINDIR "System32\wscript.exe"
if (Test-Path $hubVbs) {
  $lnk = $ws.CreateShortcut((Join-Path $desktop "DeepSeek Harness 旗舰版.lnk"))
  $lnk.TargetPath = $wscript
  $lnk.Arguments = '"' + $hubVbs + '"'
  $lnk.WorkingDirectory = $root
  $lnk.IconLocation = (Join-Path $assetDir "deepseek.ico") + ",0"
  $lnk.Description = "DeepSeek Harness - flagship hub window (no console flash)"
  $lnk.Save()
}
# 极速版入口：Edge 应用窗口，纯本地 DSH 页面（与分屏入口同款方式，无任何组装）
New-AppShortcut "DeepSeek Harness 极速版" "http://127.0.0.1:3080" (Join-Path $assetDir "deepseek.ico")

# 「DeepSeek 工具」文件夹：辅助入口与内部文件
New-AppShortcut "DeepSeek Harness 分屏" "http://127.0.0.1:3080/shadow/split.html" (Join-Path $assetDir "deepseek.ico") "" $toolDir
New-AppShortcut "看板" "http://127.0.0.1:3080/shadow/kanban.html" (Join-Path $assetDir "kanban.ico") "" $toolDir
New-AppShortcut "DeepSeek API 用量" "https://platform.deepseek.com/usage" (Join-Path $assetDir "deepseek.ico") "" $toolDir
New-AppShortcut "GitHub" "https://github.com" (Join-Path $assetDir "github.ico") "" $toolDir
New-AppShortcut "DeepSeek Chat" "https://chat.deepseek.com/" (Join-Path $assetDir "deepseek.ico") "" $toolDir

# Register dshchat:// protocol -> DeepSeek Chat.lnk (in tool folder)
$chatLnk = Join-Path $toolDir "DeepSeek Chat.lnk"
$cmdExe = Join-Path $env:WINDIR "System32\cmd.exe"
New-Item -Path "HKCU:\Software\Classes\dshchat\shell\open\command" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\dshchat" -Name "(default)" -Value "URL:DeepSeek Chat"
Set-ItemProperty -Path "HKCU:\Software\Classes\dshchat" -Name "URL Protocol" -Value ""
Set-ItemProperty -Path "HKCU:\Software\Classes\dshchat\shell\open\command" -Name "(default)" -Value ('"' + $cmdExe + '" /c start "" "' + $chatLnk + '" "%1"')

# Register dshusage:// protocol -> DeepSeek API 用量.lnk (in tool folder)
$usageLnk = Join-Path $toolDir "DeepSeek API 用量.lnk"
New-Item -Path "HKCU:\Software\Classes\dshusage\shell\open\command" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\dshusage" -Name "(default)" -Value "URL:DeepSeek Usage"
Set-ItemProperty -Path "HKCU:\Software\Classes\dshusage" -Name "URL Protocol" -Value ""
Set-ItemProperty -Path "HKCU:\Software\Classes\dshusage\shell\open\command" -Name "(default)" -Value ('"' + $cmdExe + '" /c start "" "' + $usageLnk + '" "%1"')

# Register dshhub:// protocol -> self-built tabbed hub window (no Edge chrome)
$hubExe = Join-Path $runtimeDir "dsh-hub.exe"
New-Item -Path "HKCU:\Software\Classes\dshhub\shell\open\command" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\dshhub" -Name "(default)" -Value "URL:DSH Hub Tabs"
Set-ItemProperty -Path "HKCU:\Software\Classes\dshhub" -Name "URL Protocol" -Value ""
Set-ItemProperty -Path "HKCU:\Software\Classes\dshhub\shell\open\command" -Name "(default)" -Value ('"' + $hubExe + '" "%1"')

# Register dshnotify:// protocol -> toast.lnk (in tool folder) -> hidden PowerShell balloon
$toastLnk = Join-Path $toolDir "dsh-toast.lnk"
$tlnk = $ws.CreateShortcut($toastLnk)
$tlnk.TargetPath = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
$tlnk.Arguments = '-NoProfile -WindowStyle Hidden -Command "Add-Type -AssemblyName System.Windows.Forms; $n=New-Object System.Windows.Forms.NotifyIcon; $n.Icon=[System.Drawing.SystemIcons]::Information; $n.Visible=$true; $n.BalloonTipTitle=''DeepSeek Harness''; $n.BalloonTipText=''任务已完成''; $n.ShowBalloonTip(6000); Start-Sleep -Seconds 7; $n.Dispose()"'
$tlnk.WindowStyle = 7
$tlnk.IconLocation = (Join-Path $assetDir "deepseek.ico") + ",0"
$tlnk.WorkingDirectory = $desktop
$tlnk.Save()
$rundll = Join-Path $env:WINDIR "System32\rundll32.exe"
New-Item -Path "HKCU:\Software\Classes\dshnotify\shell\open\command" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\dshnotify" -Name "(default)" -Value "URL:DeepSeek Harness Notify"
Set-ItemProperty -Path "HKCU:\Software\Classes\dshnotify" -Name "URL Protocol" -Value ""
Set-ItemProperty -Path "HKCU:\Software\Classes\dshnotify\shell\open\command" -Name "(default)" -Value ('"' + $rundll + '" shell32.dll,ShellExec_RunDLL "' + $toastLnk + '"')

Write-Output "Desktop shortcuts created (protocols registered; auxiliary shortcuts live in DeepSeek 工具)."
