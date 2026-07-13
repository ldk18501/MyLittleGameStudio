param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$Path
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$issues = @()
try { $packagePath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Path } catch { $issues += $_.Exception.Message; $packagePath = $Path }
if ($issues.Count -eq 0 -and -not (Test-Path $packagePath)) { $issues += "Work package does not exist: $Path" }
if ($issues.Count -eq 0) {
  try { $package = Get-Content -LiteralPath $packagePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $issues += "Invalid work package JSON: $($_.Exception.Message)" }
}
if ($issues.Count -eq 0) {
  foreach ($name in @("schemaVersion", "id", "objective", "strategy", "executionPlanPath", "status", "successCriteria", "budget", "attempts", "declaredVerdict", "objectiveVerdict", "gaps", "blockers", "updated")) {
    if (@($package.PSObject.Properties.Name) -notcontains $name) { $issues += "Missing work package property: $name" }
  }
}
if ($issues.Count -eq 0) {
  if ([string]$package.schemaVersion -ne "1.0") { $issues += "Work package schemaVersion must be 1.0." }
  if ([int]$package.budget.currentAttempt -gt [int]$package.budget.maxAttempts) { $issues += "currentAttempt exceeds maxAttempts." }
  if (@($package.attempts).Count -gt [int]$package.budget.maxAttempts) { $issues += "Attempt history exceeds maxAttempts." }
  foreach ($criterion in @($package.successCriteria)) {
    if (@($criterion.evidence).Count -eq 0) { $issues += "$($criterion.id): evidence is empty." }
    foreach ($pathValue in @($criterion.evidence)) {
      $issue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$pathValue) -Label "$($criterion.id) evidence"
      if ($issue) { $issues += $issue }
    }
    if ([string]$criterion.objectiveVerdict -ne "pass") { $issues += "$($criterion.id): objective verdict is not pass." }
    if (@($criterion.objectiveChecks).Count -eq 0) { $issues += "$($criterion.id): objective checks are empty." }
    foreach ($check in @($criterion.objectiveChecks)) {
      if ([string]$check.status -ne "pass") { $issues += "$($criterion.id)/$($check.id): objective check is not pass." }
    }
  }
  if ([string]$package.strategy -ne "direct") {
    if ([string]::IsNullOrWhiteSpace([string]$package.executionPlanPath)) { $issues += "Non-direct strategy requires executionPlanPath." }
    else { $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$package.executionPlanPath) -Label "Execution strategy"; if ($pathIssue) { $issues += $pathIssue } }
  }

  if ([string]$package.status -eq "done") {
    if ([string]$package.declaredVerdict -ne "pass" -or [string]$package.objectiveVerdict -ne "pass") { $issues += "Done requires both declaredVerdict and objectiveVerdict to be pass." }
    if (@($package.gaps).Count -gt 0 -or @($package.blockers).Count -gt 0) { $issues += "Done work package still has gaps or blockers." }
  }
  elseif ([string]$package.declaredVerdict -eq "pass") { $issues += "declaredVerdict pass is only valid when status is done." }
}
$result = [pscustomobject]@{ passed = $issues.Count -eq 0; path = $packagePath; issues = @($issues) }
$result | ConvertTo-Json -Depth 10
if (-not $result.passed) { exit 9 }
