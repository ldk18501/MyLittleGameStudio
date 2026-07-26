param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [string]$Path = "design/content-architecture.json"
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$issues = @()

try { $fullPath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Path }
catch {
  [pscustomobject]@{ passed = $false; experience_class = ""; issues = @($_.Exception.Message) } | ConvertTo-Json -Depth 8
  exit 15
}
if (-not (Test-Path $fullPath)) {
  [pscustomobject]@{ passed = $false; experience_class = ""; issues = @("Missing content architecture: $Path") } | ConvertTo-Json -Depth 8
  exit 15
}
try { $contract = Get-Content -LiteralPath $fullPath -Raw -Encoding UTF8 | ConvertFrom-Json }
catch {
  [pscustomobject]@{ passed = $false; experience_class = ""; issues = @("Invalid content architecture JSON: $($_.Exception.Message)") } | ConvertTo-Json -Depth 8
  exit 15
}

if ([string]$contract.schemaVersion -ne "1.0") { $issues += "schemaVersion must be 1.0." }
if ([string]$contract.status -ne "approved") { $issues += "Content architecture status must be approved." }
$class = [string]$contract.experienceTarget.experienceClass
$thresholds = @{
  "hyper-casual" = @{ references = 0; loops = 2; systems = 2; content = 1; arcs = 1; decisions = 1; minHours = 0 }
  "light"        = @{ references = 0; loops = 3; systems = 3; content = 2; arcs = 2; decisions = 2; minHours = 0 }
  "standard"     = @{ references = 3; loops = 4; systems = 5; content = 4; arcs = 3; decisions = 3; minHours = 10 }
  "deep"         = @{ references = 5; loops = 4; systems = 7; content = 6; arcs = 4; decisions = 5; minHours = 30 }
}
if (-not $thresholds.ContainsKey($class)) {
  $issues += "Unknown experience class: $class"
  $limits = $thresholds["standard"]
} else {
  $limits = $thresholds[$class]
}

$minimumHours = [double]$contract.experienceTarget.targetPlaytimeHours.minimum
$targetHours = [double]$contract.experienceTarget.targetPlaytimeHours.target
if ($targetHours -lt $minimumHours) { $issues += "Target playtime must be greater than or equal to minimum playtime." }
if ($minimumHours -lt [double]$limits.minHours) { $issues += "$class projects require at least $($limits.minHours) target minimum hours." }
if ($minimumHours -ge 30 -and $class -ne "deep") { $issues += "A 30+ hour promise requires experienceClass deep." }
if ($minimumHours -ge 10 -and @("hyper-casual", "light") -contains $class) { $issues += "A 10+ hour promise cannot use a hyper-casual or light architecture." }
if ([double]$contract.experienceTarget.targetSessionMinutes.maximum -lt [double]$contract.experienceTarget.targetSessionMinutes.minimum) { $issues += "Maximum session length must be greater than or equal to minimum session length." }
if ([string]::IsNullOrWhiteSpace([string]$contract.experienceTarget.complexityRationale)) { $issues += "Complexity rationale is required." }

$references = @($contract.research.references)
$requiredReferences = [int]$limits.references
if ([bool]$contract.experienceTarget.referenceDriven -or [bool]$contract.research.webResearchRequired) {
  $requiredReferences = [Math]::Max($requiredReferences, 2)
}
if ($references.Count -lt $requiredReferences) { $issues += "$class architecture requires at least $requiredReferences researched references." }
if ($requiredReferences -gt 0 -and [string]::IsNullOrWhiteSpace([string]$contract.research.performedAt)) { $issues += "Research timestamp is required." }
if ($class -in @("standard", "deep")) {
  if (@($references | Where-Object { [string]$_.role -eq "direct" }).Count -eq 0) { $issues += "Standard/deep research requires a direct reference." }
  if (@($references | Where-Object { [string]$_.role -in @("adjacent", "contrast") }).Count -eq 0) { $issues += "Standard/deep research requires an adjacent or contrast reference." }
}
foreach ($reference in $references) {
  if ([string]$reference.url -notmatch "^https?://") { $issues += "$($reference.id): reference URL must be http(s)." }
  if (@($reference.observedPatterns).Count -eq 0 -or @($reference.adapt).Count -eq 0 -or @($reference.reject).Count -eq 0) { $issues += "$($reference.id): observed, adapt, and reject notes are all required." }
}

$loops = @($contract.loopArchitecture)
$systems = @($contract.systemPortfolio)
$content = @($contract.contentPlan)
$arcs = @($contract.progressionArcs)
$scopeIds = @()
$scopePath = Join-Path $ProjectRoot "production/scope/release-scope.json"
if (Test-Path $scopePath) {
  try {
    $scope = Get-Content -LiteralPath $scopePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $scopeIds = @($scope.items | ForEach-Object { [string]$_.id })
  } catch {
    $issues += "Invalid release scope JSON: $($_.Exception.Message)"
  }
} elseif ($class -in @("standard", "deep")) {
  $issues += "Standard/deep content architecture requires production/scope/release-scope.json."
}
if ($loops.Count -lt [int]$limits.loops) { $issues += "$class architecture requires at least $($limits.loops) loop horizons." }
if ($systems.Count -lt [int]$limits.systems) { $issues += "$class architecture requires at least $($limits.systems) interacting systems." }
if ($content.Count -lt [int]$limits.content) { $issues += "$class architecture requires at least $($limits.content) content families." }
if ($arcs.Count -lt [int]$limits.arcs) { $issues += "$class architecture requires at least $($limits.arcs) progression arcs." }
if ($class -in @("standard", "deep")) {
  foreach ($horizon in @("moment", "session", "medium", "long")) {
    if (@($loops | Where-Object { [string]$_.horizon -eq $horizon }).Count -eq 0) { $issues += "Missing required loop horizon: $horizon" }
  }
}

