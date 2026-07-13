param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][ValidateSet("vertical-slice", "content-complete", "alpha", "beta", "release-candidate", "release")][string]$Stage
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$catalog = Get-Content -LiteralPath (Join-Path $Root "workflow/catalog.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$gateName = ""
foreach ($gateProperty in $catalog.gates.PSObject.Properties) {
  $gate = $gateProperty.Value
  if (($gate.PSObject.Properties.Name -contains "qualityReport") -and [string]$gate.qualityReport.stage -eq $Stage) {
    $gateName = $gateProperty.Name
    break
  }
}
if ([string]::IsNullOrWhiteSpace($gateName)) { throw "No quality gate definition found for stage: $Stage" }
$evaluation = Get-MLGSGateEvaluation -Root $Root -ProjectRoot ([System.IO.Path]::GetFullPath($ProjectRoot))
$result = $evaluation.gates.$gateName
$result | ConvertTo-Json -Depth 10
if (-not $result.passed) { exit 5 }
