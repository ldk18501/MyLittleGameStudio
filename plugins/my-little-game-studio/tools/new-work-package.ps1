param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-z0-9][a-z0-9-]*$")][string]$Id,
  [Parameter(Mandatory = $true)][string]$Title,
  [Parameter(Mandatory = $true)][string]$Objective,
  [ValidateSet("general", "code", "art", "design", "qa", "content", "release")][string]$WorkKind = "general",
  [string]$Owner = "gameplay-developer",
  [ValidateSet("direct", "pipeline", "fan-out-and-synthesize", "adversarial-review", "loop-until-done")][string]$Strategy = "direct",
  [ValidateRange(1, 5)][int]$MaxAttempts = 3,
  [switch]$Force
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
if (-not (Test-Path $ProjectRoot)) { throw "Project root does not exist: $ProjectRoot" }

$schemaTarget = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ".mlgs/work-package.schema.json"
New-Item -ItemType Directory -Path (Split-Path -Parent $schemaTarget) -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $Root "studio/work-package.schema.json") -Destination $schemaTarget -Force
$path = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath "production/work-packages/$Id.json"
New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
if ((Test-Path $path) -and -not $Force) { throw "Work package already exists: $path" }

$package = [ordered]@{
  '$schema' = "../../.mlgs/work-package.schema.json"
  schemaVersion = "1.1"
  id = $Id
  workKind = $WorkKind
  contextPackPath = ""
  changePlanPath = ""
  conformanceReportPath = ""
  title = $Title
  objective = $Objective
  scopeIds = @()
  nonGoals = @()
  owner = $Owner
  support = @("qa-lead")
  dependencies = @()
  strategy = $Strategy
  executionPlanPath = ""
  verificationPolicy = [ordered]@{
    cadence = "task-boundary"
    aggregateSmallChanges = $true
    focusedChecks = "risk-triggered"
    routineFullSuiteMaxRunsPerAttempt = 1
    rerunPassingChecks = "on-relevant-input-change"
    fullRegressionTriggers = @(
      "shared-contract-change",
      "scene-or-prefab-wiring",
      "persistence-or-config-change",
      "previous-check-failure",
      "build-or-phase-gate"
    )
  }
  status = "ready"
  successCriteria = @([ordered]@{
    id = "criterion-1"
    statement = "Replace with a measurable acceptance criterion."
    evidence = @()
    objectiveVerdict = "pending"
    objectiveChecks = @([ordered]@{ id = "artifact-exists"; kind = "file-exists"; path = ""; contains = ""; command = ""; status = "pending"; detail = "" })
  })
  budget = [ordered]@{ maxAttempts = $MaxAttempts; currentAttempt = 0 }
  attempts = @()
  declaredVerdict = "pending"
  objectiveVerdict = "pending"
  gaps = @()
  blockers = @()
  updated = (Get-Date).ToString("o")
}
Write-MLGSJsonAtomic -Path $path -Value $package
[pscustomobject]@{ created = $true; path = $path; id = $Id; max_attempts = $MaxAttempts } | ConvertTo-Json -Depth 6
