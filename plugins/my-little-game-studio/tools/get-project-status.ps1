param(
  [string]$Root = "",
  [string]$ProjectRoot = "",
  [string]$StatePath = "",
  [string]$RuntimeRoot = "",
  [switch]$AllowTemplate
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$RuntimeRoot = Get-MLGSRuntimeRoot -Root $Root -RuntimeRoot $RuntimeRoot

$resolveArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/resolve-state.ps1"), "-Root", $Root, "-RuntimeRoot", $RuntimeRoot)
if ($ProjectRoot) { $resolveArgs += @("-ProjectRoot", $ProjectRoot) }
if ($StatePath) { $resolveArgs += @("-StatePath", $StatePath) }
if ($AllowTemplate) { $resolveArgs += "-AllowTemplate" }
$resolved = & powershell @resolveArgs | ConvertFrom-Json

$state = $null
if ($resolved.exists) {
  $state = Import-MLGSState -Path $resolved.state_path
  $validation = Test-MLGSState -State $state -AllowTemplate
  if (-not $validation.valid) { throw ("Invalid state: " + ($validation.errors -join "; ")) }
}

$detection = $null
if ($resolved.project_exists -and $resolved.mode -ne "template") {
  $detection = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/detect-project-stage.ps1") -Root $Root -ProjectRoot $resolved.project_root -RuntimeRoot $RuntimeRoot | ConvertFrom-Json
}

$latestEvents = @()
$activityPath = Join-Path $RuntimeRoot "logs/activity.jsonl"
if (Test-Path $activityPath) {
  foreach ($line in @(Get-Content -LiteralPath $activityPath -Encoding UTF8 | Where-Object { $_.Trim() } | Select-Object -Last 5)) {
    try { $latestEvents += ($line | ConvertFrom-Json) } catch { }
  }
}
$runtimeSummary = ""
$runtimePath = Join-Path $RuntimeRoot "runtime.json"
if (Test-Path $runtimePath) {
  try { $runtimeSummary = [string](Get-Content -LiteralPath $runtimePath -Raw -Encoding UTF8 | ConvertFrom-Json).summary } catch { }
}

if ($resolved.mode -eq "template" -or $null -eq $detection) {
  [pscustomobject]@{
    resolved = $resolved
    active_project = $null
    approvals = $null
    prototype = $null
    artifacts = [pscustomobject]@{}
    gates = $null
    gaps = @("No active project is configured.")
    risks = @()
    assumptions = @()
    next_command = "/mlgs start"
    next_reason = "Select a new or existing Unity project."
    next_options = @(
      [pscustomobject]@{ key = "A"; command = "/mlgs start a new Unity game"; label = "New game" }
      [pscustomobject]@{ key = "B"; command = "/mlgs adopt <path>"; label = "Adopt project" }
      [pscustomobject]@{ key = "C"; command = "/mlgs help"; label = "Help" }
    )
    latest_activity = $latestEvents
    runtime_summary = $runtimeSummary
  } | ConvertTo-Json -Depth 15
  exit 0
}

$gate = $detection.gates
$keys = @("A", "B", "C", "D")
$nextOptions = @()
for ($i = 0; $i -lt @($gate.options).Count; $i++) {
  $nextOptions += [pscustomobject]@{ key = $keys[$i]; command = $gate.options[$i]; label = $gate.options[$i] }
}

[pscustomobject]@{
  resolved = $resolved
  active_project = [pscustomobject]@{
    name = $state.activeProject.name
    phase = $state.phase.current
    observed_phase = $gate.observedPhase
    phase_mismatch = $gate.phaseMismatch
    owner_participation = $state.ownerParticipation.level
    project_root = $resolved.project_root
    state_path = $resolved.state_path
    state_format = $resolved.state_format
    migration_available = $resolved.state_format -eq "legacy-yaml"
    mode = $state.activeProject.mode
    unity_version = $state.activeProject.engineVersion
    approved_write_paths = @($state.activeProject.approvedWritePaths)
  }
  approvals = $state.approvals
  prototype = $state.prototype
  artifacts = $detection.artifacts
  gates = $gate.gates
  counts = $detection.counts
  gaps = @($detection.gaps)
  risks = @($state.risks)
  assumptions = @($state.assumptions)
  next_command = $gate.recommendedCommand
  next_reason = $gate.reason
  next_options = $nextOptions
  latest_activity = $latestEvents
  runtime_summary = $runtimeSummary
} | ConvertTo-Json -Depth 20
