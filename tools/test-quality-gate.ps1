param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][ValidateSet("vertical-slice", "content-complete", "alpha", "beta", "release-candidate", "release")][string]$Stage
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$catalog = Get-Content -LiteralPath (Join-Path $Root "workflow/catalog.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$definition = $null
foreach ($gateProperty in $catalog.gates.PSObject.Properties) {
  $gate = $gateProperty.Value
  if (($gate.PSObject.Properties.Name -contains "qualityReport") -and [string]$gate.qualityReport.stage -eq $Stage) {
    $definition = $gate.qualityReport
    break
  }
}
if ($null -eq $definition) { throw "No quality gate definition found for stage: $Stage" }
$result = Test-MLGSQualityReport -ProjectRoot ([System.IO.Path]::GetFullPath($ProjectRoot)) -Path ([string]$definition.path) -Stage $Stage -RequiredChecks @($definition.requiredChecks)
$result | ConvertTo-Json -Depth 10
if (-not $result.passed) { exit 5 }

