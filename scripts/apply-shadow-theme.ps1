param(
  [string]$Dist = ""
)
$ErrorActionPreference = 'Stop'

# ---- locate the frontend dist directory ----
if ($Dist -eq "") {
  $dshHome = $env:DSH_HOME
  if (-not $dshHome) { $dshHome = Join-Path $env:USERPROFILE ".dsh" }
  $Dist = Join-Path $dshHome "profiles\node_modules\@deepseek-ai\dsh-web-frontend\dist"
  if (-not (Test-Path $Dist)) {
    # fallback: the package name may change across versions, search for any *web-frontend*
    $base = Join-Path $dshHome "profiles\node_modules\@deepseek-ai"
    if (Test-Path $base) {
      $hit = Get-ChildItem $base -Directory | Where-Object { $_.Name -match 'web-frontend' } |
             ForEach-Object { Join-Path $_.FullName "dist" } |
             Where-Object { Test-Path $_ } | Select-Object -First 1
      if ($hit) { $Dist = $hit }
    }
  }
}
$dist = $Dist
if (-not (Test-Path $dist)) {
  Write-Output "frontend dist not found: $dist"
  Write-Output "Install and run DeepSeek Harness at least once (npx @deepseek-ai/dsh web),"
  Write-Output "or pass the dist path explicitly: apply-shadow-theme.ps1 -Dist <path>"
  exit 1
}

# ---- copy custom files (source lives in ../web) ----
$srcWeb = Join-Path $PSScriptRoot "..\web"
$srcCss = Join-Path $srcWeb "shadow-theme.css"
Copy-Item $srcCss (Join-Path $dist "shadow-theme.css") -Force
foreach ($bgName in @("shadow-bg.jpg", "shadow-bg.png")) {
  $srcBg = Join-Path $srcWeb $bgName
  if (Test-Path $srcBg) { Copy-Item $srcBg (Join-Path $dist $bgName) -Force }
}
$srcSplit = Join-Path $srcWeb "split.html"
if (Test-Path $srcSplit) { Copy-Item $srcSplit (Join-Path $dist "split.html") -Force }
foreach ($kName in @("kanban.html", "github.html", "services.html", "dsh-kanban.css", "dsh-kanban.js", "shadowgarden2.jpg")) {
  $srcK = Join-Path $srcWeb $kName
  if (Test-Path $srcK) { Copy-Item $srcK (Join-Path $dist $kName) -Force }
}

# ---- patch index.html ----
$html = Join-Path $dist "index.html"
$content = Get-Content $html -Raw

# keep one backup of the official index.html (first run only)
$bak = Join-Path $dist "index.html.dshbak"
if (-not (Test-Path $bak)) {
  Copy-Item $html $bak -Force
  Write-Output "Backup saved: $bak"
}

$changed = $false
if ($content -notmatch 'shadow-theme\.css') {
  $content = $content -replace '(<link rel="stylesheet" crossorigin href="/assets/index-[^"]+\.css">)', "`$1`n    <link rel=`"stylesheet`" href=`"/shadow-theme.css`" />"
  $changed = $true
}
if ($content -notmatch 'name="theme-color"') {
  $content = $content -replace '(<meta name="viewport"[^>]*>)', "`$1`n    <meta name=`"theme-color`" content=`"#07070d`" />"
  $changed = $true
}
$fixed = $content -replace 'name="theme-color" content="#0c0c14"', 'name="theme-color" content="#07070d"'
if ($fixed -cne $content) { $content = $fixed; $changed = $true }
if ($content -notmatch 'dsh-kanban\.js') {
  $content = $content -replace '(<link rel="stylesheet" href="/shadow-theme.css" />)', "`$1`n    <link rel=`"stylesheet`" href=`"/dsh-kanban.css?v=78`" />`n    <script src=`"/dsh-kanban.js?v=78`" defer></script>"
  $changed = $true
} else {
  $fixed2 = $content -replace 'href="/dsh-kanban.css"', 'href="/dsh-kanban.css?v=78"'
  $fixed2 = $fixed2 -replace 'src="/dsh-kanban.js" defer', 'src="/dsh-kanban.js?v=78" defer'
  if ($fixed2 -cne $content) { $content = $fixed2; $changed = $true }
}
if ($changed) { Set-Content -Path $html -Value $content -NoNewline -Encoding UTF8 }

# ---- verification checklist ----
$check = Get-Content $html -Raw
$warn = @()
if ($check -notmatch 'shadow-theme\.css') { $warn += "WARN: theme css link was NOT injected - index.html structure may have changed in the new dsh version." }
if ($check -notmatch 'dsh-kanban\.js') { $warn += "WARN: drawer/kanban script was NOT injected - index.html structure may have changed." }
if ($warn.Count -gt 0) {
  Write-Output ""
  foreach ($w in $warn) { Write-Output $w }
  Write-Output "Files are copied anyway; the theme may only partially apply. Report the badge text (under the sidebar wordmark) when asking for help."
} else {
  Write-Output "All injections verified OK."
}
Write-Output "Shadow theme applied to: $dist"
Write-Output "Done. Refresh the DeepSeek Harness page (F5) to see it."
