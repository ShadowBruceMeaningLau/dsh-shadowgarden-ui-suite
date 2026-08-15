param(
  [string]$Dist = ""
)
$ErrorActionPreference = 'Stop'
if ($Dist -eq "") {
  $dshHome = $env:DSH_HOME
  if (-not $dshHome) { $dshHome = Join-Path $env:USERPROFILE ".dsh" }
  $Dist = Join-Path $dshHome "profiles\node_modules\@deepseek-ai\dsh-web-frontend\dist"
}
$dist = $Dist
if (-not (Test-Path $dist)) {
  Write-Output "frontend dist not found: $dist"
  exit 1
}

# 1. remove injected tags from index.html
$html = Join-Path $dist "index.html"
$content = Get-Content $html -Raw
$orig = $content
$content = $content -replace '[ \t]*<link rel="stylesheet" href="/shadow-theme.css" />', ''
$content = $content -replace '[ \t]*<link rel="stylesheet" href="/dsh-kanban.css\?v=\d+" />', ''
$content = $content -replace '[ \t]*<script src="/dsh-kanban.js\?v=\d+" defer></script>', ''
$content = $content -replace '[ \t]*<meta name="theme-color" content="#[0-9a-fA-F]+" />', ''
if ($content -cne $orig) { Set-Content -Path $html -Value $content -NoNewline -Encoding UTF8 }

# 2. delete copied custom files
$files = @("shadow-theme.css", "shadow-bg.png", "shadow-bg.jpg", "shadowgarden2.jpg",
           "dsh-kanban.css", "dsh-kanban.js", "kanban.html", "github.html", "split.html")
foreach ($f in $files) {
  Remove-Item (Join-Path $dist $f) -Force -ErrorAction SilentlyContinue
}

Write-Output "Official frontend restored (dist: $dist)"
Write-Output "Refresh the DeepSeek Harness page (F5) to see the original style."
