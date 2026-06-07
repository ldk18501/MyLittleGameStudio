param(
  [string]$Root = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)),
  [int]$Limit = 50
)

$dashboardDir = Join-Path $Root "dashboard"
$runtimePath = Join-Path $Root "studio/runtime.json"
$activityPath = Join-Path $Root "studio/logs/activity.jsonl"
$outputPath = Join-Path $dashboardDir "studio-data.js"

if (-not (Test-Path $dashboardDir)) {
  New-Item -ItemType Directory -Path $dashboardDir | Out-Null
}

if (Test-Path $runtimePath) {
  $runtime = Get-Content -Path $runtimePath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
  $runtime = [pscustomobject]@{
    version = "0.1"
    updated = (Get-Date).ToString("o")
    activeCommand = ""
    activeTask = ""
    summary = "No MLGS runtime file exists yet."
    agents = @()
    latestEvents = @()
  }
}

$events = @()
if (Test-Path $activityPath) {
  $lines = Get-Content -Path $activityPath -Encoding UTF8 | Where-Object { $_.Trim().Length -gt 0 } | Select-Object -Last $Limit
  foreach ($line in $lines) {
    try {
      $events += ($line | ConvertFrom-Json)
    } catch {
      $events += [pscustomobject]@{
        id = "invalid"
        timestamp = ""
        command = "unknown"
        title = "Invalid trace line"
        status = "blocked"
        leadAgent = "producer"
        agentsUsed = @("producer")
        skillsUsed = @()
        filesRead = @()
        filesWritten = @()
        assumptions = @()
        decisions = @("A malformed trace line was ignored by the dashboard exporter.")
        verification = @()
        summary = $line
      }
    }
  }
}

$payload = [pscustomobject]@{
  generatedAt = (Get-Date).ToString("o")
  runtime = $runtime
  events = $events
}

$json = $payload | ConvertTo-Json -Depth 20
$content = "window.MLGS_STUDIO_DATA = $json;"
Set-Content -Path $outputPath -Value $content -Encoding UTF8

Write-Output "Dashboard data exported: $outputPath"
