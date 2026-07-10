param(
  [string]$Root = "",
  [string]$ProjectRoot = "",
  [string]$StatePath = "",
  [switch]$ArchiveLegacy,
  [switch]$Force
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")

if ([string]::IsNullOrWhiteSpace($StatePath)) {
  if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { throw "Provide -ProjectRoot or -StatePath." }
  $StatePath = Join-Path ([System.IO.Path]::GetFullPath($ProjectRoot)) ".mlgs/state.yaml"
} else {
  $StatePath = [System.IO.Path]::GetFullPath($StatePath)
}
if (-not (Test-Path $StatePath)) { throw "Legacy state does not exist: $StatePath" }
if ([System.IO.Path]::GetExtension($StatePath).ToLowerInvariant() -ne ".yaml") { throw "Migration input must be a legacy .yaml state file." }

$targetPath = Join-Path (Split-Path -Parent $StatePath) "state.json"
if ((Test-Path $targetPath) -and -not $Force) { throw "Target state already exists: $targetPath" }

$state = Import-MLGSState -Path $StatePath
$state.updated = (Get-Date).ToString("o")
$validation = Test-MLGSState -State $state
if (-not $validation.valid) { throw ("Legacy state cannot be migrated: " + ($validation.errors -join "; ")) }
Write-MLGSJsonAtomic -Path $targetPath -Value $state

$archivedPath = ""
if ($ArchiveLegacy) {
  $archivedPath = Join-Path (Split-Path -Parent $StatePath) "state.legacy.yaml"
  Move-Item -LiteralPath $StatePath -Destination $archivedPath -Force
}

[pscustomobject]@{
  migrated = $true
  source_path = $StatePath
  state_path = $targetPath
  archived_path = $archivedPath
} | ConvertTo-Json -Depth 5

