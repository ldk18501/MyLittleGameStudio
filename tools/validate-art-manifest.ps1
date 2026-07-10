param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [string]$ManifestPath = "production/assets/asset-manifest.json",
  [Parameter(Mandatory = $true)][ValidateSet("vertical-slice", "content-complete", "alpha", "beta", "release-candidate", "release")][string]$RequiredFor,
  [ValidateSet("planned", "prompt-ready", "generated", "selected", "processed", "imported", "referenced", "approved")][string]$MinimumStatus = "approved",
  [switch]$DisallowPlaceholders,
  [string[]]$RequiredKinds = @()
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$result = Test-MLGSArtManifest -ProjectRoot ([System.IO.Path]::GetFullPath($ProjectRoot)) -Path $ManifestPath -RequiredFor $RequiredFor -MinimumStatus $MinimumStatus -DisallowPlaceholders:$DisallowPlaceholders -RequiredKinds $RequiredKinds
$result | ConvertTo-Json -Depth 10
if (-not $result.passed) { exit 4 }

