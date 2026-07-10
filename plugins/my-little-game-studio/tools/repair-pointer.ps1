param(
  [string]$Root = "",
  [string]$ProjectRoot = "",
  [string]$StatePath = "",
  [string]$RuntimeRoot = "",
  [switch]$Clear,
  [switch]$ClearLegacy
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$RuntimeRoot = Get-MLGSRuntimeRoot -Root $Root -RuntimeRoot $RuntimeRoot
$pointerPath = Join-Path $RuntimeRoot "current-project.json"
$legacyPointerPath = Join-Path $Root "studio/current-project.local.yaml"

if ($Clear) {
  if (Test-Path $pointerPath) { Remove-Item -LiteralPath $pointerPath -Force }
  if ($ClearLegacy -and (Test-Path $legacyPointerPath)) { Remove-Item -LiteralPath $legacyPointerPath -Force }
  [pscustomobject]@{ status = "cleared"; pointer_path = $pointerPath; legacy_cleared = [bool]$ClearLegacy } | ConvertTo-Json
  exit 0
}

if ([string]::IsNullOrWhiteSpace($StatePath)) {
  if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { throw "Provide -ProjectRoot, -StatePath, or -Clear." }
  $resolvedProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
  $resolvedStatePath = Get-MLGSStateCandidate -ProjectRoot $resolvedProjectRoot
} else {
  $resolvedStatePath = [System.IO.Path]::GetFullPath($StatePath)
  $resolvedProjectRoot = if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    Split-Path -Parent (Split-Path -Parent $resolvedStatePath)
  } else {
    [System.IO.Path]::GetFullPath($ProjectRoot)
  }
}

if (-not (Test-Path $resolvedProjectRoot)) { throw "Project root does not exist: $resolvedProjectRoot" }
if (-not (Test-Path $resolvedStatePath)) { throw "Project state does not exist: $resolvedStatePath" }
if ([System.IO.Path]::GetFullPath($resolvedStatePath) -eq [System.IO.Path]::GetFullPath((Join-Path $Root "studio/state.json"))) {
  throw "Refusing to point at the root template state."
}

$state = Import-MLGSState -Path $resolvedStatePath
$validation = Test-MLGSState -State $state
if (-not $validation.valid) { throw ("Refusing invalid project state: " + ($validation.errors -join "; ")) }

$pointer = [ordered]@{
  schemaVersion = "1.0"
  updated = (Get-Date).ToString("o")
  statePath = $resolvedStatePath.Replace("\", "/")
  projectRoot = $resolvedProjectRoot.Replace("\", "/")
}
Write-MLGSJsonAtomic -Path $pointerPath -Value $pointer

[pscustomobject]@{
  status = "repaired"
  pointer_path = $pointerPath
  state_path = $resolvedStatePath
  project_root = $resolvedProjectRoot
  state_format = $(if ($resolvedStatePath.EndsWith(".json")) { "json" } else { "legacy-yaml" })
} | ConvertTo-Json -Depth 5

