param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][ValidateSet("initial-platform-validation", "owner-request", "release-candidate", "release", "routine-development")][string]$Reason,
  [switch]$OwnerRequested,
  [switch]$StartFlow
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$issues = @()
$policyPath = Join-Path $ProjectRoot ".mlgs/build-policy.json"
$policy = $null

if (-not (Test-Path $policyPath)) {
  $issues += "Missing .mlgs/build-policy.json. Initialize or adopt the project with the current MLGS version."
} else {
  try { $policy = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8 | ConvertFrom-Json }
  catch { $issues += "Invalid build policy JSON: $($_.Exception.Message)" }
}

if ($policy) {
  if ([string]$policy.schemaVersion -ne "1.0") { $issues += "Build policy schemaVersion must be 1.0." }
  if ([string]$policy.mode -ne "initial-validation-then-explicit-or-release") { $issues += "Unsupported build policy mode." }
  if ([bool]$policy.automaticDevelopmentBuilds) { $issues += "automaticDevelopmentBuilds must remain false." }
  if (@($policy.allowedAutomaticStages) -notcontains "release-candidate" -or @($policy.allowedAutomaticStages) -notcontains "release") { $issues += "Automatic build stages must remain limited to Release Candidate and Release." }

  switch ($Reason) {
    "routine-development" {
      $issues += "Routine content changes, task verification, regressions, and non-release phase gates never authorize a package build."
    }
    "initial-platform-validation" {
      if (-not $StartFlow) { $issues += "Initial platform validation is allowed only inside the active new-project start flow." }
      if ([string]$policy.initialValidation.status -notin @("pending", "failed")) {
        $issues += "Initial platform validation has already been completed, skipped, or classified as unknown; reuse existing evidence."
      }
    }
    "owner-request" {
      if (-not $OwnerRequested) { $issues += "A development package build requires an explicit request in the owner's current message." }
    }
    "release-candidate" {
      $statePath = Join-Path $ProjectRoot ".mlgs/state.json"
      if (-not (Test-Path $statePath)) { $issues += "Release Candidate build requires project state." }
      else {
        try {
          $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
          if ([string]$state.phase.current -notin @("beta", "release-candidate")) { $issues += "Release Candidate build is allowed only from Beta or Release Candidate." }
        } catch { $issues += "Invalid project state while authorizing Release Candidate build." }
      }
    }
    "release" {
      $statePath = Join-Path $ProjectRoot ".mlgs/state.json"
      if (-not (Test-Path $statePath)) { $issues += "Release build requires project state." }
      else {
        try {
          $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
          if ([string]$state.phase.current -notin @("release-candidate", "release")) { $issues += "Final release build is allowed only from Release Candidate or Release." }
        } catch { $issues += "Invalid project state while authorizing final release build." }
      }
    }
  }
}

$result = [pscustomobject]@{
  allowed = $issues.Count -eq 0
  reason = $Reason
  policy_path = $policyPath
  initial_validation_status = $(if ($policy) { [string]$policy.initialValidation.status } else { "" })
  alternative = "Run compile, focused acceptance checks, editor/play-mode tests, and non-packaging platform preflight."
  issues = @($issues)
}
$result | ConvertTo-Json -Depth 8
if (-not $result.allowed) { exit 18 }
