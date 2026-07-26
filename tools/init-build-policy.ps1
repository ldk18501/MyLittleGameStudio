param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [ValidateSet("pending", "passed", "failed", "skipped", "unknown")][string]$InitialStatus = "unknown",
  [switch]$Force
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$mlgsPath = Join-Path $ProjectRoot ".mlgs"
if (-not (Test-Path $mlgsPath)) { throw "Project has no .mlgs directory: $ProjectRoot" }
$policyPath = Join-Path $mlgsPath "build-policy.json"
$schemaPath = Join-Path $mlgsPath "build-policy.schema.json"

Copy-Item -LiteralPath (Join-Path $Root "studio/build-policy.schema.json") -Destination $schemaPath -Force
if ((Test-Path $policyPath) -and -not $Force) {
  [pscustomobject]@{ initialized = $false; existing = $true; policy_path = $policyPath } | ConvertTo-Json -Depth 4
  exit 0
}
$policy = Get-Content -LiteralPath (Join-Path $Root "templates/build-policy.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$policy.initialValidation.status = $InitialStatus
$policy.updated = (Get-Date).ToString("o")
Write-MLGSJsonAtomic -Path $policyPath -Value $policy
[pscustomobject]@{ initialized = $true; existing = $false; initial_status = $InitialStatus; policy_path = $policyPath } | ConvertTo-Json -Depth 4
