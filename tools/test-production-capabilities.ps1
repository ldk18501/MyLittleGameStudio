param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [ValidateSet("vertical-slice", "content-complete", "alpha", "beta", "release-candidate", "release")][string]$RequiredFor = "vertical-slice",
  [string]$Path = "production/capabilities/capability-manifest.json",
  [string[]]$RequiredCapabilityKinds = @()
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$result = Test-MLGSProductionCapabilities -ProjectRoot ([System.IO.Path]::GetFullPath($ProjectRoot)) -Path $Path -RequiredFor $RequiredFor -RequiredCapabilityKinds $RequiredCapabilityKinds
$result | ConvertTo-Json -Depth 10
if (-not $result.passed) { exit 15 }
