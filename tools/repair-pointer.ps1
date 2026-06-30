param(
  [string]$Root = "",
  [string]$ProjectRoot = "",
  [string]$StatePath = "",
  [switch]$Clear
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

$pointerPath = Join-Path $Root "studio/current-project.local.yaml"

if ($Clear) {
  if (Test-Path $pointerPath) {
    Remove-Item -LiteralPath $pointerPath
  }

  [pscustomobject]@{
    action = "cleared"
    pointer_path = $pointerPath
    state_path = ""
    project_root = ""
  } | ConvertTo-Json -Depth 5
  exit 0
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot) -and [string]::IsNullOrWhiteSpace($StatePath)) {
  Write-Error "Provide -ProjectRoot, -StatePath, or -Clear."
  exit 1
}

$resolvedStatePath = ""
$resolvedProjectRoot = ""

if (-not [string]::IsNullOrWhiteSpace($StatePath)) {
  $resolvedStatePath = Resolve-ExistingPath $Root $StatePath
  $resolvedProjectRoot = Split-Path -Parent (Split-Path -Parent $resolvedStatePath)
} else {
  $resolvedProjectRoot = Resolve-ExistingPath $Root $ProjectRoot
  $resolvedStatePath = Join-Path $resolvedProjectRoot ".mlgs/state.yaml"
}

if (-not (Test-Path $resolvedProjectRoot)) {
  Write-Error "Project root does not exist: $resolvedProjectRoot"
  exit 1
}

if (-not (Test-Path $resolvedStatePath)) {
  Write-Error "State file does not exist: $resolvedStatePath"
  exit 1
}

$state = Get-Content -Path $resolvedStatePath -Raw -Encoding UTF8
if ($state -match "kind:\s*template") {
  Write-Error "Refusing to point at the root template state. Choose a project .mlgs/state.yaml instead."
  exit 1
}

if ($state -notmatch "active_project:" -or $state -notmatch "phase:" -or $state -notmatch "next_action:") {
  Write-Error "State file is missing required MLGS sections: $resolvedStatePath"
  exit 1
}

$studioDir = Join-Path $Root "studio"
if (-not (Test-Path $studioDir)) {
  New-Item -ItemType Directory -Path $studioDir | Out-Null
}

$now = (Get-Date).ToString("o")
$pointer = @"
version: 0.1
updated: "$now"
state_path: "$($resolvedStatePath.Replace("\", "/"))"
project_root: "$($resolvedProjectRoot.Replace("\", "/"))"
"@

Set-Content -Path $pointerPath -Value $pointer -Encoding UTF8

[pscustomobject]@{
  action = "repaired"
  pointer_path = $pointerPath
  state_path = $resolvedStatePath
  project_root = $resolvedProjectRoot
} | ConvertTo-Json -Depth 5

