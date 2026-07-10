param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$Name,
  [string]$Slug = "",
  [ValidateSet("internal", "external-adopted", "embedded")][string]$Mode = "external-adopted",
  [string]$UnityVersion = "",
  [string[]]$ApprovedWritePaths = @(),
  [ValidateSet("high", "medium", "low")][string]$PlanningAutomation = "high",
  [ValidateSet("high", "medium", "low")][string]$ProductionAutomation = "medium",
  [ValidateSet("low", "medium", "high")][string]$OwnerParticipation = "medium",
  [string]$RuntimeRoot = "",
  [switch]$SkipPointer,
  [switch]$Force
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")

if ([string]::IsNullOrWhiteSpace($Slug)) {
  $Slug = ($Name.Trim().ToLowerInvariant() -replace "[^a-z0-9]+", "-").Trim("-")
}
if ([string]::IsNullOrWhiteSpace($Slug)) { throw "Project slug cannot be empty." }

$resolvedProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$mlgsDir = Join-Path $resolvedProjectRoot ".mlgs"
$statePath = Join-Path $mlgsDir "state.json"
$legacyStatePath = Join-Path $mlgsDir "state.yaml"
$projectPath = Join-Path $mlgsDir "project.md"
$RuntimeRoot = Get-MLGSRuntimeRoot -Root $Root -RuntimeRoot $RuntimeRoot
$pointerPath = Join-Path $RuntimeRoot "current-project.json"

if (((Test-Path $statePath) -or (Test-Path $legacyStatePath)) -and -not $Force) {
  throw "Project state already exists. Use migrate-state.ps1 for legacy YAML or pass -Force intentionally."
}
New-Item -ItemType Directory -Path $mlgsDir -Force | Out-Null

$approved = @($ApprovedWritePaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Replace("\", "/").Trim("/") } | Select-Object -Unique)
$now = (Get-Date).ToString("o")
$state = [ordered]@{
  schemaVersion = "0.3"
  updated = $now
  kind = "project"
  activeProject = [ordered]@{
    name = $Name
    slug = $Slug
    mode = $Mode
    workspacePath = $(if ($Mode -eq "internal") { $resolvedProjectRoot.Replace("\", "/") } else { "" })
    externalPath = $(if ($Mode -eq "external-adopted") { $resolvedProjectRoot.Replace("\", "/") } else { "" })
    engine = "Unity"
    language = "C#"
    engineVersion = $UnityVersion
    approvedWritePaths = $approved
  }
  ownerParticipation = [ordered]@{ level = $OwnerParticipation; notes = "" }
  automation = [ordered]@{ planning = $PlanningAutomation; production = $ProductionAutomation }
  phase = [ordered]@{ current = "intake" }
  approvals = [ordered]@{
    projectSelected = $true
    conceptPackage = $false
    designTechPlan = $false
    prototypeValidation = $false
    productionUnblocked = $false
  }
  prototype = [ordered]@{ policy = "recommended"; type = "html-or-unity-greybox"; verdict = "pending"; skipReason = "" }
  nextAction = [ordered]@{
    command = "/mlgs status"
    reason = "Project state initialized. Inspect gaps and choose the next MLGS action."
    options = @("/mlgs status", "/mlgs brainstorm and create the concept package", "/mlgs plan systems and tasks")
  }
  assumptions = @()
  risks = @()
  staff = [ordered]@{ lastLead = "producer"; lastAgents = @() }
}

$normalizedState = ($state | ConvertTo-Json -Depth 30 | ConvertFrom-Json)
$validation = Test-MLGSState -State $normalizedState
if (-not $validation.valid) { throw ("Generated state is invalid: " + ($validation.errors -join "; ")) }
Write-MLGSJsonAtomic -Path $statePath -Value $state

$project = @"
# Project Brief

## Identity

- Name: $Name
- Slug: $Slug
- Mode: $Mode
- Unity version: $UnityVersion
- Owner participation: $OwnerParticipation
- Project path: $($resolvedProjectRoot.Replace("\", "/"))

## Current Goal

[What the user wants to make.]

## Constraints

- Time:
- Team:
- Budget:
- Existing architecture:
- Must keep:
- Must avoid:
"@
$project | Set-Content -LiteralPath $projectPath -Encoding UTF8

if (-not $SkipPointer) {
  $pointer = [ordered]@{
    schemaVersion = "1.0"
    updated = $now
    statePath = $statePath.Replace("\", "/")
    projectRoot = $resolvedProjectRoot.Replace("\", "/")
  }
  Write-MLGSJsonAtomic -Path $pointerPath -Value $pointer
}

[pscustomobject]@{
  state_path = $statePath
  project_path = $projectPath
  pointer_path = $(if ($SkipPointer) { "" } else { $pointerPath })
  runtime_root = $RuntimeRoot
} | ConvertTo-Json -Depth 6
