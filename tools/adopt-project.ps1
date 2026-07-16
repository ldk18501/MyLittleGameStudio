param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [string]$Name = "",
  [ValidateSet("low", "medium", "high")][string]$OwnerParticipation = "medium",
  [string[]]$ApprovedWritePaths = @("Assets"),
  [string]$RuntimeRoot = "",
  [switch]$Apply
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
$resolvedProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
if (-not (Test-Path $resolvedProjectRoot)) { throw "Project root does not exist: $resolvedProjectRoot" }
if ([string]::IsNullOrWhiteSpace($Name)) { $Name = Split-Path -Leaf $resolvedProjectRoot }

$detectArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/detect-project-stage.ps1"), "-Root", $Root, "-ProjectRoot", $resolvedProjectRoot)
if ($RuntimeRoot) { $detectArgs += @("-RuntimeRoot", $RuntimeRoot) }
$detection = & powershell @detectArgs | ConvertFrom-Json

$recommendation = "start"
$recommendedAction = "Treat this as a new MLGS workspace."
if ($detection.state_exists) {
  $recommendation = "status"
  $recommendedAction = "Point MLGS at the existing project state and report status."
} elseif ($detection.is_unity_project) {
  $recommendation = "adopt-unity"
  $recommendedAction = "Initialize state.json for this Unity project."
} elseif ($detection.is_partial_unity_project) {
  $recommendation = "adopt-partial-unity"
  $recommendedAction = "Adopt with an explicit risk noting incomplete Unity project markers."
} elseif (($detection.counts.design_files + $detection.counts.docs_files + $detection.counts.source_files) -gt 0) {
  $recommendation = "adopt-materials"
  $recommendedAction = "Initialize MLGS state for the existing design/code workspace."
}

$applyResult = $null
$codebaseReport = $null
if ($detection.is_unity_project -or $detection.is_partial_unity_project) {
  try { $codebaseReport = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/inspect-codebase.ps1") -Root $Root -ProjectRoot $resolvedProjectRoot | ConvertFrom-Json } catch { $codebaseReport = [pscustomobject]@{ error = $_.Exception.Message } }
}
if ($Apply) {
  if ($detection.state_exists) {
    $repairArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/repair-pointer.ps1"), "-Root", $Root, "-StatePath", $detection.state_path)
    if ($RuntimeRoot) { $repairArgs += @("-RuntimeRoot", $RuntimeRoot) }
    $applyResult = & powershell @repairArgs | ConvertFrom-Json
  } else {
    $mode = if ($detection.is_unity_project -or $detection.is_partial_unity_project) { "external-adopted" } else { "internal" }
    $initArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/init-project-state.ps1"), "-Root", $Root, "-ProjectRoot", $resolvedProjectRoot, "-Name", $Name, "-Mode", $mode, "-UnityVersion", $detection.unity_version, "-OwnerParticipation", $OwnerParticipation)
    if ($ApprovedWritePaths.Count -gt 0) {
      $initArgs += "-ApprovedWritePaths"
      $initArgs += @($ApprovedWritePaths)
    }
    if ($RuntimeRoot) { $initArgs += @("-RuntimeRoot", $RuntimeRoot) }
    $applyResult = & powershell @initArgs | ConvertFrom-Json
  }
}

[pscustomobject]@{
  project_root = $resolvedProjectRoot
  recommendation = $recommendation
  recommended_action = $recommendedAction
  detection = $detection
  codebase = $codebaseReport
  apply_requested = [bool]$Apply
  apply_result = $applyResult
} | ConvertTo-Json -Depth 20
