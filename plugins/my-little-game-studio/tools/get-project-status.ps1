param(
  [string]$Root = "",
  [string]$ProjectRoot = "",
  [string]$StatePath = "",
  [string]$ContextPath = "",
  [string]$RuntimeRoot = "",
  [switch]$AllowUserPointer,
  [switch]$InspectPointer,
  [switch]$AllowLegacyPointer,
  [switch]$AllowTemplate,
  [ValidateSet("model", "full")][string]$View = "full",
  [ValidateRange(0, 10)][int]$ActivityLimit = 3
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$RuntimeRoot = Get-MLGSRuntimeRoot -Root $Root -RuntimeRoot $RuntimeRoot

function Write-MLGSStatusOutput {
  param($Result)
  if ($View -eq "full") {
    $Result | ConvertTo-Json -Depth 20
    return
  }

  $compactEvents = @()
  foreach ($event in @($Result.latest_activity | Select-Object -Last $ActivityLimit)) {
    $compactEvents += [ordered]@{
      id = [string]$event.id
      timestamp = [string]$event.timestamp
      command = [string]$event.command
      status = [string]$event.status
      taskId = [string]$event.taskId
      title = [string]$event.title
      summary = [string]$event.summary
    }
  }

  $compactProject = $null
  if ($null -ne $Result.active_project) {
    $compactProject = [ordered]@{
      name = [string]$Result.active_project.name
      phase = [string]$Result.active_project.phase
      observedPhase = [string]$Result.active_project.observed_phase
      phaseMismatch = [bool]$Result.active_project.phase_mismatch
      participation = [string]$Result.active_project.owner_participation
      projectRoot = [string]$Result.active_project.project_root
      projectId = [string]$Result.active_project.project_id
    }
    if ($InspectPointer) { $compactProject["pointerMismatch"] = [bool]$Result.active_project.pointer_mismatch }
  }

  $compactProductization = $null
  if ($null -ne $Result.productization) {
    $compactProductization = [ordered]@{
      targetVersion = [string]$Result.productization.target_version
      scopeItems = [int]$Result.productization.release_scope_items
      planned = [int]$Result.productization.planned_count
      implemented = [int]$Result.productization.implemented_count
      verified = [int]$Result.productization.verified_count
      scopeGap = [int]$Result.productization.scope_count_gap
      visualTargets = [int]$Result.productization.visual_targets_total
      visualTargetsApproved = [int]$Result.productization.visual_targets_approved
      contentStatus = [string]$Result.productization.content_architecture.status
      contentValidationPassed = [bool]$Result.productization.content_architecture.validation_passed
      buildPolicyStatus = [string]$Result.productization.build_policy.status
      initialPlatformValidation = [string]$Result.productization.build_policy.initial_validation_status
    }
  }

  [ordered]@{
    schemaVersion = "1.0"
    resolved = [ordered]@{
      mode = [string]$Result.resolved.mode
      projectRoot = [string]$Result.resolved.project_root
      projectId = [string]$Result.resolved.project_id
      statePath = [string]$Result.resolved.state_path
      contextSafe = [bool]$Result.resolved.context_safe
      needsRepair = [bool]$Result.resolved.needs_repair
      reason = $(if ($Result.resolved.repair_reason) { [string]$Result.resolved.repair_reason } else { [string]$Result.resolved.context_reason })
    }
    project = $compactProject
    productization = $compactProductization
    gaps = @($Result.gaps | Select-Object -First 10)
    risks = @($Result.risks | Select-Object -First 10)
    nextCommand = [string]$Result.next_command
    nextReason = [string]$Result.next_reason
    nextOptions = @($Result.next_options | Select-Object -First 4)
    recentActivity = @($compactEvents)
    runtimeSummary = [string]$Result.runtime_summary
  } | ConvertTo-Json -Depth 12 -Compress
}

$resolveArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/resolve-state.ps1"), "-Root", $Root, "-RuntimeRoot", $RuntimeRoot)
if ($ProjectRoot) { $resolveArgs += @("-ProjectRoot", $ProjectRoot) }
if ($StatePath) { $resolveArgs += @("-StatePath", $StatePath) }
if ($ContextPath) { $resolveArgs += @("-ContextPath", $ContextPath) }
if ($AllowUserPointer) { $resolveArgs += "-AllowUserPointer" }
if ($InspectPointer) { $resolveArgs += "-InspectPointer" }
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
  $eventReadLimit = if ($View -eq "full") { 5 } else { $ActivityLimit }
  foreach ($line in @(Get-Content -LiteralPath $activityPath -Encoding UTF8 | Where-Object { $_.Trim() } | Select-Object -Last $eventReadLimit)) {
    try { $latestEvents += ($line | ConvertFrom-Json) } catch { }
  }
}
$runtimeSummary = ""
$runtimePath = Join-Path $projectRuntimeRoot "runtime.json"
if (Test-Path $runtimePath) {
  try { $runtimeSummary = [string](Get-Content -LiteralPath $runtimePath -Raw -Encoding UTF8 | ConvertFrom-Json).summary } catch { }
}

