param(
  [string]$Root = "",
  [string]$ProjectRoot = "",
  [string]$StatePath = "",
  [string]$ContextPath = "",
  [string]$RuntimeRoot = "",
  [string]$DashboardRoot = "",
  [int]$Limit = 25
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$resolveArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/resolve-state.ps1"), "-Root", $Root, "-AllowTemplate")
if ($ProjectRoot) { $resolveArgs += @("-ProjectRoot", $ProjectRoot) }
if ($StatePath) { $resolveArgs += @("-StatePath", $StatePath) }
if ($ContextPath) { $resolveArgs += @("-ContextPath", $ContextPath) }
if ($RuntimeRoot) { $resolveArgs += @("-RuntimeRoot", $RuntimeRoot) }
$resolved = & powershell @resolveArgs | ConvertFrom-Json
$RuntimeRoot = [System.IO.Path]::GetFullPath([string]$resolved.project_runtime_root)
if ([string]::IsNullOrWhiteSpace($DashboardRoot)) {
  $DashboardRoot = Join-Path $RuntimeRoot "dashboard"
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
  $statusArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/get-project-status.ps1"), "-Root", $Root, "-RuntimeRoot", [string]$resolved.global_runtime_root, "-AllowTemplate")
  if ($resolved.project_root -and $resolved.mode -ne "template") { $statusArgs += @("-ProjectRoot", [string]$resolved.project_root) }
  if ($ContextPath) { $statusArgs += @("-ContextPath", $ContextPath) }
  $status = & powershell @statusArgs | ConvertFrom-Json
} catch { }

$payload = [ordered]@{
  generatedAt = (Get-Date).ToString("o")
  runtime = $runtime
  events = @($events)
  status = $status
  projectId = [string]$resolved.project_id
  projectRoot = [string]$resolved.project_root
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