$systemIds = @($systems | ForEach-Object { [string]$_.id })
foreach ($loop in $loops) {
  if (@($loop.playerDecisions).Count -eq 0) { $issues += "$($loop.name): loop needs a meaningful player decision." }
  foreach ($id in @($loop.systemIds)) { if ($systemIds -notcontains [string]$id) { $issues += "$($loop.name): unknown system ID $id." } }
}
foreach ($system in $systems) {
  if (@($system.playerDecisions).Count -eq 0) { $issues += "$($system.id): system has no player decision." }
  foreach ($id in @($system.synergySystemIds)) { if ($systemIds -notcontains [string]$id) { $issues += "$($system.id): unknown synergy system ID $id." } }
  if ($class -in @("standard", "deep") -and @($system.scopeIds).Count -eq 0) { $issues += "$($system.id): production-depth systems must map to release scope." }
  foreach ($id in @($system.scopeIds)) { if ($scopeIds -notcontains [string]$id) { $issues += "$($system.id): unknown release-scope ID $id." } }
}
if ($class -in @("standard", "deep") -and @($systems | Where-Object { @($_.synergySystemIds).Count -gt 0 }).Count -lt 3) { $issues += "At least three systems must participate in explicit synergies." }
foreach ($family in $content) {
  if ([int]$family.plannedCount -lt 1) { $issues += "$($family.id): plannedCount must be positive." }
  if (@($family.variationAxes).Count -eq 0 -or @($family.systemIds).Count -eq 0) { $issues += "$($family.id): content needs variation axes and system links." }
  if ($class -in @("standard", "deep") -and @($family.scopeIds).Count -eq 0) { $issues += "$($family.id): production-depth content must map to release scope." }
  foreach ($id in @($family.scopeIds)) { if ($scopeIds -notcontains [string]$id) { $issues += "$($family.id): unknown release-scope ID $id." } }
}
foreach ($arc in $arcs) {
  if ([double]$arc.endHour -le [double]$arc.startHour) { $issues += "$($arc.id): endHour must be greater than startHour." }
  if (@($arc.unlocks).Count -eq 0 -or @($arc.novelty).Count -eq 0 -or @($arc.masteryTests).Count -eq 0) { $issues += "$($arc.id): progression arc needs unlocks, novelty, and mastery tests." }
}
if ($arcs.Count -gt 0) {
  $coverageEnd = ($arcs | Measure-Object -Property endHour -Maximum).Maximum
  if ([double]$coverageEnd -lt $minimumHours) { $issues += "Progression arcs end at hour $coverageEnd, before the minimum playtime promise of $minimumHours hours." }
}

if (@($contract.varietyModel.meaningfulDecisionFamilies).Count -lt [int]$limits.decisions) { $issues += "$class architecture needs at least $($limits.decisions) meaningful decision families." }
if (@($contract.varietyModel.combinatorialSources).Count -eq 0 -or @($contract.varietyModel.repetitionControls).Count -eq 0) { $issues += "Variety sources and repetition controls are required." }
if ([string]::IsNullOrWhiteSpace([string]$contract.varietyModel.endgame)) { $issues += "Endgame or terminal mastery design is required." }
if (@($contract.differentiation.borrowedPatterns).Count -eq 0 -or [string]::IsNullOrWhiteSpace([string]$contract.differentiation.uniqueCombination) -or @($contract.differentiation.avoidCloneRules).Count -eq 0) { $issues += "Differentiation must state borrowed patterns, the unique combination, and anti-clone rules." }

$estimatedTotal = [double]$contract.contentBudget.estimatedTotalHours
if ($estimatedTotal -lt $minimumHours) { $issues += "Estimated total content hours ($estimatedTotal) do not support the minimum playtime promise ($minimumHours)." }
if ([string]::IsNullOrWhiteSpace([string]$contract.contentBudget.calculation)) { $issues += "Content budget calculation is required." }
if (-not [bool]$contract.validation.referenceSynthesisComplete) { $issues += "Reference synthesis is incomplete." }
if (-not [bool]$contract.validation.loopCoverageComplete) { $issues += "Loop coverage is incomplete." }
if (-not [bool]$contract.validation.scopeMappingComplete) { $issues += "Release-scope mapping is incomplete." }
if (-not [bool]$contract.validation.prototypeOnlyRiskRejected) { $issues += "The design has not explicitly rejected prototype-only expansion." }
if ([string]$contract.validation.designerVerdict -ne "pass") { $issues += "Game Designer verdict must pass." }
if ([string]::IsNullOrWhiteSpace([string]$contract.updated)) { $issues += "Updated timestamp is required." }

$result = [pscustomobject]@{
  passed = $issues.Count -eq 0
  experience_class = $class
  target_playtime_hours = [pscustomobject]@{ minimum = $minimumHours; target = $targetHours; estimated = $estimatedTotal }
  counts = [pscustomobject]@{ references = $references.Count; loops = $loops.Count; systems = $systems.Count; content_families = $content.Count; progression_arcs = $arcs.Count }
  issues = @($issues)
}
$result | ConvertTo-Json -Depth 10
if (-not $result.passed) { exit 15 }
