param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [string]$Path = "design/art/visual-scene-contract.json",
  [ValidateSet("vertical-slice", "content-complete", "alpha", "beta", "release-candidate", "release")][string]$RequiredFor = "vertical-slice",
  [ValidateSet("specified", "implemented", "approved")][string]$MinimumStatus = "approved"
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$issues = @()

try { $contractPath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Path } catch {
  $result = [pscustomobject]@{ passed = $false; path = $Path; requiredFor = $RequiredFor; issues = @($_.Exception.Message) }
  $result | ConvertTo-Json -Depth 10; exit 16
}
if (-not (Test-Path $contractPath)) {
  $result = [pscustomobject]@{ passed = $false; path = $contractPath; requiredFor = $RequiredFor; issues = @("Missing visual scene contract: $Path") }
  $result | ConvertTo-Json -Depth 10; exit 16
}
try { $contract = Get-Content -LiteralPath $contractPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
  $result = [pscustomobject]@{ passed = $false; path = $contractPath; requiredFor = $RequiredFor; issues = @("Invalid visual scene contract JSON: $($_.Exception.Message)") }
  $result | ConvertTo-Json -Depth 10; exit 16
}
if ([string]$contract.schemaVersion -ne "1.1") { $issues += "Visual scene contract schemaVersion must be 1.1." }
if ([string]::IsNullOrWhiteSpace([string]$contract.updated)) { $issues += "Visual scene contract updated timestamp is required." }
$visualTargetResult = Test-MLGSVisualTarget -ProjectRoot $ProjectRoot -Path "design/art/visual-target.json"
if (-not $visualTargetResult.passed) { $issues += @($visualTargetResult.issues) }
$approvedTargetIds = @{}
foreach ($targetId in @($visualTargetResult.approvedIds)) { $approvedTargetIds[[string]$targetId] = $true }

$statusRank = @{ planned = 0; specified = 1; implemented = 2; approved = 3; blocked = -1 }
$minimumRank = $statusRank[$MinimumStatus]
$requiredStageRank = Get-MLGSStageRank -Stage $RequiredFor
$requiredScenes = @($contract.scenes | Where-Object { (Get-MLGSStageRank -Stage ([string]$_.requiredFor)) -le $requiredStageRank })
if ($requiredScenes.Count -eq 0) { $issues += "No visual scene is scoped for $RequiredFor." }
$ids = @{}
$metricNames = @("targetMatch", "composition", "spatialLayout", "depthLighting", "materialLanguage", "detailDensity", "diegeticIntegration", "readability")

