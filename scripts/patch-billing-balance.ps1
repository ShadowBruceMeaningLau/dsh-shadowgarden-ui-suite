$ErrorActionPreference = 'Stop'
# 给 dsh-billing-balance 打补丁：把 ctx.get() 读取的 credentials/settings/fs
# 声明进 inject，让 cordis 等这些服务 ACTIVE 后再 apply——否则启动竞态下
# ctx.get('credentials') 返回 undefined，插件整个进程周期都读不到余额。
# 幂等：已打过则直接退出。
$profileDir = Join-Path $env:USERPROFILE '.dsh\profiles\web'
$target = Join-Path $profileDir 'node_modules\dsh-billing-balance\index.js'
if (-not (Test-Path $target)) { Write-Output 'dsh-billing-balance not installed, skipping'; exit 0 }

$content = [System.IO.File]::ReadAllText($target, [System.Text.Encoding]::UTF8)
if ($content -match "inject = \['webServer', 'credentials'") { Write-Output 'already patched'; exit 0 }
if ($content -notmatch "export const inject = \['webServer'\]") {
  Write-Output 'unexpected inject line — plugin may have changed, skipping'
  exit 1
}
$patched = $content.Replace(
  "export const inject = ['webServer']",
  "export const inject = ['webServer', 'credentials', 'settings', 'fs'] // local patch: wait for services before apply"
)

# 断开 pnpm 硬链接再写入，避免污染 pnpm 内容存储
$tmp = "$target.patchtmp"
[System.IO.File]::WriteAllText($tmp, $patched, (New-Object System.Text.UTF8Encoding $false))
Remove-Item $target -Force
Move-Item $tmp $target -Force
Write-Output 'patched dsh-billing-balance: inject now waits for credentials/settings/fs'
