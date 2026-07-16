param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-z0-9][a-z0-9-]*$")][string]$TaskId,
  [string[]]$RequirementSources = @(),
  [string[]]$ScopeIds = @(),
  [string]$TargetModuleId = "",
  [switch]$Force
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$profilePath = Join-Path $ProjectRoot "design/code/codebase-profile.json"
$moduleMapPath = Join-Path $ProjectRoot "design/code/module-map.json"
if (-not (Test-Path $profilePath) -or -not (Test-Path $moduleMapPath)) { throw "Run tools/inspect-codebase.ps1 -Apply before creating a code task." }
$workPackagePath = Join-Path $ProjectRoot "production/work-packages/$TaskId.json"
if (-not (Test-Path $workPackagePath)) { throw "Create the matching production work package before its code context: production/work-packages/$TaskId.json" }
$profile = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
$moduleMap = Get-Content -LiteralPath $moduleMapPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $TargetModuleId) { $TargetModuleId = [string](@($moduleMap.modules) | Select-Object -First 1).id }

foreach ($schema in @("task-context.schema.json", "change-plan.schema.json")) {
  $schemaTarget = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ".mlgs/$schema"
  New-Item -ItemType Directory -Path (Split-Path -Parent $schemaTarget) -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $Root "studio/$schema") -Destination $schemaTarget -Force
}
$contextPath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath "production/context-packs/$TaskId.json"
$planPath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath "production/change-plans/$TaskId.json"
if (-not $Force -and ((Test-Path $contextPath) -or (Test-Path $planPath))) { throw "Code task context or change plan already exists for: $TaskId" }

$structuralProvider = [string]$profile.structuralAnalysis.provider
$preImpact = if ([bool]$profile.policy.requirePostImpact -or [string]$profile.policy.structuralAnalysisRequirement -eq "required") { "pending" } else { "not-required" }
$postImpact = if ([bool]$profile.policy.requirePostImpact) { "pending" } else { "not-required" }
$context = [ordered]@{
  '$schema' = "../../.mlgs/task-context.schema.json"
  schemaVersion = "1.0"
  id = $TaskId
  workPackageId = $TaskId
  projectKind = [string]$profile.projectKind
  intensity = [string]$profile.intensity
  requirementSources = @($RequirementSources)
  scopeIds = @($ScopeIds)
  targetModuleId = $TargetModuleId
  codeFilesRead = @()
  symbols = @()
  exemplars = @()
  integrationPoints = @()
  dependencies = @()
  plannedFiles = [ordered]@{ modify = @(); create = @(); delete = @(); evidence = @() }
  unitySurfaces = [ordered]@{ scenes = @(); prefabs = @(); configuration = @(); ui = @(); tests = @() }
  structuralEvidence = [ordered]@{ provider = $structuralProvider; queries = @(); evidence = @(); preImpactVerdict = $preImpact; postImpactVerdict = $postImpact; notes = "Scale evidence to the selected codebase intensity." }
  freshness = [ordered]@{ codebaseProfileSha256 = (Get-FileHash -LiteralPath $profilePath -Algorithm SHA256).Hash; moduleMapSha256 = (Get-FileHash -LiteralPath $moduleMapPath -Algorithm SHA256).Hash }
  architectVerdict = "pending"
  status = "draft"
  blockers = @()
  updated = (Get-Date).ToString("o")
}
$decision = if ([string]$profile.projectKind -eq "new-project") { "create-new-foundation" } else { "extend-existing" }
$plan = [ordered]@{
  '$schema' = "../../.mlgs/change-plan.schema.json"
  schemaVersion = "1.0"
  taskId = $TaskId
  projectKind = [string]$profile.projectKind
  intensity = [string]$profile.intensity
  targetModuleId = $TargetModuleId
  architectureDecision = $decision
  decisionReason = $(if ($decision -eq "create-new-foundation") { "Create only the minimal foundation required by the first real feature." } else { "Extend the nearest approved module unless an explicit tradeoff justifies adaptation or replacement." })
  legacyTradeoff = [ordered]@{ consistencyBenefit = ""; newRequirementBenefit = ""; risk = ""; approvalRequired = $false; approved = $false }
  responsibilities = @([ordered]@{ name = "replace-me"; scriptRole = "pure-csharp"; path = "Assets/Game/ReplaceMe.cs"; moduleId = $TargetModuleId; owns = @("Replace with one explicit responsibility.") })
  reuseExisting = @()
  newAbstractions = @()
  plannedFiles = [ordered]@{ modify = @(); create = @(); delete = @(); evidence = @() }
  dependencyChanges = @()
  lifecycle = "Describe initialization, activation, cleanup, cancellation, and scene unload behavior."
  dataOwnership = "Describe authoritative runtime, configuration, and save-state ownership."
  errorHandling = "Describe validation, failure, fallback, and logging behavior."
  testPlan = @("Replace with focused EditMode, PlayMode, compile, or integration evidence.")
  architectVerdict = "pending"
  status = "draft"
  blockers = @()
  updated = (Get-Date).ToString("o")
}
Write-MLGSJsonAtomic -Path $contextPath -Value $context
Write-MLGSJsonAtomic -Path $planPath -Value $plan
$workPackage = Get-Content -LiteralPath $workPackagePath -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($entry in @(
  @{ Name = "workKind"; Value = "code" },
  @{ Name = "contextPackPath"; Value = "production/context-packs/$TaskId.json" },
  @{ Name = "changePlanPath"; Value = "production/change-plans/$TaskId.json" },
  @{ Name = "conformanceReportPath"; Value = "production/quality/code-conformance-$TaskId.json" }
)) {
  if ($workPackage.PSObject.Properties.Name -contains $entry.Name) { $workPackage.($entry.Name) = $entry.Value }
  else { $workPackage | Add-Member -MemberType NoteProperty -Name $entry.Name -Value $entry.Value }
}
$workPackage.updated = (Get-Date).ToString("o")
Write-MLGSJsonAtomic -Path $workPackagePath -Value $workPackage
[pscustomobject]@{ taskId = $TaskId; workPackagePath = $workPackagePath; projectKind = $profile.projectKind; intensity = $profile.intensity; contextPath = $contextPath; changePlanPath = $planPath } | ConvertTo-Json -Depth 8
