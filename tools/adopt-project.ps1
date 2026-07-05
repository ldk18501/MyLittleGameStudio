param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)]
  [string]$ProjectRoot,
  [string]$Name = "",
  [ValidateSet("low", "medium", "high")]
  [string]$OwnerParticipation = "medium",
  [string[]]$ApprovedWritePaths = @("Assets"),
  [switch]$Apply
)

if ([string]::IsNullOrWhiteSpace($Root)) {
  $scriptPath = $PSCommandPath
  if ([string]::IsNullOrWhiteSpace($scriptPath)) {
    $scriptPath = $MyInvocation.MyCommand.Path
  }
  if ([string]::IsNullOrWhiteSpace($scriptPath)) {
    $Root = (Get-Location).Path
  } else {
    $Root = Split-Path -Parent (Split-Path -Parent $scriptPath)
  }
}

function Resolve-ExistingPath {
  param([string]$Base, [string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path)) {
    return ""
  }

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }

  return [System.IO.Path]::GetFullPath((Join-Path $Base $Path))
}

function Get-DefaultProjectName {
  param([string]$Path)

  $leaf = Split-Path -Leaf $Path
  if ([string]::IsNullOrWhiteSpace($leaf)) {
    return "Unity Game"
  }

  return $leaf
}

function Get-NextCommand {
  param($Detection)

  if (-not $Detection.state_exists) {
    return "/mlgs 接管这个项目"
  }
  if (-not $Detection.artifacts.concept) {
    return "/mlgs 头脑风暴并创建概念包"
  }
  if (-not $Detection.artifacts.design_plan) {
    return "/mlgs 规划系统和任务"
  }
  if (-not $Detection.artifacts.prototype) {
    return "/mlgs 验证核心原型"
  }
  if (-not $Detection.artifacts.tests) {
    return "/mlgs 验证当前任务"
  }

  return "/mlgs 看看当前状态"
}

$resolvedProjectRoot = Resolve-ExistingPath $Root $ProjectRoot
if (-not (Test-Path $resolvedProjectRoot)) {
  Write-Error "Project root does not exist: $resolvedProjectRoot"
  exit 1
}

$detectPath = Join-Path $Root "tools/detect-project-stage.ps1"
$initPath = Join-Path $Root "tools/init-project-state.ps1"
$repairPath = Join-Path $Root "tools/repair-pointer.ps1"

if (-not (Test-Path $detectPath)) {
  Write-Error "Missing detect script: $detectPath"
  exit 1
}

$detection = & powershell -NoProfile -ExecutionPolicy Bypass -File $detectPath -Root $Root -ProjectRoot $resolvedProjectRoot | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($Name)) {
  $Name = Get-DefaultProjectName $resolvedProjectRoot
}

$recommendation = "start"
$recommendedAction = "Run /mlgs 开始; this folder does not look like a Unity or existing work project."
if ($detection.state_exists) {
  $recommendation = "repair-pointer"
  $recommendedAction = "Point MLGS at the existing .mlgs/state.yaml, then run /mlgs 看看当前状态."
} elseif ($detection.is_unity_project) {
  $recommendation = "adopt-unity"
  $recommendedAction = "Initialize .mlgs/state.yaml as an external Unity project."
} elseif ($detection.counts.design_files -gt 0 -or $detection.counts.docs_files -gt 0 -or $detection.counts.source_files -gt 0) {
  $recommendation = "adopt-materials"
  $recommendedAction = "Treat this as existing materials and create an MLGS state before planning."
}

$applyResult = $null
if ($Apply) {
  if ($detection.state_exists) {
    $applyResult = & powershell -NoProfile -ExecutionPolicy Bypass -File $repairPath -Root $Root -StatePath $detection.state_path | ConvertFrom-Json
  } elseif ($detection.is_unity_project) {
    $applyResult = & powershell -NoProfile -ExecutionPolicy Bypass -File $initPath -Root $Root -ProjectRoot $resolvedProjectRoot -Name $Name -Mode external-adopted -UnityVersion $detection.unity_version -ApprovedWritePaths $ApprovedWritePaths -OwnerParticipation $OwnerParticipation | ConvertFrom-Json
  } else {
    $applyResult = & powershell -NoProfile -ExecutionPolicy Bypass -File $initPath -Root $Root -ProjectRoot $resolvedProjectRoot -Name $Name -Mode internal -ApprovedWritePaths $ApprovedWritePaths -OwnerParticipation $OwnerParticipation | ConvertFrom-Json
  }
}

[pscustomobject]@{
  project_root = $resolvedProjectRoot
  project_name = $Name
  owner_participation = $OwnerParticipation
  apply = [bool]$Apply
  detection = $detection
  recommendation = $recommendation
  recommended_action = $recommendedAction
  next_command = $(Get-NextCommand $detection)
  next_options = @(
    [pscustomobject]@{ key = "A"; command = "/mlgs 接管这个项目"; label = "Adopt now"; description = "Create or repair MLGS state for this project." },
    [pscustomobject]@{ key = "B"; command = "/mlgs 看看当前状态"; label = "Inspect status"; description = "Use the current or newly attached project state." },
    [pscustomobject]@{ key = "C"; command = "/mlgs 头脑风暴并创建概念包"; label = "Shape concept"; description = "Fill missing concept direction." },
    [pscustomobject]@{ key = "D"; command = "/mlgs 规划系统和任务"; label = "Plan systems"; description = "Create systems, tech plan, and tasks." }
  )
  apply_result = $applyResult
} | ConvertTo-Json -Depth 12


