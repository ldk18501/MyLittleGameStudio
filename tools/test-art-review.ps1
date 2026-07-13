param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$Path,
  [string]$AssetId = ""
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$result = Test-MLGSArtReview -ProjectRoot ([System.IO.Path]::GetFullPath($ProjectRoot)) -Path $Path -AssetId $AssetId
$result | ConvertTo-Json -Depth 10
if (-not $result.passed) { exit 10 }
