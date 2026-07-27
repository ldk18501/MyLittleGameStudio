param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$ContractPath,
  [ValidateSet("planned", "specified", "source-approved", "parts-validated", "unity-integrated", "approved")][string]$MinimumStatus = "specified",
  [string]$AssetId = ""
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")

$result = Test-MLGSCharacterAnimationContract `
  -ProjectRoot ([System.IO.Path]::GetFullPath($ProjectRoot)) `
  -Path $ContractPath `
  -MinimumStatus $MinimumStatus `
  -AssetId $AssetId
$result | Select-Object -Property * -ExcludeProperty contract | ConvertTo-Json -Depth 12
if (-not $result.passed) { exit 28 }

