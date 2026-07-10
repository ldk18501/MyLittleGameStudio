param(
  [string]$Root = "",
  [string]$ProjectRoot = "",
  [string]$StatePath = "",
  [string]$RuntimeRoot = "",
  [switch]$AllowTemplate
)

if ([string]::IsNullOrWhiteSpace($Root)) {
  $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
}
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")

$RuntimeRoot = Get-MLGSRuntimeRoot -Root $Root -RuntimeRoot $RuntimeRoot
$templatePath = Join-Path $Root "studio/state.json"
$pointerPath = Join-Path $RuntimeRoot "current-project.json"
$legacyPointerPath = Join-Path $Root "studio/current-project.local.yaml"
$mode = "missing"
$resolvedStatePath = ""
$resolvedProjectRoot = ""
$needsRepair = $false
$repairReason = ""
$usedPointerPath = ""

function Read-LegacyPointerValue {
  param([string]$Content, [string]$Key)
  $pattern = '(?m)^\s*{0}\s*:\s*["'']?([^"''\r\n]+)["'']?\s*$' -f [regex]::Escape($Key)
  $match = [regex]::Match($Content, $pattern)
  if ($match.Success) { return $match.Groups[1].Value.Trim() }
  return ""
}

function Find-NearestProjectState {
  param([string]$Start)
  if ([string]::IsNullOrWhiteSpace($Start) -or -not (Test-Path $Start)) { return $null }
  $current = [System.IO.DirectoryInfo][System.IO.Path]::GetFullPath($Start)
  while ($null -ne $current) {
    $candidate = Get-MLGSStateCandidate -ProjectRoot $current.FullName
    if (Test-Path $candidate) {
      return [pscustomobject]@{ state = $candidate; root = $current.FullName }
    }
    $current = $current.Parent
  }
  return $null
}

if (-not [string]::IsNullOrWhiteSpace($StatePath)) {
  $resolvedStatePath = Resolve-MLGSPath -Base $Root -Path $StatePath
  $resolvedProjectRoot = Split-Path -Parent (Split-Path -Parent $resolvedStatePath)
  $mode = "explicit-state"
} elseif (-not [string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $resolvedProjectRoot = Resolve-MLGSPath -Base $Root -Path $ProjectRoot
  $resolvedStatePath = Get-MLGSStateCandidate -ProjectRoot $resolvedProjectRoot
  $mode = "explicit-project"
} elseif (Test-Path $pointerPath) {
  $pointer = Get-Content -LiteralPath $pointerPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $resolvedStatePath = Resolve-MLGSPath -Base $RuntimeRoot -Path ([string]$pointer.statePath)
  $resolvedProjectRoot = Resolve-MLGSPath -Base $RuntimeRoot -Path ([string]$pointer.projectRoot)
  $mode = "user-pointer"
  $usedPointerPath = $pointerPath
} elseif (Test-Path $legacyPointerPath) {
  $pointer = Get-Content -LiteralPath $legacyPointerPath -Raw -Encoding UTF8
  $resolvedStatePath = Resolve-MLGSPath -Base $Root -Path (Read-LegacyPointerValue $pointer "state_path")
  $resolvedProjectRoot = Resolve-MLGSPath -Base $Root -Path (Read-LegacyPointerValue $pointer "project_root")
  $mode = "legacy-pointer"
  $usedPointerPath = $legacyPointerPath
} else {
  $nearest = Find-NearestProjectState -Start (Get-Location).Path
  if ($null -ne $nearest) {
    $resolvedStatePath = $nearest.state
    $resolvedProjectRoot = $nearest.root
    $mode = "nearest-project"
  } elseif ($AllowTemplate -and (Test-Path $templatePath)) {
    $resolvedStatePath = $templatePath
    $resolvedProjectRoot = $Root
    $mode = "template"
  }
}

if (-not [string]::IsNullOrWhiteSpace($resolvedProjectRoot) -and -not (Test-Path $resolvedStatePath)) {
  $candidate = Get-MLGSStateCandidate -ProjectRoot $resolvedProjectRoot
  if (Test-Path $candidate) { $resolvedStatePath = $candidate }
}

$exists = (-not [string]::IsNullOrWhiteSpace($resolvedStatePath)) -and (Test-Path $resolvedStatePath)
$projectExists = (-not [string]::IsNullOrWhiteSpace($resolvedProjectRoot)) -and (Test-Path $resolvedProjectRoot)
$templateExists = Test-Path $templatePath
if (@("user-pointer", "legacy-pointer") -contains $mode -and -not $exists) {
  $needsRepair = $true
  $repairReason = if (-not $projectExists) { "project_root does not exist" } else { "state path does not exist" }
}

[pscustomobject]@{
  mode = $mode
  exists = $exists
  project_exists = $projectExists
  needs_repair = $needsRepair
  repair_reason = $repairReason
  state_path = $resolvedStatePath
  state_format = $(if ($resolvedStatePath.EndsWith(".json")) { "json" } elseif ($exists) { "legacy-yaml" } else { "" })
  project_root = $resolvedProjectRoot
  template_path = $templatePath
  template_exists = $templateExists
  pointer_path = $(if ($usedPointerPath) { $usedPointerPath } else { $pointerPath })
  runtime_root = $RuntimeRoot
} | ConvertTo-Json -Depth 6
