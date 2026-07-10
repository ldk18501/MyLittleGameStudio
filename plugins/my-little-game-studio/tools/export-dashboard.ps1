param(
  [string]$Root = "",
  [string]$RuntimeRoot = "",
  [string]$DashboardRoot = "",
  [int]$Limit = 25
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$runtimeWasExplicit = -not [string]::IsNullOrWhiteSpace($RuntimeRoot)
$RuntimeRoot = Get-MLGSRuntimeRoot -Root $Root -RuntimeRoot $RuntimeRoot
if ([string]::IsNullOrWhiteSpace($DashboardRoot)) {
  $DashboardRoot = if ($runtimeWasExplicit -or (Test-Path (Join-Path $Root ".codex-plugin/plugin.json"))) { Join-Path $RuntimeRoot "dashboard" } else { Join-Path $Root "dashboard" }
}
$DashboardRoot = [System.IO.Path]::GetFullPath($DashboardRoot)
New-Item -ItemType Directory -Path $DashboardRoot -Force | Out-Null

$sourceIndex = Join-Path $Root "dashboard/index.html"
$targetIndex = Join-Path $DashboardRoot "index.html"
if ((Test-Path $sourceIndex) -and ([System.IO.Path]::GetFullPath($sourceIndex) -ne [System.IO.Path]::GetFullPath($targetIndex))) {
  Copy-Item -LiteralPath $sourceIndex -Destination $targetIndex -Force
}

$runtimePath = Join-Path $RuntimeRoot "runtime.json"
$activityPath = Join-Path $RuntimeRoot "logs/activity.jsonl"
$runtime = if (Test-Path $runtimePath) {
  Get-Content -LiteralPath $runtimePath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
  [pscustomobject]@{ version = "0.2"; updated = ""; activeCommand = ""; activeTask = ""; summary = ""; project = $null; agents = @(); latestEvents = @() }
}

$events = @()
if (Test-Path $activityPath) {
  foreach ($line in @(Get-Content -LiteralPath $activityPath -Encoding UTF8 | Where-Object { $_.Trim() } | Select-Object -Last $Limit)) {
    try { $events += ($line | ConvertFrom-Json) } catch { }
  }
}

$status = $null
try {
  $status = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/get-project-status.ps1") -Root $Root -RuntimeRoot $RuntimeRoot -AllowTemplate | ConvertFrom-Json
} catch { }

$payload = [ordered]@{
  generatedAt = (Get-Date).ToString("o")
  runtime = $runtime
  events = @($events)
  status = $status
}
$content = "window.MLGS_STUDIO_DATA = " + ($payload | ConvertTo-Json -Depth 30) + ";"
$outputPath = Join-Path $DashboardRoot "studio-data.js"
$tempPath = Join-Path $DashboardRoot (".studio-data." + [guid]::NewGuid().ToString("N") + ".tmp")
try {
  Set-Content -LiteralPath $tempPath -Value $content -Encoding UTF8
  Move-Item -LiteralPath $tempPath -Destination $outputPath -Force
} finally {
  if (Test-Path $tempPath) { Remove-Item -LiteralPath $tempPath -Force }
}

[pscustomobject]@{ output_path = $outputPath; dashboard_root = $DashboardRoot; event_count = $events.Count } | ConvertTo-Json
