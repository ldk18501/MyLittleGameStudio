param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][ValidateSet("initial-platform-validation", "owner-request", "release-candidate", "release")][string]$Kind,
  [Parameter(Mandatory = $true)][ValidateSet("start-flow", "owner", "release-flow")][string]$RequestedBy,
  [Parameter(Mandatory = $true)][string]$TargetPlatform,
  [Parameter(Mandatory = $true)][ValidateSet("passed", "failed", "blocked")][string]$Result,
  [string[]]$Evidence = @()
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$policyPath = Join-Path $ProjectRoot ".mlgs/build-policy.json"
if (-not (Test-Path $policyPath)) { throw "Missing build policy: $policyPath" }
$policy = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8 | ConvertFrom-Json
$now = (Get-Date).ToString("o")
$cleanEvidence = @($Evidence | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)

if ($Kind -eq "initial-platform-validation" -and $RequestedBy -ne "start-flow") { throw "Initial platform validation must be requested by start-flow." }
if ($Kind -eq "owner-request" -and $RequestedBy -ne "owner") { throw "Owner-request builds must be requested by owner." }
if ($Kind -in @("release-candidate", "release") -and $RequestedBy -ne "release-flow") { throw "Release builds must be requested by release-flow." }

if ($Kind -eq "initial-platform-validation") {
  $policy.initialValidation.status = $(if ($Result -eq "passed") { "passed" } elseif ($Result -eq "failed") { "failed" } else { "pending" })
  $policy.initialValidation.targetPlatform = $TargetPlatform
  $policy.initialValidation.attempts = [int]$policy.initialValidation.attempts + 1
  $policy.initialValidation.completedAt = $(if ($Result -eq "passed") { $now } else { "" })
  $policy.initialValidation.evidence = $cleanEvidence
}
$policy.history += [pscustomobject][ordered]@{
  kind = $Kind
  requestedBy = $RequestedBy
  targetPlatform = $TargetPlatform
  result = $Result
  at = $now
  evidence = $cleanEvidence
}
$policy.updated = $now
Write-MLGSJsonAtomic -Path $policyPath -Value $policy

[pscustomobject]@{
  recorded = $true
  policy_path = $policyPath
  kind = $Kind
  result = $Result
  initial_validation_status = [string]$policy.initialValidation.status
  history_count = @($policy.history).Count
} | ConvertTo-Json -Depth 6
