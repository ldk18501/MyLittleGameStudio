param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [string]$ProfilePath = "design/code/codebase-profile.json",
  [string]$ModuleMapPath = "design/code/module-map.json"
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$issues = @(); $warnings = @()
try { $profileFull = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $ProfilePath } catch { $issues += $_.Exception.Message }
try { $moduleFull = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $ModuleMapPath } catch { $issues += $_.Exception.Message }
if ($issues.Count -eq 0 -and -not (Test-Path $profileFull)) { $issues += "Missing codebase profile: $ProfilePath" }
if ($issues.Count -eq 0) { try { $profile = Get-Content -LiteralPath $profileFull -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $issues += "Invalid codebase profile JSON: $($_.Exception.Message)" } }
if ($issues.Count -eq 0) {
  if ([string]$profile.schemaVersion -ne "1.0") { $issues += "Codebase profile schemaVersion must be 1.0." }
  $expectedIntensity = @{ "new-project" = "lightweight"; "small-existing" = "standard"; "large-framework" = "deep" }[[string]$profile.projectKind]
  if ([string]$profile.intensity -ne $expectedIntensity) { $issues += "Project kind '$($profile.projectKind)' must use '$expectedIntensity' intensity." }
  if ([string]$profile.classification.source -eq "owner-override" -and [string]::IsNullOrWhiteSpace([string]$profile.classification.overrideReason)) { $issues += "Classification override requires a reason." }
  if ([string]$profile.architectVerdict -ne "pass" -or [string]$profile.status -ne "approved") { $issues += "Codebase profile requires approved Unity Architect pass." }
  if (@($profile.blockers).Count -gt 0) { $issues += "Codebase profile still has blockers: $(@($profile.blockers) -join '; ')" }
  if (@($profile.exemplars).Count -lt [int]$profile.policy.minimumExemplars) { $issues += "Codebase profile needs at least $($profile.policy.minimumExemplars) approved exemplars." }
  foreach ($exemplar in @($profile.exemplars)) {
    $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$exemplar.path) -Label "Codebase exemplar"
    if ($pathIssue) { $issues += $pathIssue; continue }
    $full = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ([string]$exemplar.path)
    $hash = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    if ($hash -ne [string]$exemplar.sha256) { $issues += "Codebase exemplar is stale: $($exemplar.path)" }
  }
  if ([string]$profile.policy.structuralAnalysisRequirement -eq "required") {
    if ([string]$profile.structuralAnalysis.provider -eq "none" -or [string]$profile.structuralAnalysis.status -ne "pass") { $issues += "Deep projects require passing CodeGraph, Roslyn, or manual structural analysis." }
    if (@($profile.structuralAnalysis.queries).Count -eq 0 -or @($profile.structuralAnalysis.evidence).Count -eq 0) { $issues += "Deep structural analysis needs queries and project-relative evidence." }
  } elseif ([string]$profile.policy.structuralAnalysisRequirement -eq "recommended" -and [string]$profile.structuralAnalysis.status -ne "pass") {
    $warnings += "Structural analysis is recommended for this small existing project but has not passed."
  }
  foreach ($relative in @($profile.structuralAnalysis.evidence)) {
    $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$relative) -Label "Structural analysis evidence"
    if ($pathIssue) { $issues += $pathIssue }
  }

  if ([bool]$profile.policy.requireModuleMap) {
    if (-not (Test-Path $moduleFull)) { $issues += "Project intensity requires a module map: $ModuleMapPath" }
    else {
      try { $moduleMap = Get-Content -LiteralPath $moduleFull -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $issues += "Invalid module map JSON: $($_.Exception.Message)" }
      if ($null -ne $moduleMap) {
        if ([string]$moduleMap.projectKind -ne [string]$profile.projectKind) { $issues += "Module map projectKind does not match codebase profile." }
        if ([string]$moduleMap.architectVerdict -ne "pass" -or [string]$moduleMap.status -ne "approved") { $issues += "Module map requires approved Unity Architect pass." }
        if (@($moduleMap.modules).Count -eq 0) { $issues += "Required module map has no modules." }
        $moduleIds = @{}
        foreach ($module in @($moduleMap.modules)) {
          if ($moduleIds.ContainsKey([string]$module.id)) { $issues += "Duplicate module id: $($module.id)" } else { $moduleIds[[string]$module.id] = $true }
          if ([string]$module.state -ne "planned") {
            $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$module.root) -Label "Module root '$($module.id)'"
            if ($pathIssue) { $issues += $pathIssue }
          }
          if (@($module.responsibilities).Count -eq 0) { $issues += "Module '$($module.id)' has no recorded responsibilities." }
        }
        foreach ($module in @($moduleMap.modules)) { foreach ($dependency in @($module.dependencies)) { if (-not $moduleIds.ContainsKey([string]$dependency)) { $issues += "Module '$($module.id)' references unknown dependency '$dependency'." } } }
        if (@($moduleMap.blockers).Count -gt 0) { $issues += "Module map still has blockers: $(@($moduleMap.blockers) -join '; ')" }
      }
    }
  }
}
$result = [pscustomobject]@{ passed = $issues.Count -eq 0; projectKind = [string]$profile.projectKind; intensity = [string]$profile.intensity; issues = @($issues); warnings = @($warnings); profilePath = $profileFull; moduleMapPath = $moduleFull }
$result | ConvertTo-Json -Depth 12
if (-not $result.passed) { exit 19 }
