param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [string]$Path = "design/framework-adoption.json"
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$issues = @()
try { $contractPath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Path } catch { $issues += $_.Exception.Message }
if ($issues.Count -eq 0 -and -not (Test-Path $contractPath)) { $issues += "Missing framework adoption contract: $Path" }
if ($issues.Count -eq 0) {
  $projectKind = ""
  $profilePath = Join-Path $ProjectRoot "design/code/codebase-profile.json"
  if (Test-Path $profilePath) { try { $projectKind = [string](Get-Content $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json).projectKind } catch { } }
  try { $contract = Get-Content -LiteralPath $contractPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $issues += "Invalid framework adoption JSON: $($_.Exception.Message)" }
}
if ($issues.Count -eq 0) {
  if ([string]$contract.schemaVersion -ne "1.0") { $issues += "Framework adoption schemaVersion must be 1.0." }
  if (-not [bool]$contract.reconnaissance.completed) { $issues += "Unity architecture reconnaissance is not complete." }
  foreach ($relative in @($contract.reconnaissance.evidence)) {
    $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$relative) -Label "Framework reconnaissance evidence"
    if ($pathIssue) { $issues += $pathIssue }
  }
  if ([string]$contract.projectMode -eq "existing-framework" -and @($contract.frameworkSignals).Count -eq 0) {
    $issues += "Existing projects must record framework signals before implementation."
  }
  foreach ($signal in @($contract.frameworkSignals)) {
    if ([string]$signal.decision -ne "not-applicable") {
      $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$signal.path) -Label "Framework signal '$($signal.name)'"
      if ($pathIssue) { $issues += $pathIssue }
    }
  }
  foreach ($name in @("compositionRoot", "moduleBoundary", "lifecycle", "events", "configuration", "persistence", "uiPresentation")) {
    $point = $contract.selectedIntegration.$name
    if ([string]$point.decision -ne "not-applicable") {
      if ([string]::IsNullOrWhiteSpace([string]$point.path)) { $issues += "Framework integration point '$name' has no path." }
      elseif ($projectKind -eq "new-project" -and [string]$point.decision -eq "create") {
        try { Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ([string]$point.path) | Out-Null } catch { $issues += "Planned framework integration point '$name' is outside the project: $($point.path)" }
      }
      else {
        $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$point.path) -Label "Framework integration point '$name'"
        if ($pathIssue) { $issues += $pathIssue }
      }
    }
  }
  if ($projectKind -eq "new-project" -and [string]$contract.projectMode -ne "new-foundation") { $issues += "New-project profile must use a new-foundation framework contract." }
  foreach ($relative in @($contract.implementationRoots)) {
    $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$relative) -Label "Framework implementation root"
    if ($pathIssue) { $issues += $pathIssue }
  }
  $recordedAsmdefs = @{}
  foreach ($relative in @($contract.reconnaissance.asmdefPaths)) {
    $recordedAsmdefs[[string]$relative] = $true
    $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$relative) -Label "Recorded asmdef"
    if ($pathIssue) { $issues += $pathIssue }
  }
  foreach ($relative in @($contract.implementationRoots)) {
    try { $implementationRoot = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ([string]$relative) } catch { continue }
    if (-not (Test-Path $implementationRoot) -or -not (Get-Item -LiteralPath $implementationRoot).PSIsContainer) { continue }
    foreach ($asmdef in @(Get-ChildItem -LiteralPath $implementationRoot -Recurse -File -Filter "*.asmdef" -ErrorAction SilentlyContinue)) {
      $asmdefRelative = $asmdef.FullName.Substring($ProjectRoot.Length).TrimStart('\', '/').Replace("\", "/")
      if ($asmdefRelative -match "(?i)(^|/)(Plugins|ThirdParty|External|Samples?)(/|$)") { continue }
      if (-not $recordedAsmdefs.ContainsKey($asmdefRelative)) { $issues += "Project asmdef was not recorded during framework reconnaissance: $asmdefRelative" }
    }
  }
  if ([string]$contract.architectVerdict -ne "pass" -or [string]$contract.status -ne "approved") { $issues += "Framework adoption requires approved Unity Architect pass." }
  if (@($contract.blockers).Count -gt 0) { $issues += "Framework adoption still has blockers: $(@($contract.blockers) -join '; ')" }
}
$result = [pscustomobject]@{ passed = $issues.Count -eq 0; path = $contractPath; issues = @($issues) }
$result | ConvertTo-Json -Depth 10
if (-not $result.passed) { exit 17 }
