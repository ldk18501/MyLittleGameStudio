param(
  [string]$Root = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)),
  [string]$ProjectRoot = "",
  [string]$StatePath = "",
  [switch]$AllowTemplate
)

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

function Read-PointerValue {
  param([string]$Content, [string]$Key)

  $match = [regex]::Match($Content, "(?m)^\s*$([regex]::Escape($Key))\s*:\s*[""']?([^""'\r\n]+)[""']?\s*$")
  if ($match.Success) {
    return $match.Groups[1].Value.Trim()
  }

  return ""
}

$templatePath = Join-Path $Root "studio/state.yaml"
$pointerPath = Join-Path $Root "studio/current-project.local.yaml"
$mode = "missing"
$resolvedStatePath = ""
$resolvedProjectRoot = ""

if (-not [string]::IsNullOrWhiteSpace($StatePath)) {
  $resolvedStatePath = Resolve-ExistingPath $Root $StatePath
  $resolvedProjectRoot = Split-Path -Parent (Split-Path -Parent $resolvedStatePath)
  $mode = "explicit-state"
} elseif (-not [string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $resolvedProjectRoot = Resolve-ExistingPath $Root $ProjectRoot
  $resolvedStatePath = Join-Path $resolvedProjectRoot ".mlgs/state.yaml"
  $mode = "explicit-project"
} elseif (Test-Path $pointerPath) {
  $pointer = Get-Content -Path $pointerPath -Raw -Encoding UTF8
  $pointerState = Read-PointerValue $pointer "state_path"
  $pointerRoot = Read-PointerValue $pointer "project_root"
  $resolvedStatePath = Resolve-ExistingPath $Root $pointerState
  $resolvedProjectRoot = Resolve-ExistingPath $Root $pointerRoot
  if ([string]::IsNullOrWhiteSpace($resolvedProjectRoot) -and -not [string]::IsNullOrWhiteSpace($resolvedStatePath)) {
    $resolvedProjectRoot = Split-Path -Parent (Split-Path -Parent $resolvedStatePath)
  }
  $mode = "local-pointer"
} elseif ($AllowTemplate -and (Test-Path $templatePath)) {
  $resolvedStatePath = $templatePath
  $resolvedProjectRoot = $Root
  $mode = "template"
}

$exists = (-not [string]::IsNullOrWhiteSpace($resolvedStatePath)) -and (Test-Path $resolvedStatePath)

[pscustomobject]@{
  mode = $mode
  exists = $exists
  state_path = $resolvedStatePath
  project_root = $resolvedProjectRoot
  template_path = $templatePath
  pointer_path = $pointerPath
} | ConvertTo-Json -Depth 5
