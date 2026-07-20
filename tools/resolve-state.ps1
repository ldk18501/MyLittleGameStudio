param(
  [string]$Root = "",
  [string]$ProjectRoot = "",
  [string]$StatePath = "",
  [string]$ContextPath = "",
  [string]$RuntimeRoot = "",
  [switch]$AllowLegacyPointer,
  [switch]$AllowTemplate,
  [switch]$RequireProjectContext
)

if ([string]::IsNullOrWhiteSpace($Root)) {
  $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
}
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")

$runtimeWasExplicit = -not [string]::IsNullOrWhiteSpace($RuntimeRoot)
$globalRuntimeRoot = Get-MLGSRuntimeRoot -Root $Root -RuntimeRoot $RuntimeRoot
$templatePath = Join-Path $Root "studio/state.json"
$pointerPath = Join-Path $globalRuntimeRoot "current-project.json"
$legacyPointerPath = Join-Path $Root "studio/current-project.local.yaml"
$mode = "missing"
$resolvedStatePath = ""
$resolvedProjectRoot = ""
$resolvedContextPath = ""
$contextProjectId = ""
$contextRuntimeRoot = ""
$contextInvocationId = ""
$contextTaskId = ""
$needsRepair = $false
$repairReason = ""
$usedPointerPath = ""
$pointerMismatch = $false
$pointerProjectRoot = ""

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