if ($resolved.mode -eq "template" -or $null -eq $detection) {
  $templateResult = [pscustomobject]@{
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
  }
  Write-MLGSStatusOutput -Result $templateResult
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
  content_architecture = [pscustomobject]@{
    status = "missing"
    experience_class = ""
    minimum_playtime_hours = 0
    target_playtime_hours = 0
    estimated_playtime_hours = 0
    references = 0
    loops = 0
    systems = 0
    content_families = 0
    progression_arcs = 0
    validation_passed = $false
    issues = @()
  }
  build_policy = [pscustomobject]@{
    status = "missing"
    automatic_development_builds = $false
    initial_validation_status = ""
    initial_target_platform = ""
    initial_attempts = 0
    build_history_count = 0
    next_automatic_build_stage = "release-candidate"
  }
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
$contentArchitecturePath = Join-Path $resolved.project_root "design/content-architecture.json"
if (Test-Path $contentArchitecturePath) {
  try {
    $contentArchitecture = Get-Content -LiteralPath $contentArchitecturePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $contentValidationRaw = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-content-architecture.ps1") -Root $Root -ProjectRoot $resolved.project_root 2>$null
    $contentValidation = $contentValidationRaw | ConvertFrom-Json
    $productization.content_architecture = [pscustomobject]@{
      status = [string]$contentArchitecture.status
      experience_class = [string]$contentArchitecture.experienceTarget.experienceClass
      minimum_playtime_hours = [double]$contentArchitecture.experienceTarget.targetPlaytimeHours.minimum
      target_playtime_hours = [double]$contentArchitecture.experienceTarget.targetPlaytimeHours.target
      estimated_playtime_hours = [double]$contentArchitecture.contentBudget.estimatedTotalHours
      references = @($contentArchitecture.research.references).Count
      loops = @($contentArchitecture.loopArchitecture).Count
      systems = @($contentArchitecture.systemPortfolio).Count
      content_families = @($contentArchitecture.contentPlan).Count
      progression_arcs = @($contentArchitecture.progressionArcs).Count
      validation_passed = [bool]$contentValidation.passed
      issues = @($contentValidation.issues)
    }
  } catch {
    $productization.content_architecture.status = "invalid"
    $productization.content_architecture.issues = @($_.Exception.Message)
  }
}
$buildPolicyPath = Join-Path $resolved.project_root ".mlgs/build-policy.json"
if (Test-Path $buildPolicyPath) {
  try {
    $buildPolicy = Get-Content -LiteralPath $buildPolicyPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $productization.build_policy = [pscustomobject]@{
      status = "active"
      automatic_development_builds = [bool]$buildPolicy.automaticDevelopmentBuilds
      initial_validation_status = [string]$buildPolicy.initialValidation.status
      initial_target_platform = [string]$buildPolicy.initialValidation.targetPlatform
      initial_attempts = [int]$buildPolicy.initialValidation.attempts
      build_history_count = @($buildPolicy.history).Count
      next_automatic_build_stage = "release-candidate"
    }
  } catch {
    $productization.build_policy.status = "invalid"
  }
}
$keys = @("A", "B", "C", "D")
$nextOptions = @()
for ($i = 0; $i -lt @($gate.options).Count; $i++) {
  $nextOptions += [pscustomobject]@{ key = $keys[$i]; command = $gate.options[$i]; label = $gate.options[$i] }
}

$result = [pscustomobject]@{
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
}
Write-MLGSStatusOutput -Result $result
