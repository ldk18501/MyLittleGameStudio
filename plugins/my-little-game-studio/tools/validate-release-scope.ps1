param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [string]$ManifestPath = "production/scope/release-scope.json",
  [Parameter(Mandatory = $true)][ValidateSet("vertical-slice", "content-complete", "alpha", "beta", "release-candidate", "release")][string]$RequiredFor,
  [ValidateSet("planned", "specified", "implemented", "integrated", "verified")][string]$MinimumStatus = "integrated",
  [switch]$DisallowPlaceholders,
  [string[]]$RequiredTypes = @()
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$result = Test-MLGSReleaseScope -ProjectRoot ([System.IO.Path]::GetFullPath($ProjectRoot)) -Path $ManifestPath -RequiredFor $RequiredFor -MinimumStatus $MinimumStatus -DisallowPlaceholders:$DisallowPlaceholders -RequiredTypes $RequiredTypes
$result | ConvertTo-Json -Depth 10
if (-not $result.passed) { exit 7 }
