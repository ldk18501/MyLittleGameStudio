param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-z0-9][a-z0-9-]*$")][string]$TaskId,
  [ValidateSet("ready", "implemented", "approved")][string]$MinimumStatus = "ready"
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$issues = @(); $warnings = @()
$understandingRaw = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-codebase-understanding.ps1") -Root $Root -ProjectRoot $ProjectRoot 2>$null
try { $understanding = $understandingRaw | ConvertFrom-Json } catch { $understanding = [pscustomobject]@{ passed = $false; issues = @("Codebase understanding validator returned invalid output.") } }
if (-not [bool]$understanding.passed) { $issues += @($understanding.issues) }

$profilePath = Join-Path $ProjectRoot "design/code/codebase-profile.json"
$modulePath = Join-Path $ProjectRoot "design/code/module-map.json"
$contextPath = Join-Path $ProjectRoot "production/context-packs/$TaskId.json"
$planPath = Join-Path $ProjectRoot "production/change-plans/$TaskId.json"
foreach ($entry in @(@{label="task context";path=$contextPath}, @{label="change plan";path=$planPath})) { if (-not (Test-Path $entry.path)) { $issues += "Missing $($entry.label) for task '$TaskId'." } }
if ($issues.Count -eq 0) {
  try { $profile = Get-Content $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json; $moduleMap = Get-Content $modulePath -Raw -Encoding UTF8 | ConvertFrom-Json; $context = Get-Content $contextPath -Raw -Encoding UTF8 | ConvertFrom-Json; $plan = Get-Content $planPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $issues += "Invalid code task JSON: $($_.Exception.Message)" }
}
if ($null -ne $context -and $null -ne $plan) {
  if ([string]$context.id -ne $TaskId -or [string]$context.workPackageId -ne $TaskId -or [string]$plan.taskId -ne $TaskId) { $issues += "Task ids must match '$TaskId'." }
  if ([string]$context.projectKind -ne [string]$profile.projectKind -or [string]$plan.projectKind -ne [string]$profile.projectKind) { $issues += "Code task projectKind does not match the current profile." }
  if ([string]$context.intensity -ne [string]$profile.intensity -or [string]$plan.intensity -ne [string]$profile.intensity) { $issues += "Code task intensity does not match the current profile." }
  if ((Get-FileHash $profilePath -Algorithm SHA256).Hash -ne [string]$context.freshness.codebaseProfileSha256) { $issues += "Task context is stale because the codebase profile changed." }
  if ((Get-FileHash $modulePath -Algorithm SHA256).Hash -ne [string]$context.freshness.moduleMapSha256) { $issues += "Task context is stale because the module map changed." }
  if (@($context.requirementSources).Count -eq 0) { $issues += "Task context needs requirement sources." }
  foreach ($relative in @($context.requirementSources)) { $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$relative) -Label "Task requirement source"; if ($pathIssue) { $issues += $pathIssue } }
  if (@($context.codeFilesRead).Count -lt [int]$profile.policy.minimumContextFiles) { $issues += "Task context needs at least $($profile.policy.minimumContextFiles) code files for '$($profile.intensity)' intensity." }
  if (@($context.exemplars).Count -lt [int]$profile.policy.minimumExemplars) { $issues += "Task context needs at least $($profile.policy.minimumExemplars) style/sibling exemplars." }
  foreach ($collection in @(@($context.codeFilesRead), @($context.exemplars))) {
    foreach ($file in $collection) {
      $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$file.path) -Label "Task context code evidence"
      if ($pathIssue) { $issues += $pathIssue; continue }
      $full = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ([string]$file.path)
      if ((Get-FileHash $full -Algorithm SHA256).Hash -ne [string]$file.sha256) { $issues += "Task context code evidence is stale: $($file.path)" }
    }
  }
  if ([string]$profile.projectKind -ne "new-project") {
    if ([string]::IsNullOrWhiteSpace([string]$context.targetModuleId)) { $issues += "Existing-project task needs a target module." }
    if (@($context.integrationPoints).Count -eq 0) { $issues += "Existing-project task needs explicit reuse/adapt/replace/create integration points." }
  }
  if ([string]$profile.intensity -eq "deep") {
    if ([string]$context.structuralEvidence.provider -eq "none" -or [string]$context.structuralEvidence.preImpactVerdict -ne "pass") { $issues += "Deep task needs passing pre-change structural impact analysis." }
    if (@($context.structuralEvidence.queries).Count -eq 0 -or @($context.structuralEvidence.evidence).Count -eq 0) { $issues += "Deep task needs structural queries and evidence." }
  }
  foreach ($relative in @($context.structuralEvidence.evidence)) { $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$relative) -Label "Task structural evidence"; if ($pathIssue) { $issues += $pathIssue } }
  if (@($context.plannedFiles.modify).Count + @($context.plannedFiles.create).Count + @($context.plannedFiles.delete).Count -eq 0) { $issues += "Task context needs an explicit planned change set." }
  if ((@($context.plannedFiles.modify) -join "|") -ne (@($plan.plannedFiles.modify) -join "|") -or (@($context.plannedFiles.create) -join "|") -ne (@($plan.plannedFiles.create) -join "|") -or (@($context.plannedFiles.delete) -join "|") -ne (@($plan.plannedFiles.delete) -join "|")) { $issues += "Task context and change plan file sets disagree." }
  if (@($plan.responsibilities).Count -eq 0 -or @($plan.testPlan).Count -eq 0) { $issues += "Change plan needs responsibilities and tests." }
  $evolutionDecision = @("replace-legacy", "create-new-foundation", "isolated-new-module") -contains [string]$plan.architectureDecision
  if ([string]$profile.projectKind -ne "new-project" -and $evolutionDecision) {
    if (-not [bool]$profile.policy.allowNewFoundation) { $issues += "The selected codebase policy does not allow a new/replacement foundation." }
    if (-not [bool]$plan.legacyTradeoff.approvalRequired -or -not [bool]$plan.legacyTradeoff.approved) { $issues += "Existing-project framework replacement/new isolation requires an explicit approved legacy tradeoff." }
    foreach ($name in @("consistencyBenefit", "newRequirementBenefit", "risk")) { if ([string]::IsNullOrWhiteSpace([string]$plan.legacyTradeoff.$name)) { $issues += "Legacy tradeoff '$name' is required for architecture evolution." } }
  }
  $statusRank = @{ draft = 0; ready = 1; implemented = 2; approved = 3; blocked = -1 }
  if ($statusRank[[string]$context.status] -lt $statusRank[$MinimumStatus]) { $issues += "Task context status must be at least $MinimumStatus." }
  if ([string]$context.architectVerdict -ne "pass" -or [string]$plan.architectVerdict -ne "pass" -or [string]$plan.status -notin @("approved", "implemented")) { $issues += "Task context and change plan require Unity Architect pass." }
  if (@($context.blockers).Count -gt 0 -or @($plan.blockers).Count -gt 0) { $issues += "Task context or change plan still has blockers." }
}
$result = [pscustomobject]@{ passed = $issues.Count -eq 0; taskId = $TaskId; projectKind = [string]$profile.projectKind; intensity = [string]$profile.intensity; issues = @($issues); warnings = @($warnings); contextPath = $contextPath; changePlanPath = $planPath }
$result | ConvertTo-Json -Depth 12
if (-not $result.passed) { exit 20 }
