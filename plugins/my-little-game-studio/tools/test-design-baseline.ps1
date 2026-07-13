param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [string]$Path = "design/baseline.json",
  [string]$OutputPath = "production/quality/design-change-impact.json"
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$result = Test-MLGSDesignBaseline -ProjectRoot ([System.IO.Path]::GetFullPath($ProjectRoot)) -Path $Path -OutputPath $OutputPath
$result | ConvertTo-Json -Depth 10
if (-not $result.passed) { exit 14 }
