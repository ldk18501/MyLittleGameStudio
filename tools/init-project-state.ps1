param(
  [string]$Root = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)),
  [Parameter(Mandatory = $true)]
  [string]$ProjectRoot,
  [Parameter(Mandatory = $true)]
  [string]$Name,
  [string]$Slug = "",
  [ValidateSet("internal", "external-adopted", "embedded")]
  [string]$Mode = "external-adopted",
  [string]$UnityVersion = "",
  [string[]]$ApprovedWritePaths = @(),
  [ValidateSet("high", "medium", "low")]
  [string]$PlanningAutomation = "high",
  [ValidateSet("high", "medium", "low")]
  [string]$ProductionAutomation = "medium",
  [switch]$SkipPointer
)

function ConvertTo-Slug {
  param([string]$Value)

  $slugValue = $Value.Trim().ToLowerInvariant() -replace "[^a-z0-9]+", "-"
  return $slugValue.Trim("-")
}

function ConvertTo-YamlList {
  param([string[]]$Values)

  $clean = @($Values | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($clean.Count -eq 0) {
    return "[]"
  }

  $lines = @()
  foreach ($value in $clean) {
    $escaped = $value.Replace("\", "/").Replace('"', '\"')
    $lines += "    - ""$escaped"""
  }

  return "`n" + ($lines -join "`n")
}

if ([string]::IsNullOrWhiteSpace($Slug)) {
  $Slug = ConvertTo-Slug $Name
}

if ([string]::IsNullOrWhiteSpace($Slug)) {
  Write-Error "Project slug cannot be empty."
  exit 1
}

$resolvedProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$mlgsDir = Join-Path $resolvedProjectRoot ".mlgs"
$statePath = Join-Path $mlgsDir "state.yaml"
$projectPath = Join-Path $mlgsDir "project.md"
$pointerPath = Join-Path $Root "studio/current-project.local.yaml"
$workspacePath = $(if ($Mode -eq "internal") { $resolvedProjectRoot } else { "" })
$externalPath = $(if ($Mode -eq "external-adopted") { $resolvedProjectRoot } else { "" })
$approved = ConvertTo-YamlList $ApprovedWritePaths
$now = (Get-Date).ToString("o")

if (-not (Test-Path $mlgsDir)) {
  New-Item -ItemType Directory -Path $mlgsDir | Out-Null
}

$state = @"
version: 0.1
updated: $now
kind: project

active_project:
  name: "$Name"
  slug: "$Slug"
  mode: $Mode # none | internal | external-adopted | embedded
  workspace_path: "$($workspacePath.Replace("\", "/"))"
  external_path: "$($externalPath.Replace("\", "/"))"
  engine: Unity
  engine_version: "$UnityVersion"
  approved_write_paths: $approved

automation:
  planning: $PlanningAutomation
  production: $ProductionAutomation

phase:
  current: idea-alignment
  allowed_values:
    - not-started
    - idea-alignment
    - concept-package
    - design-tech-plan
    - prototype-validation
    - production
    - polish-ship

approvals:
  idea_alignment: false
  concept_package: false
  design_tech_plan: false
  prototype_validation: false
  production_unblocked: false

prototype:
  policy: recommended # recommended | required | skipped-with-risk | not-needed
  type: html-or-unity-greybox
  verdict: pending # pending | pass | revise | skipped
  skip_reason: ""

next_action:
  command: references
  reason: "Project state initialized. Collect references or run status."

assumptions: []

risks: []
"@

$project = @"
# Project Brief

## Identity

- Name: $Name
- Slug: $Slug
- Mode: $Mode
- Unity version: $UnityVersion
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

$pointer = @"
version: 0.1
updated: "$now"
state_path: "$($statePath.Replace("\", "/"))"
project_root: "$($resolvedProjectRoot.Replace("\", "/"))"
"@

Set-Content -Path $statePath -Value $state -Encoding UTF8
Set-Content -Path $projectPath -Value $project -Encoding UTF8
if (-not $SkipPointer) {
  Set-Content -Path $pointerPath -Value $pointer -Encoding UTF8
}

[pscustomobject]@{
  state_path = $statePath
  project_path = $projectPath
  pointer_path = $(if ($SkipPointer) { "" } else { $pointerPath })
} | ConvertTo-Json -Depth 5