if (-not [string]::IsNullOrWhiteSpace($ContextPath)) {
  $resolvedContextPath = Resolve-MLGSPath -Base $Root -Path $ContextPath
  if (-not (Test-Path $resolvedContextPath)) { throw "MLGS project context does not exist: $resolvedContextPath" }
  $context = Get-Content -LiteralPath $resolvedContextPath -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($required in @("projectId", "projectRoot", "statePath", "runtimeRoot", "invocationId")) {
    if ([string]::IsNullOrWhiteSpace([string]$context.$required)) { throw "MLGS project context is missing $required." }
  }
  $resolvedProjectRoot = [System.IO.Path]::GetFullPath([string]$context.projectRoot)
  $resolvedStatePath = [System.IO.Path]::GetFullPath([string]$context.statePath)
  $contextProjectId = [string]$context.projectId
  $contextRuntimeRoot = [System.IO.Path]::GetFullPath([string]$context.runtimeRoot)
  $contextInvocationId = [string]$context.invocationId
  $contextTaskId = [string]$context.taskId
  $expectedProjectId = Get-MLGSProjectId -ProjectRoot $resolvedProjectRoot
  if ($contextProjectId -ne $expectedProjectId) { throw "MLGS project context projectId does not match projectRoot." }
  $expectedStatePath = [System.IO.Path]::GetFullPath((Get-MLGSStateCandidate -ProjectRoot $resolvedProjectRoot))
  if ($resolvedStatePath -ne $expectedStatePath) { throw "MLGS project context statePath does not belong to projectRoot." }
  if ((Split-Path -Leaf $contextRuntimeRoot) -ne $contextProjectId -or (Split-Path -Leaf (Split-Path -Parent $contextRuntimeRoot)) -ne "projects") {
    throw "MLGS project context runtimeRoot is not a project-scoped runtime directory."
  }
  $mode = "bound-context"
} elseif (-not [string]::IsNullOrWhiteSpace($StatePath)) {
  $resolvedStatePath = Resolve-MLGSPath -Base $Root -Path $StatePath
  $resolvedProjectRoot = Split-Path -Parent (Split-Path -Parent $resolvedStatePath)
  $mode = "explicit-state"
} elseif (-not [string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $resolvedProjectRoot = Resolve-MLGSPath -Base $Root -Path $ProjectRoot
  $resolvedStatePath = Get-MLGSStateCandidate -ProjectRoot $resolvedProjectRoot
  $mode = "explicit-project"
} else {
  $nearest = Find-NearestProjectState -Start (Get-Location).Path
  if ($null -ne $nearest) {
    $resolvedStatePath = $nearest.state
    $resolvedProjectRoot = $nearest.root
    $mode = "nearest-project"
  } elseif (Test-Path $pointerPath) {
    $pointer = Get-Content -LiteralPath $pointerPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $resolvedStatePath = Resolve-MLGSPath -Base $globalRuntimeRoot -Path ([string]$pointer.statePath)
    $resolvedProjectRoot = Resolve-MLGSPath -Base $globalRuntimeRoot -Path ([string]$pointer.projectRoot)
    $mode = "user-pointer"
    $usedPointerPath = $pointerPath
  } elseif ($AllowLegacyPointer -and (Test-Path $legacyPointerPath)) {
    $pointer = Get-Content -LiteralPath $legacyPointerPath -Raw -Encoding UTF8
    $resolvedStatePath = Resolve-MLGSPath -Base $Root -Path (Read-LegacyPointerValue $pointer "state_path")
    $resolvedProjectRoot = Resolve-MLGSPath -Base $Root -Path (Read-LegacyPointerValue $pointer "project_root")
    $mode = "legacy-pointer"
    $usedPointerPath = $legacyPointerPath
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

if ((Test-Path $pointerPath) -and $mode -notin @("user-pointer", "template", "missing")) {
  try {
    $currentPointer = Get-Content -LiteralPath $pointerPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $pointerProjectRoot = Resolve-MLGSPath -Base $globalRuntimeRoot -Path ([string]$currentPointer.projectRoot)
    if ($resolvedProjectRoot -and $pointerProjectRoot) {
      $pointerMismatch = (Get-MLGSNormalizedProjectRoot -ProjectRoot $resolvedProjectRoot) -ne (Get-MLGSNormalizedProjectRoot -ProjectRoot $pointerProjectRoot)
    }
  } catch { }
}

$projectId = if ($resolvedProjectRoot -and $mode -ne "template") { Get-MLGSProjectId -ProjectRoot $resolvedProjectRoot } else { "" }
$projectRuntimeRoot = if ($contextRuntimeRoot) {
  $contextRuntimeRoot
} elseif ($projectId) {
  Get-MLGSProjectRuntimeRoot -GlobalRuntimeRoot $globalRuntimeRoot -ProjectRoot $resolvedProjectRoot
} else {
  $globalRuntimeRoot
}
$contextSafe = @("bound-context", "explicit-state", "explicit-project", "nearest-project") -contains $mode
$contextReason = if ($contextSafe) { "" } elseif ($mode -eq "user-pointer") { "A global pointer is only a compatibility fallback and cannot authorize project writes." } elseif ($mode -eq "legacy-pointer") { "A legacy pointer cannot authorize project writes." } else { "No bound project context is available." }
if ($RequireProjectContext -and -not $contextSafe) { $needsRepair = $true; $repairReason = $contextReason }

[pscustomobject]@{
  mode = $mode
  exists = $exists
  project_exists = $projectExists
  needs_repair = $needsRepair
  repair_reason = $repairReason
  state_path = $resolvedStatePath
  state_format = $(if ($resolvedStatePath.EndsWith(".json")) { "json" } elseif ($exists) { "legacy-yaml" } else { "" })
  project_root = $resolvedProjectRoot
  project_id = $projectId
  context_path = $resolvedContextPath
  context_invocation_id = $contextInvocationId
  context_task_id = $contextTaskId
  context_safe = $contextSafe
  context_reason = $contextReason
  pointer_mismatch = $pointerMismatch
  pointer_project_root = $pointerProjectRoot
  template_path = $templatePath
  template_exists = $templateExists
  pointer_path = $(if ($usedPointerPath) { $usedPointerPath } else { $pointerPath })
  global_runtime_root = $globalRuntimeRoot
  project_runtime_root = $projectRuntimeRoot
  runtime_root = $projectRuntimeRoot
} | ConvertTo-Json -Depth 8