foreach ($scene in $requiredScenes) {
  $id = [string]$scene.id
  if ([string]::IsNullOrWhiteSpace($id)) { $issues += "Visual scene without id."; continue }
  if ($ids.ContainsKey($id)) { $issues += "Duplicate visual scene id: $id" } else { $ids[$id] = $true }
  $rank = if ($statusRank.ContainsKey([string]$scene.status)) { $statusRank[[string]$scene.status] } else { -1 }
  if ($rank -lt $minimumRank) { $issues += "Visual scene '$id' status must be at least $MinimumStatus." }
  if (@($scene.visualTargetIds).Count -eq 0) { $issues += "Visual scene '$id' needs visualTargetIds." }
  foreach ($targetId in @($scene.visualTargetIds)) {
    if (-not $approvedTargetIds.ContainsKey([string]$targetId)) { $issues += "Visual scene '$id' references a missing or unapproved visual target: $targetId" }
  }
  foreach ($target in @($scene.targetImages)) {
    $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$target) -Label "Visual scene '$id' target image"
    if ($pathIssue) { $issues += $pathIssue }
  }
  $requiredLayers = @($scene.layers | Where-Object { [bool]$_.required })
  if ($requiredLayers.Count -eq 0) { $issues += "Visual scene '$id' needs required layers." }
  if (@("gameplay", "hybrid", "diegetic-ui") -contains [string]$scene.kind -and $requiredLayers.Count -lt 3) {
    $issues += "Visual scene '$id' needs at least three required layers to preserve depth and composition."
  }
  if (@($scene.anchors).Count -eq 0) { $issues += "Visual scene '$id' needs normalized composition anchors." }
  foreach ($anchor in @($scene.anchors)) {
    if (([double]$anchor.normalizedRect.x + [double]$anchor.normalizedRect.width) -gt 1.000001 -or ([double]$anchor.normalizedRect.y + [double]$anchor.normalizedRect.height) -gt 1.000001) {
      $issues += "Visual scene '$id' anchor '$($anchor.id)' extends outside the normalized frame."
    }
  }
  if ([int]$scene.maxAttempts -lt 1 -or [int]$scene.maxAttempts -gt 5) { $issues += "Visual scene '$id' maxAttempts must be between 1 and 5." }
  if ([int]$scene.attempt -lt 0 -or [int]$scene.attempt -gt [int]$scene.maxAttempts) { $issues += "Visual scene '$id' attempt must be between 0 and maxAttempts." }

  if ($rank -ge 2) {
    foreach ($relative in @($scene.capture.screenshots)) {
      $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$relative) -Label "Visual scene '$id' Unity screenshot"
      if ($pathIssue) { $issues += $pathIssue }
    }
    if (@($scene.capture.screenshots).Count -eq 0) { $issues += "Visual scene '$id' needs Unity Game View screenshots." }
    if ([string]::IsNullOrWhiteSpace([string]$scene.capture.unityScene) -or [string]::IsNullOrWhiteSpace([string]$scene.capture.camera)) {
      $issues += "Visual scene '$id' needs an exact Unity scene and camera capture setup."
    }
    if ([int]$scene.targetResolution.width -ne [int]$scene.capture.resolution.width -or [int]$scene.targetResolution.height -ne [int]$scene.capture.resolution.height) {
      $issues += "Visual scene '$id' target and capture resolution must match exactly."
    }
    foreach ($layer in $requiredLayers) {
      if (@($layer.implementationPaths).Count -eq 0) { $issues += "Visual scene '$id' required layer '$($layer.id)' has no Unity implementation path." }
      foreach ($relative in @($layer.implementationPaths) + @($layer.evidence)) {
        $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$relative) -Label "Visual scene '$id' layer '$($layer.id)' evidence"
        if ($pathIssue) { $issues += $pathIssue }
      }
    }
    foreach ($anchor in @($scene.anchors)) {
      if ([string]::IsNullOrWhiteSpace([string]$anchor.implementationPath)) { $issues += "Visual scene '$id' anchor '$($anchor.id)' needs an implementation path."; continue }
      $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$anchor.implementationPath) -Label "Visual scene '$id' anchor '$($anchor.id)' implementation"
      if ($pathIssue) { $issues += $pathIssue }
    }
  }

  if ($rank -ge 3) {
    if ([string]::IsNullOrWhiteSpace([string]$scene.comparisonReport)) { $issues += "Visual scene '$id' needs comparisonReport." }
    else {
      $comparisonResult = Test-MLGSVisualComparisonReport -ProjectRoot $ProjectRoot -Path ([string]$scene.comparisonReport) -ExpectedMode scene
      if (-not $comparisonResult.passed) { $issues += @($comparisonResult.issues | ForEach-Object { "Visual scene '$id': $_" }) }
      elseif ($comparisonResult.report) {
        if (@($scene.targetImages) -notcontains [string]$comparisonResult.report.targetImage) { $issues += "Visual scene '$id' comparison target is not listed in targetImages." }
        if (@($scene.capture.screenshots) -notcontains [string]$comparisonResult.report.candidateImage) { $issues += "Visual scene '$id' comparison candidate is not a captured Unity screenshot." }
      }
    }
    foreach ($metric in $metricNames) {
      $threshold = [int]$scene.thresholds.$metric
      $score = [int]$scene.scores.$metric
      if ($threshold -lt 0 -or $threshold -gt 100 -or $score -lt 0 -or $score -gt 100) { $issues += "Visual scene '$id' $metric score/threshold must be between 0 and 100."; continue }
      if ($metric -eq "targetMatch" -and $threshold -lt 85) { $issues += "Visual scene '$id' targetMatch threshold cannot be below 85." }
      if ($metric -ne "targetMatch" -and $threshold -lt 80) { $issues += "Visual scene '$id' $metric threshold cannot be below 80." }
      if ($score -lt $threshold) { $issues += "Visual scene '$id' $metric score $score is below threshold $threshold." }
    }
    if ([string]$scene.automatedVerdict -ne "pass") { $issues += "Visual scene '$id' automated comparison must pass; unavailable and error fail closed." }
    if ([string]$scene.artDirectorVerdict -ne "pass") { $issues += "Visual scene '$id' requires Art Director pass." }
    if ([string]$scene.qaVerdict -ne "pass") { $issues += "Visual scene '$id' requires QA pass." }
    if (@($scene.blockers).Count -gt 0) { $issues += "Visual scene '$id' still has blockers: $(@($scene.blockers) -join '; ')" }
  }
}

$result = [pscustomobject]@{ passed = $issues.Count -eq 0; path = $contractPath; requiredFor = $RequiredFor; minimumStatus = $MinimumStatus; checkedScenes = $requiredScenes.Count; issues = @($issues) }
$result | ConvertTo-Json -Depth 10
if (-not $result.passed) { exit 16 }
