param(
  [string]$Root = "",
  [string]$ProjectRoot = "",
  [string]$StatePath = "",
  [string]$ContextPath = "",
  [string]$RuntimeRoot = "",
  [switch]$AllowLegacyPointer,
  [switch]$AllowTemplate
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$RuntimeRoot = Get-MLGSRuntimeRoot -Root $Root -RuntimeRoot $RuntimeRoot

$resolveArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/resolve-state.ps1"), "-Root", $Root, "-RuntimeRoot", $RuntimeRoot)
if ($ProjectRoot) { $resolveArgs += @("-ProjectRoot", $ProjectRoot) }
if ($StatePath) { $resolveArgs += @("-StatePath", $StatePath) }
if ($ContextPath) { $resolveArgs += @("-ContextPath", $ContextPath) }
if ($AllowLegacyPointer) { $resolveArgs += "-AllowLegacyPointer" }
if ($AllowTemplate) { $resolveArgs += "-AllowTemplate" }
$resolved = & powershell @resolveArgs | ConvertFrom-Json
$projectRuntimeRoot = [string]$resolved.project_runtime_root

$state = $null
if ($resolved.exists) {
  $state = Import-MLGSState -Path $resolved.state_path
  $validation = Test-MLGSState -State $state -AllowTemplate
  if (-not $validation.valid) { throw ("Invalid state: " + ($validation.errors -join "; ")) }
}

$detection = $null
if ($resolved.project_exists -and $resolved.mode -ne "template") {
  $detection = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/detect-project-stage.ps1") -Root $Root -ProjectRoot $resolved.project_root -RuntimeRoot $resolved.global_runtime_root | ConvertFrom-Json
}

$latestEvents = @()
$activityPath = Join-Path $projectRuntimeRoot "logs/activity.jsonl"
if (Test-Path $activityPath) {
  foreach ($line in @(Get-Content -LiteralPath $activityPath -Encoding UTF8 | Where-Object { $_.Trim() } | Select-Object -Last 5)) {
    try { $latestEvents += ($line | ConvertFrom-Json) } catch { }
  }
}
$runtimeSummary = ""
$runtimePath = Join-Path $projectRuntimeRoot "runtime.json"
if (Test-Path $runtimePath) {
  try { $runtimeSummary = [string](Get-Content -LiteralPath $runtimePath -Raw -Encoding UTF8 | ConvertFrom-Json).summary } catch { }
}

if ($resolved.mode -eq "template" -or $null -eq $detection) {
  [pscustomobject]@{
    resolved = $resolved
    active_project = $null
    approvals = $null
    prototype = $null
    productization = $null
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
$productization = [ordered]@{
  target_version = ""
  release_scope_items = 0
  scope_by_type = [pscustomobject]@{}
  scope_by_status = [pscustomobject]@{}
  planned_count = 0
  implemented_count = 0
  verified_count = 0
  scope_count_gap = 0
  visual_targets_total = 0
  visual_targets_approved = 0
}
$scopePath = Join-Path $resolved.project_root "production/scope/release-scope.json"
if (Test-Path $scopePath) {
  try {
    $scope = Get-Content -LiteralPath $scopePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $productization.target_version = [string]$scope.targetVersion
    $items = @($scope.items)
    $productization.release_scope_items = $items.Count
    $typeCounts = [ordered]@{}
    foreach ($group in @($items | Group-Object type)) { $typeCounts[$group.Name] = $group.Count }
    $statusCounts = [ordered]@{}
    foreach ($group in @($items | Group-Object status)) { $statusCounts[$group.Name] = $group.Count }
    $productization.scope_by_type = [pscustomobject]$typeCounts
    $productization.scope_by_status = [pscustomobject]$statusCounts
    $productization.planned_count = [int](($items | Measure-Object plannedCount -Sum).Sum)
    $productization.implemented_count = [int](($items | Measure-Object implementedCount -Sum).Sum)
    $productization.verified_count = [int](($items | Measure-Object verifiedCount -Sum).Sum)
    $productization.scope_count_gap = [Math]::Max(0, $productization.planned_count - $productization.verified_count)
  } catch { }
}
$visualTargetPath = Join-Path $resolved.project_root "design/art/visual-target.json"
if (Test-Path $visualTargetPath) {
  try {
    $visualTarget = Get-Content -LiteralPath $visualTargetPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $productization.visual_targets_total = @($visualTarget.targets).Count
    $productization.visual_targets_approved = @($visualTarget.targets | Where-Object { [bool]$_.approved }).Count
  } catch { }
}
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
    project_id = $resolved.project_id
    project_runtime_root = $resolved.project_runtime_root
    pointer_mismatch = $resolved.pointer_mismatch
    pointer_project_root = $resolved.pointer_project_root
    migration_available = $resolved.state_format -eq "legacy-yaml"
    mode = $state.activeProject.mode
    unity_version = $state.activeProject.engineVersion
    approved_write_paths = @($state.activeProject.approvedWritePaths)
  }
  approvals = $state.approvals
  prototype = $state.prototype
  productization = [pscustomobject]$productization
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
