param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [ValidateSet("vertical-slice", "content-complete", "alpha", "beta", "release-candidate", "release")][string]$RequiredFor = "content-complete",
  [ValidateSet("planned", "specified", "implemented", "integrated", "approved")][string]$MinimumStatus = "integrated",
  [string]$Path = "design/ui/screen-inventory.json"
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$result = Test-MLGSUIScreenContract -ProjectRoot ([System.IO.Path]::GetFullPath($ProjectRoot)) -Path $Path -RequiredFor $RequiredFor -MinimumStatus $MinimumStatus
$result | ConvertTo-Json -Depth 10
if (-not $result.passed) { exit 13 }
