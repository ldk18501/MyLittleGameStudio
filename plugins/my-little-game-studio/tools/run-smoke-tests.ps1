param([string]$Root = "")

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("mlgs-smoke-" + [guid]::NewGuid().ToString("N"))
$runtimeRoot = Join-Path $sandbox "runtime"
$project = Join-Path $sandbox "UnityProject"
$legacyProject = Join-Path $sandbox "LegacyProject"
$results = @()

function Get-HashState {
  param([string]$Path)
  if (-not (Test-Path $Path)) { return "<missing>" }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Write-SmokePng {
  param([Parameter(Mandatory = $true)][string]$Path)
  $bytes = [Convert]::FromBase64String("iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAQ0lEQVR4nO3RsQ0AIBBCUWQWC0d0BEe0cBfdQAuLK+6/mgQSJADZlVeg9bV/Cuao1w4rmBkgLghmBogLgpkByn4BAByFqAQg3WYqZgAAAABJRU5ErkJggg==")
  [IO.File]::WriteAllBytes($Path, $bytes)
}

function Invoke-Step {
  param([string]$Name, [scriptblock]$Body)
  try {
    & $Body | Out-Null
    return [pscustomobject]@{ name = $Name; status = "pass"; detail = "" }
  } catch {
    return [pscustomobject]@{ name = $Name; status = "fail"; detail = $_.Exception.Message }
  }
}

$protectedPaths = @(
  (Join-Path $Root "studio/current-project.local.yaml"),
  (Join-Path $Root "studio/current-project.local.json"),
  (Join-Path $Root "studio/runtime.json"),
  (Join-Path $Root "studio/logs/activity.jsonl"),
  (Join-Path $Root "dashboard/studio-data.js")
)
$before = @{}
foreach ($path in $protectedPaths) { $before[$path] = Get-HashState $path }

try {
  New-Item -ItemType Directory -Path (Join-Path $project "Assets/Scripts"), (Join-Path $project "ProjectSettings"), (Join-Path $project "Packages") -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $project "ProjectSettings/ProjectVersion.txt") -Value "m_EditorVersion: 6000.0.0f1" -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $project "Packages/manifest.json") -Value "{}" -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $project "Assets/Scripts/PlayerController.cs") -Value "public sealed class PlayerController { }" -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $project "Assets/Scripts/PlayerModel.cs") -Value "public sealed class PlayerModel { }" -Encoding UTF8

  $results += Invoke-Step "check-template-state" {
    $check = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/check-state.ps1") -Root $Root -RuntimeRoot $runtimeRoot | ConvertFrom-Json
    if ($check.status -ne "passed") { throw "Template state check failed." }
  }

  $results += Invoke-Step "detect-complete-unity-project" {
    $detected = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/detect-project-stage.ps1") -Root $Root -ProjectRoot $project -RuntimeRoot $runtimeRoot | ConvertFrom-Json
    if (-not $detected.is_unity_project -or $detected.is_partial_unity_project -or $detected.recommended_command -ne "adopt") { throw "Unity detection is incorrect." }
  }

  $results += Invoke-Step "adopt-isolated-project" {
    $adopted = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/adopt-project.ps1") -Root $Root -ProjectRoot $project -Name "Colon: Smoke" -OwnerParticipation high -ApprovedWritePaths Assets -RuntimeRoot $runtimeRoot -SetCurrent -Apply | ConvertFrom-Json
    if (-not (Test-Path $adopted.apply_result.state_path)) { throw "Adoption did not create state.json." }
    if (-not (Test-Path (Join-Path $runtimeRoot "current-project.json"))) { throw "Isolated pointer was not written." }
  }

  $results += Invoke-Step "build-cadence-authorization" {
    $buildPolicyPath = Join-Path $project ".mlgs/build-policy.json"
    if (-not (Test-Path $buildPolicyPath)) { throw "Project initialization did not create build policy." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-build-authorization.ps1") -Root $Root -ProjectRoot $project -Reason routine-development 2>$null | Out-Null
    if ($LASTEXITCODE -ne 18) { throw "Routine development was allowed to produce a package build." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/preflight-task.ps1") -Root $Root -ProjectRoot $project -Command build 2>$null | Out-Null
    if ($LASTEXITCODE -ne 2) { throw "Build preflight did not block an unclassified routine package build." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-build-authorization.ps1") -Root $Root -ProjectRoot $project -Reason initial-platform-validation 2>$null | Out-Null
    if ($LASTEXITCODE -ne 18) { throw "Initial platform build was allowed outside the start flow." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-build-authorization.ps1") -Root $Root -ProjectRoot $project -Reason initial-platform-validation -StartFlow | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "One-time start-flow platform validation was blocked." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/record-build-event.ps1") -Root $Root -ProjectRoot $project -Kind initial-platform-validation -RequestedBy start-flow -TargetPlatform "Android" -Result passed -Evidence "production/qa/evidence/initial-build.txt" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Initial platform validation result was not recorded." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-build-authorization.ps1") -Root $Root -ProjectRoot $project -Reason initial-platform-validation -StartFlow 2>$null | Out-Null
    if ($LASTEXITCODE -ne 18) { throw "A passed initial platform validation was allowed to repeat automatically." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-build-authorization.ps1") -Root $Root -ProjectRoot $project -Reason owner-request 2>$null | Out-Null
    if ($LASTEXITCODE -ne 18) { throw "Development build was allowed without a current explicit owner request." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-build-authorization.ps1") -Root $Root -ProjectRoot $project -Reason owner-request -OwnerRequested | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Current explicit owner build request was blocked." }
    $buildPolicy = Get-Content -LiteralPath $buildPolicyPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]$buildPolicy.initialValidation.status -ne "passed" -or [int]$buildPolicy.initialValidation.attempts -ne 1) { throw "Build policy did not preserve the one-time validation state." }
  }

  $results += Invoke-Step "status-uses-unified-gates" {
    $status = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/get-project-status.ps1") -Root $Root -ProjectRoot $project -RuntimeRoot $runtimeRoot | ConvertFrom-Json
    if ($status.active_project.owner_participation -ne "high") { throw "Participation was not preserved." }
    if ($status.next_command -ne "/mlgs brainstorm and create the concept package") { throw "Gate-derived next command is incorrect." }
  }

  $results += Invoke-Step "state-schema-rejects-invalid-data" {
    $invalidProject = Join-Path $sandbox "InvalidProject"
    New-Item -ItemType Directory -Path (Join-Path $invalidProject ".mlgs") -Force | Out-Null
    $invalidState = Get-Content -LiteralPath (Join-Path $project ".mlgs/state.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $invalidState | Add-Member -MemberType NoteProperty -Name unexpectedField -Value $true
    $invalidState | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $invalidProject ".mlgs/state.json") -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/detect-project-stage.ps1") -Root $Root -ProjectRoot $invalidProject -RuntimeRoot $runtimeRoot 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { throw "Invalid state was accepted." }
  }

  $results += Invoke-Step "preflight-blocks-locked-production" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/preflight-task.ps1") -Root $Root -Command implement -ProjectRoot $project -RuntimeRoot $runtimeRoot 2>$null | Out-Null
    if ($LASTEXITCODE -ne 2) { throw "Locked production was not blocked." }
  }

  $results += Invoke-Step "preflight-and-write-boundaries" {
    $statePath = Join-Path $project ".mlgs/state.json"
    $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $state.approvals.productionUnblocked = $true
    $state | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $statePath -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/preflight-task.ps1") -Root $Root -Command implement -ProjectRoot $project -RuntimeRoot $runtimeRoot 2>$null | Out-Null
    if ($LASTEXITCODE -ne 2) { throw "Unlocked production without architecture contracts was not blocked." }
    $context = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/new-project-context.ps1") -Root $Root -ProjectRoot $project -RuntimeRoot $runtimeRoot -InvocationId validate-boundaries -TaskId validate-boundaries | ConvertFrom-Json
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/acquire-project-lease.ps1") -Root $Root -ContextPath $context.contextPath -RuntimeRoot $runtimeRoot -InvocationId validate-boundaries -TaskId validate-boundaries -Paths "Assets/Scripts/PlayerController.cs","production/task-plan.md" | Out-Null
    try {
      $valid = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/validate-changes.ps1") -Root $Root -ContextPath $context.contextPath -RuntimeRoot $runtimeRoot -ChangedPaths "Assets/Scripts/PlayerController.cs","production/task-plan.md" | ConvertFrom-Json
      if (-not $valid.valid) { throw "Approved paths were rejected." }
      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/validate-changes.ps1") -Root $Root -ContextPath $context.contextPath -RuntimeRoot $runtimeRoot -ChangedPaths "ProjectSettings/ProjectSettings.asset" 2>$null | Out-Null
      if ($LASTEXITCODE -ne 3) { throw "Out-of-bound path was not rejected." }
    } finally {
      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/release-project-lease.ps1") -Root $Root -ContextPath $context.contextPath -RuntimeRoot $runtimeRoot -InvocationId validate-boundaries 2>$null | Out-Null
    }
  }

  $results += Invoke-Step "framework-reconnaissance" {
    $bootstrapPath = Join-Path $project "Assets/Scripts/GameBootstrap.cs"
    $asmdefPath = Join-Path $project "Assets/Scripts/Game.Runtime.asmdef"
    Set-Content -LiteralPath $bootstrapPath -Value "public sealed class GameBootstrap { }" -Encoding UTF8
    Set-Content -LiteralPath $asmdefPath -Value '{"name":"Game.Runtime"}' -Encoding UTF8
    $report = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/inspect-unity-framework.ps1") -Root $Root -ProjectRoot $project | ConvertFrom-Json
    if (@($report.asmdefPaths) -notcontains "Assets/Scripts/Game.Runtime.asmdef") { throw "Framework reconnaissance did not discover the runtime asmdef." }
    if (@($report.frameworkSignals | Where-Object { $_.path -eq "Assets/Scripts/GameBootstrap.cs" }).Count -eq 0) { throw "Framework reconnaissance did not discover the composition-root candidate." }
    Remove-Item -LiteralPath $bootstrapPath, $asmdefPath -Force
  }

  $results += Invoke-Step "adaptive-codebase-tiers" {
    $newProject = Join-Path $sandbox "TierNew"
    $smallProject = Join-Path $sandbox "TierSmall"
    $largeProject = Join-Path $sandbox "TierLarge"
    foreach ($tierProject in @($newProject, $smallProject, $largeProject)) { New-Item -ItemType Directory -Path (Join-Path $tierProject "Assets/Game") -Force | Out-Null }
    Set-Content -LiteralPath (Join-Path $newProject "Assets/Game/FirstFeature.cs") -Value "public sealed class FirstFeature { }" -Encoding UTF8
    1..4 | ForEach-Object { Set-Content -LiteralPath (Join-Path $smallProject "Assets/Game/Feature$_.cs") -Value "public sealed class Feature$_ { }" -Encoding UTF8 }
    1..20 | ForEach-Object { Set-Content -LiteralPath (Join-Path $largeProject "Assets/Game/System$_.cs") -Value "public sealed class System$_ { }" -Encoding UTF8 }
    $newReport = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/inspect-codebase.ps1") -Root $Root -ProjectRoot $newProject | ConvertFrom-Json
    $smallReport = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/inspect-codebase.ps1") -Root $Root -ProjectRoot $smallProject | ConvertFrom-Json
    $largeReport = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/inspect-codebase.ps1") -Root $Root -ProjectRoot $largeProject -LargeSourceThreshold 20 | ConvertFrom-Json
    if ($newReport.projectKind -ne "new-project" -or $newReport.intensity -ne "lightweight" -or -not [bool]$newReport.policy.allowNewFoundation) { throw "New-project lightweight policy is incorrect." }
    if ($smallReport.projectKind -ne "small-existing" -or $smallReport.intensity -ne "standard" -or [int]$smallReport.policy.minimumExemplars -ne 2) { throw "Small-existing standard policy is incorrect." }
    if ($largeReport.projectKind -ne "large-framework" -or $largeReport.intensity -ne "deep" -or [string]$largeReport.policy.structuralAnalysisRequirement -ne "required") { throw "Large-framework deep policy is incorrect." }
  }

  $results += Invoke-Step "formal-art-pipeline" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/init-production-pipeline.ps1") -Root $Root -ProjectRoot $project | Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/select-game-profile.ps1") -Root $Root -ProjectRoot $project -ProfileId puzzle | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Game profile selection failed." }
    $contentArchitecturePath = Join-Path $project "design/content-architecture.json"
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-content-architecture.ps1") -Root $Root -ProjectRoot $project 2>$null | Out-Null
    if ($LASTEXITCODE -ne 15) { throw "Blank content architecture did not fail closed." }
    $contentArchitecture = Get-Content -LiteralPath $contentArchitecturePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $contentArchitecture.status = "approved"
    $contentArchitecture.experienceTarget.ownerParticipation = "high"
    $contentArchitecture.experienceTarget.targetPlaytimeHours.minimum = 10
    $contentArchitecture.experienceTarget.targetPlaytimeHours.target = 12
    $contentArchitecture.experienceTarget.referenceDriven = $true
    $contentArchitecture.experienceTarget.complexityRationale = "Smoke standard-depth puzzle validates multi-horizon progression rather than a polished single-board prototype."
    $contentArchitecture.experienceTarget.antiScope = @("No copied level layouts")
    $contentArchitecture.research.performedAt = (Get-Date).ToString("o")
    $contentArchitecture.research.references = @(
      [pscustomobject]@{ id = "direct-puzzle"; title = "Direct puzzle reference"; url = "https://example.com/direct-puzzle"; role = "direct"; observedPatterns = @("Curated objective progression"); adapt = @("Readable objective escalation"); reject = @("Copied layouts") },
      [pscustomobject]@{ id = "adjacent-strategy"; title = "Adjacent strategy reference"; url = "https://example.com/adjacent-strategy"; role = "adjacent"; observedPatterns = @("Long-term mastery goals"); adapt = @("Optional mastery layer"); reject = @("Unbounded complexity") },
      [pscustomobject]@{ id = "contrast-puzzle"; title = "Contrast puzzle reference"; url = "https://example.com/contrast-puzzle"; role = "contrast"; observedPatterns = @("Repetitive board variants"); adapt = @("Fast retry"); reject = @("Cosmetic-only variation") }
    )
    $contentArchitecture.loopArchitecture = @(
      [pscustomobject]@{ horizon = "moment"; name = "Read and move"; cadence = "seconds"; playerDecisions = @("Choose the move with the best constraint tradeoff"); systemIds = @("rules", "feedback"); progressionOutput = "Board state knowledge" },
      [pscustomobject]@{ horizon = "session"; name = "Solve a set"; cadence = "10-20 minutes"; playerDecisions = @("Choose level and optional objective"); systemIds = @("levels", "hints"); progressionOutput = "Stars and route access" },
      [pscustomobject]@{ horizon = "medium"; name = "Master a mechanic family"; cadence = "1-3 hours"; playerDecisions = @("Prioritize mastery rewards or route unlocks"); systemIds = @("progression", "levels"); progressionOutput = "New mechanics and modifiers" },
      [pscustomobject]@{ horizon = "long"; name = "Complete mastery routes"; cadence = "10+ hours"; playerDecisions = @("Select advanced challenge branches"); systemIds = @("progression", "hints"); progressionOutput = "Terminal mastery completion" }
    )
    $contentArchitecture.systemPortfolio = @(
      [pscustomobject]@{ id = "rules"; name = "Puzzle rules"; role = "core"; description = "Board rules and resolution"; unlockCondition = "start"; playerDecisions = @("Select legal move"); synergySystemIds = @("feedback", "levels"); referenceIds = @("direct-puzzle"); scopeIds = @("scope-puzzle-rules") },
      [pscustomobject]@{ id = "feedback"; name = "Feedback"; role = "quality-of-life"; description = "Readable consequence feedback"; unlockCondition = "start"; playerDecisions = @("Use feedback to revise plan"); synergySystemIds = @("rules"); referenceIds = @("contrast-puzzle"); scopeIds = @("scope-puzzle-rules") },
      [pscustomobject]@{ id = "levels"; name = "Level library"; role = "content"; description = "Curated and parameterized levels"; unlockCondition = "tutorial complete"; playerDecisions = @("Choose route and objective"); synergySystemIds = @("rules", "progression"); referenceIds = @("direct-puzzle"); scopeIds = @("scope-level-library") },
      [pscustomobject]@{ id = "progression"; name = "Mastery progression"; role = "progression"; description = "Unlock routes and mastery goals"; unlockCondition = "first set complete"; playerDecisions = @("Choose unlock branch"); synergySystemIds = @("levels", "hints"); referenceIds = @("adjacent-strategy"); scopeIds = @("scope-puzzle-rules") },
      [pscustomobject]@{ id = "hints"; name = "Hint economy"; role = "economy"; description = "Recoverable hint resource"; unlockCondition = "first failed level"; playerDecisions = @("Spend hint or preserve it"); synergySystemIds = @("rules", "progression"); referenceIds = @("direct-puzzle"); scopeIds = @("scope-puzzle-rules") }
    )
    $contentArchitecture.contentPlan = @(
      [pscustomobject]@{ id = "tutorial-levels"; category = "Tutorial levels"; productionMode = "authored"; plannedCount = 8; unitPlaytimeMinutes = 5; replayMultiplier = 1; unlockArc = "onboarding"; variationAxes = @("mechanic"); systemIds = @("rules", "feedback"); scopeIds = @("scope-vertical-content") },
      [pscustomobject]@{ id = "core-levels"; category = "Core levels"; productionMode = "hybrid"; plannedCount = 40; unitPlaytimeMinutes = 8; replayMultiplier = 1.3; unlockArc = "core mastery"; variationAxes = @("objective", "layout", "constraint"); systemIds = @("levels", "rules"); scopeIds = @("scope-level-library") },
      [pscustomobject]@{ id = "challenge-levels"; category = "Challenge levels"; productionMode = "authored"; plannedCount = 20; unitPlaytimeMinutes = 12; replayMultiplier = 1.5; unlockArc = "advanced"; variationAxes = @("modifier", "move budget"); systemIds = @("levels", "progression"); scopeIds = @("scope-level-library") },
      [pscustomobject]@{ id = "mastery-goals"; category = "Mastery goals"; productionMode = "emergent"; plannedCount = 30; unitPlaytimeMinutes = 10; replayMultiplier = 1.4; unlockArc = "endgame"; variationAxes = @("route", "score", "restriction"); systemIds = @("progression", "hints"); scopeIds = @("scope-level-library") }
    )
    $contentArchitecture.progressionArcs = @(
      [pscustomobject]@{ id = "learn"; name = "Learn"; startHour = 0; endHour = 2; goals = @("Learn core rules"); unlocks = @("Core route"); novelty = @("New mechanics"); masteryTests = @("Solve without hints") },
      [pscustomobject]@{ id = "combine"; name = "Combine"; startHour = 2; endHour = 7; goals = @("Combine mechanics"); unlocks = @("Challenge route"); novelty = @("Constraint combinations"); masteryTests = @("Meet move budgets") },
      [pscustomobject]@{ id = "master"; name = "Master"; startHour = 7; endHour = 12; goals = @("Complete mastery routes"); unlocks = @("Terminal badges"); novelty = @("Advanced modifiers"); masteryTests = @("Optional perfect clears") }
    )
    $contentArchitecture.varietyModel.meaningfulDecisionFamilies = @("move selection", "route selection", "hint economy")
    $contentArchitecture.varietyModel.combinatorialSources = @("objectives x constraints x mechanics")
    $contentArchitecture.varietyModel.repetitionControls = @("novel mechanic cadence", "optional challenge branches")
    $contentArchitecture.varietyModel.failureRecovery = "Fast retry, readable failure, and bounded hints."
    $contentArchitecture.varietyModel.endgame = "Mastery routes and optional perfect clears."
    $contentArchitecture.differentiation.borrowedPatterns = @("Readable objective escalation", "Optional mastery goals")
    $contentArchitecture.differentiation.uniqueCombination = "Curated puzzle routes with a recoverable hint economy and branching mastery."
    $contentArchitecture.differentiation.avoidCloneRules = @("No copied level layouts", "No copied names or visual expression")
    $contentArchitecture.contentBudget.estimatedAuthoredHours = 8
    $contentArchitecture.contentBudget.estimatedReplayHours = 4
    $contentArchitecture.contentBudget.estimatedTotalHours = 12
    $contentArchitecture.contentBudget.calculation = "68 authored levels plus 30 mastery goals, weighted by unit duration and conservative replay multipliers."
    $contentArchitecture.contentBudget.confidence = "medium"
    $contentArchitecture.validation.referenceSynthesisComplete = $true
    $contentArchitecture.validation.loopCoverageComplete = $true
    $contentArchitecture.validation.scopeMappingComplete = $true
    $contentArchitecture.validation.prototypeOnlyRiskRejected = $true
    $contentArchitecture.validation.designerVerdict = "pass"
    $contentArchitecture.updated = (Get-Date).ToString("o")
    Write-MLGSJsonAtomic -Path $contentArchitecturePath -Value $contentArchitecture
    foreach ($relative in @(
      "design/concept-package.md",
      "design/art/targets/final-gameplay-target.png",
      "Assets/Art/Source/hero.png",
      "Assets/Art/Sprites/hero.png",
      "production/assets/prompts/hero.json",
      "production/assets/import-recipes/hero.json",
      "production/assets/reviews/hero-game-view.png",
      "production/assets/reviews/hero.json",
      "Assets/Prefabs/Hero.prefab"
    )) {
      $path = Join-Path $project $relative
      New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
      if ([IO.Path]::GetExtension($path) -eq ".png") { Write-SmokePng -Path $path }
      else { Set-Content -LiteralPath $path -Value "smoke" -Encoding UTF8 }
    }
    foreach ($entry in @(
      @{ Path = "Assets/Game/World/GameplayRoot.prefab"; Content = "SpriteRenderer world gameplay" },
      @{ Path = "Assets/Game/UI/Hud.prefab"; Content = "UGUI HUD" }
    )) {
      $path = Join-Path $project $entry.Path
      New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
      Set-Content -LiteralPath $path -Value $entry.Content -Encoding UTF8
    }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/inspect-codebase.ps1") -Root $Root -ProjectRoot $project -ProjectKind new-project -OverrideReason "Smoke exercises the lightweight greenfield policy." -Apply | Out-Null
    $codeProfilePath = Join-Path $project "design/code/codebase-profile.json"
    $codeProfile = Get-Content -LiteralPath $codeProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $codeProfile.architectVerdict = "pass"
    $codeProfile.status = "approved"
    $codeProfile.updated = (Get-Date).ToString("o")
    Write-MLGSJsonAtomic -Path $codeProfilePath -Value $codeProfile
    $moduleMapPath = Join-Path $project "design/code/module-map.json"
    $moduleMap = Get-Content -LiteralPath $moduleMapPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $moduleMap.architectVerdict = "pass"
    $moduleMap.status = "approved"
    $moduleMap.updated = (Get-Date).ToString("o")
    Write-MLGSJsonAtomic -Path $moduleMapPath -Value $moduleMap
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/inspect-unity-framework.ps1") -Root $Root -ProjectRoot $project -Apply | Out-Null
    $visualTargetPath = Join-Path $project "design/art/visual-target.json"
    $visualTarget = Get-Content -LiteralPath $visualTargetPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $visualTarget.updated = (Get-Date).ToString("o")
    $visualTarget.targets[0].approved = $true
    $visualTarget.targets[0].imagePath = "design/art/targets/final-gameplay-target.png"
    $visualTarget.targets[0].styleLock.renderingMedium = "Painted low-resolution game art with controlled CRT-era texture"
    $visualTarget.targets[0].styleLock.palette = @(
      [pscustomobject]@{ hex = "#1B2014"; role = "shadow and background" },
      [pscustomobject]@{ hex = "#6F7545"; role = "muted olive midtone" },
      [pscustomobject]@{ hex = "#D2CD83"; role = "yellow-green highlight" }
    )
    $visualTarget.targets[0].styleLock.colorTemperature = "cool olive shadows with restrained yellow-green highlights"
    $visualTarget.targets[0].styleLock.saturation = "muted"
    $visualTarget.targets[0].styleLock.contrast = "low-key scene with readable focal contrast"
    $visualTarget.targets[0].styleLock.lighting = @("single directional practical light")
    $visualTarget.targets[0].styleLock.materials = @("aged painted metal", "dirty glass")
    $visualTarget.targets[0].styleLock.surfaceTexture = @("controlled grime and edge wear")
    $visualTarget.targets[0].styleLock.shapeLanguage = @("chunky late-1990s industrial silhouettes")
    $visualTarget.targets[0].styleLock.uiTreatment = @("cool neutral gray Win98 panels with navy title bars")
    $visualTarget.targets[0].styleLock.preserve = @("preserve olive palette roles", "preserve chunky industrial proportions")
    $visualTarget.targets[0].styleLock.avoid = @("avoid warm amber recoloring", "avoid modern flat UI")
    Write-MLGSJsonAtomic -Path $visualTargetPath -Value $visualTarget

    $frameworkPath = Join-Path $project "design/framework-adoption.json"
    $framework = Get-Content -LiteralPath $frameworkPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $framework.projectMode = "new-foundation"
    $framework.reconnaissance.completed = $true
    $framework.reconnaissance.evidence = @("Assets/Scripts/PlayerController.cs", "Packages/manifest.json")
    $framework.frameworkSignals = @()
    $framework.implementationRoots = @("Assets")
    $framework.architectVerdict = "pass"
    $framework.status = "approved"
    $framework.updated = (Get-Date).ToString("o")
    Write-MLGSJsonAtomic -Path $frameworkPath -Value $framework

    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/new-work-package.ps1") -Root $Root -ProjectRoot $project -Id smoke-feature -Title "Smoke feature" -Objective "Exercise adaptive code task contracts" | Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/new-code-task.ps1") -Root $Root -ProjectRoot $project -TaskId smoke-feature -RequirementSources "design/concept-package.md" -TargetModuleId "game-foundation" | Out-Null
    $contextPath = Join-Path $project "production/context-packs/smoke-feature.json"
    $context = Get-Content -LiteralPath $contextPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $context.plannedFiles.modify = @("Assets/Scripts/PlayerController.cs", "Assets/Scripts/PlayerModel.cs")
    $context.architectVerdict = "pass"
    $context.status = "ready"
    $context.updated = (Get-Date).ToString("o")
    Write-MLGSJsonAtomic -Path $contextPath -Value $context
    $changePlanPath = Join-Path $project "production/change-plans/smoke-feature.json"
    $changePlan = Get-Content -LiteralPath $changePlanPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $changePlan.plannedFiles.modify = @("Assets/Scripts/PlayerController.cs", "Assets/Scripts/PlayerModel.cs")
    $changePlan.responsibilities[0].name = "PlayerController"
    $changePlan.responsibilities[0].path = "Assets/Scripts/PlayerController.cs"
    $changePlan.architectVerdict = "pass"
    $changePlan.status = "approved"
    $changePlan.updated = (Get-Date).ToString("o")
    Write-MLGSJsonAtomic -Path $changePlanPath -Value $changePlan

    $presentationPath = Join-Path $project "design/presentation-architecture.json"
    $presentation = Get-Content -LiteralPath $presentationPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $presentation.dimension = "2d"
    $presentation.pureUIGame = $false
    $presentation.ownerApprovedPureUI = $false
    $presentation.coreGameplayRenderer = "sprite-scene"
    $presentation.coreGameplayPaths = @("Assets/Game/World")
    $presentation.uiPaths = @("Assets/Game/UI")
    $presentation.requiredWorldComponents = @("SpriteRenderer")
    $presentation.evidence = @("Assets/Game/World/GameplayRoot.prefab")
    $presentation.architectVerdict = "pass"
    $presentation.status = "approved"
    $presentation.updated = (Get-Date).ToString("o")
    Write-MLGSJsonAtomic -Path $presentationPath -Value $presentation

    $sceneContractPath = Join-Path $project "design/art/visual-scene-contract.json"
    $assetComparisonPath = "production/qa/evidence/visual-comparisons/hero-asset.json"
    $sceneComparisonPath = "production/qa/evidence/visual-comparisons/gameplay-main-scene.json"
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-visual-comparison.ps1") -Root $Root -ProjectRoot $project -TargetPath "design/art/targets/final-gameplay-target.png" -CandidatePath "production/assets/reviews/hero-game-view.png" -ReportPath $assetComparisonPath -Mode asset | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Asset visual comparison did not pass." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-visual-comparison.ps1") -Root $Root -ProjectRoot $project -TargetPath "design/art/targets/final-gameplay-target.png" -CandidatePath "production/assets/reviews/hero-game-view.png" -ReportPath $sceneComparisonPath -Mode scene | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Scene visual comparison did not pass." }
    $sceneContract = Get-Content -LiteralPath $sceneContractPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $sceneContract.updated = (Get-Date).ToString("o")
    $sceneContract.scenes = @([pscustomobject][ordered]@{
      id = "gameplay-main"
      requiredFor = "vertical-slice"
      kind = "gameplay"
      visualTargetIds = @("VT-001")
      targetImages = @("design/art/targets/final-gameplay-target.png")
      targetResolution = [pscustomobject]@{ width = 1080; height = 1920 }
      capture = [pscustomobject]@{ unityScene = "Assets/Scenes/Main.unity"; camera = "MainCamera"; gameViewPreset = "1080x1920"; resolution = [pscustomobject]@{ width = 1080; height = 1920 }; screenshots = @("production/assets/reviews/hero-game-view.png") }
      layers = @(
        [pscustomobject]@{ id = "background"; role = "background"; renderer = "SpriteRenderer"; required = $true; implementationPaths = @("Assets/Game/World/GameplayRoot.prefab"); evidence = @("production/assets/reviews/hero-game-view.png") },
        [pscustomobject]@{ id = "world"; role = "world-gameplay"; renderer = "SpriteRenderer"; required = $true; implementationPaths = @("Assets/Game/World/GameplayRoot.prefab"); evidence = @("production/assets/reviews/hero-game-view.png") },
        [pscustomobject]@{ id = "foreground"; role = "foreground"; renderer = "SpriteRenderer"; required = $true; implementationPaths = @("Assets/Game/World/GameplayRoot.prefab"); evidence = @("production/assets/reviews/hero-game-view.png") }
      )
      anchors = @([pscustomobject]@{ id = "focal"; purpose = "Primary gameplay focal area"; normalizedRect = [pscustomobject]@{ x = 0.1; y = 0.1; width = 0.8; height = 0.8 }; implementationPath = "Assets/Game/World/GameplayRoot.prefab" })
      thresholds = [pscustomobject]@{ targetMatch = 85; composition = 80; spatialLayout = 80; depthLighting = 80; materialLanguage = 80; detailDensity = 80; diegeticIntegration = 80; readability = 80 }
      scores = [pscustomobject]@{ targetMatch = 90; composition = 90; spatialLayout = 90; depthLighting = 90; materialLanguage = 90; detailDensity = 90; diegeticIntegration = 90; readability = 90 }
      comparisonReport = $sceneComparisonPath
      automatedVerdict = "pass"
      artDirectorVerdict = "pass"
      qaVerdict = "pass"
      status = "approved"
      attempt = 1
      maxAttempts = 3
      blockers = @()
    })
    Write-MLGSJsonAtomic -Path $sceneContractPath -Value $sceneContract
    $recipePath = Join-Path $project "production/assets/import-recipes/hero.json"
    $recipe = Get-Content -LiteralPath (Join-Path $Root "templates/art-import-recipe.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $recipe.assetId = "hero"
    $recipe.texturePath = "Assets/Art/Sprites/hero.png"
    $recipe.usageMetadata = "production/assets/usage/hero.json"
    $recipe.unityImporterEvidence = @("production/assets/reviews/hero-game-view.png")
    Write-MLGSJsonAtomic -Path $recipePath -Value $recipe
    $heroVisualComponent = [pscustomobject][ordered]@{
      mode = "standalone"
      role = "character-sprite"
      reuseKey = "hero"
      generationUnit = "single-sprite"
      styleDescription = "Chunky late-1990s industrial hero sprite using the approved olive palette."
      promptCore = "Generate the isolated hero sprite with the approved chunky industrial silhouette."
      textPolicy = "no-text"
      requiredStates = @("default")
      sourceComponents = @()
      preserve = @("Preserve the hero silhouette and approved palette roles.")
      avoid = @("Avoid modern flat styling or warm amber recoloring.")
    }
    $prompt = Get-Content -LiteralPath (Join-Path $Root "templates/art-prompt-metadata.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $prompt.assetId = "hero"
    $prompt.visualTargetId = "VT-001"
    $prompt.referenceImages = @("design/art/targets/final-gameplay-target.png")
    $prompt.requestedFinalSize = @(32, 32)
    $prompt.generationCanvasSize = @(1024, 1024)
    $prompt.manifestComponentSnapshot = $heroVisualComponent
    $prompt.styleLockSnapshot = $visualTarget.targets[0].styleLock
    $prompt.promptSections.invariants = @($visualTarget.targets[0].styleLock.preserve)
    $prompt.promptSections.negativeConstraints = @($visualTarget.targets[0].styleLock.avoid)
    $prompt.postProcess.outputSize = @(32, 32)
    $prompt.updated = (Get-Date).ToString("o")
    Write-MLGSJsonAtomic -Path (Join-Path $project "production/assets/prompts/hero.json") -Value $prompt
    $usage = Get-Content -LiteralPath (Join-Path $Root "templates/art-usage.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $usage.assetId = "hero"
    $usage.sourceTexture = "Assets/Art/Sprites/hero.png"
    $usage.unityTargets[0].assetPath = "Assets/Prefabs/Hero.prefab"
    $usage.unityTargets[0].objectPath = "Hero/Visual"
    $usage.layout.expectedPixelSize = @(32, 32)
    $usage.verification.gameViewPreset = "1080x1920"
    $usage.verification.evidence = @("production/assets/reviews/hero-game-view.png")
    $usage.updated = (Get-Date).ToString("o")
    Write-MLGSJsonAtomic -Path (Join-Path $project "production/assets/usage/hero.json") -Value $usage
    $manifestPath = Join-Path $project "production/assets/asset-manifest.json"
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $manifest.assets = @([pscustomobject]@{
      id = "hero"
      kind = "sprite"
      usage = "Hero presentation"
      requiredFor = "vertical-slice"
      visualTargets = @("VT-001")
      sourceType = "generated"
      source = "smoke/provider"
      license = "project-owned/generated"
      promptMetadata = "production/assets/prompts/hero.json"
      visualComponent = $heroVisualComponent
      sourceFile = "Assets/Art/Source/hero.png"
      outputPath = "Assets/Art/Sprites/hero.png"
      status = "approved"
      statusHistory = @(
        [pscustomobject]@{ status = "planned"; at = (Get-Date).ToString("o"); evidence = @(); note = "Smoke plan" },
        [pscustomobject]@{ status = "prompt-ready"; at = (Get-Date).ToString("o"); evidence = @("production/assets/prompts/hero.json"); note = "Prompt ready" },
        [pscustomobject]@{ status = "generated"; at = (Get-Date).ToString("o"); evidence = @("Assets/Art/Source/hero.png"); note = "Generated" },
        [pscustomobject]@{ status = "selected"; at = (Get-Date).ToString("o"); evidence = @("Assets/Art/Source/hero.png"); note = "Selected" },
        [pscustomobject]@{ status = "processed"; at = (Get-Date).ToString("o"); evidence = @("Assets/Art/Sprites/hero.png", "production/qa/evidence/sprite-integrity.json"); note = "Processed" },
        [pscustomobject]@{ status = "imported"; at = (Get-Date).ToString("o"); evidence = @("production/assets/import-recipes/hero.json", "production/assets/reviews/hero-game-view.png"); note = "Imported" },
        [pscustomobject]@{ status = "referenced"; at = (Get-Date).ToString("o"); evidence = @("Assets/Prefabs/Hero.prefab"); note = "Referenced" },
        [pscustomobject]@{ status = "approved"; at = (Get-Date).ToString("o"); evidence = @("production/assets/reviews/hero.json", "production/assets/reviews/hero-game-view.png"); note = "Approved" }
      )
      placeholder = $false
      importRecipe = "production/assets/import-recipes/hero.json"
      usageMetadata = "production/assets/usage/hero.json"
      integrity = [pscustomobject]@{
        sourceLayout = "individual"
        extractionMode = "single-object"
        minimumTransparentMargin = 8
        minimumFrameMargin = 2
        expectedFrames = 1
        maxSignificantComponents = 1
        maxBaselineVariance = 2
        maxFrameSizeVarianceRatio = 0.15
        reportPath = "production/qa/evidence/sprite-integrity.json"
        verdict = "pass"
      }
      references = @("Assets/Prefabs/Hero.prefab")
      evidence = @("production/assets/reviews/hero-game-view.png")
      reviewPath = "production/assets/reviews/hero.json"
    })
    $review = [ordered]@{
      '$schema' = "../../../.mlgs/art-review.schema.json"
      schemaVersion = "1.1"
      assetId = "hero"
      visualTargetIds = @("VT-001")
      targetImages = @("design/art/targets/final-gameplay-target.png")
      candidateSource = "Assets/Art/Source/hero.png"
      processedAsset = "Assets/Art/Sprites/hero.png"
      unityReferences = @("Assets/Prefabs/Hero.prefab")
      inGameScreenshots = @("production/assets/reviews/hero-game-view.png")
      comparisonReport = $assetComparisonPath
      scores = [ordered]@{ targetMatch = 90; composition = 85; palette = 85; value = 85; material = 85; detail = 85; readability = 90 }
      automatedVerdict = "pass"
      artDirectorVerdict = "pass"
      qaVerdict = "pass"
      finalVerdict = "pass"
      attempt = 1
      maxAttempts = 3
      blockers = @()
      notes = "Smoke review"
      updated = (Get-Date).ToString("o")
    }
    Write-MLGSJsonAtomic -Path (Join-Path $project "production/assets/reviews/hero.json") -Value $review
    Write-MLGSJsonAtomic -Path $manifestPath -Value $manifest
    $promptPacketJson = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/get-art-prompt-packet.ps1") -Root $Root -ProjectRoot $project -AssetId hero
    if ($LASTEXITCODE -ne 0) { throw "Compact art prompt packet could not be produced." }
    $promptPacket = $promptPacketJson | ConvertFrom-Json
    if ([string]$promptPacket.assetId -ne "hero" -or [string]$promptPacket.contextFingerprint -notmatch "^[a-f0-9]{64}$") { throw "Compact art prompt packet is incomplete." }
    if ($promptPacket.PSObject.Properties.Name -contains "styleLockSnapshot") { throw "Compact art prompt packet leaked the full style lock." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-sprite-integrity.ps1") -Root $Root -ProjectRoot $project | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Sprite integrity evidence did not pass." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/validate-art-manifest.ps1") -Root $Root -ProjectRoot $project -RequiredFor vertical-slice -MinimumStatus approved -DisallowPlaceholders | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Approved art manifest did not pass." }
    $originalHistory = @($manifest.assets[0].statusHistory)
    $manifest.assets[0].statusHistory = @($originalHistory | Where-Object { [string]$_.status -ne "selected" })
    Write-MLGSJsonAtomic -Path $manifestPath -Value $manifest
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/validate-art-manifest.ps1") -Root $Root -ProjectRoot $project -RequiredFor vertical-slice -MinimumStatus approved -DisallowPlaceholders 2>$null | Out-Null
    if ($LASTEXITCODE -ne 4) { throw "Skipped art lifecycle transition passed." }
    $manifest.assets[0].statusHistory = $originalHistory
    Write-MLGSJsonAtomic -Path $manifestPath -Value $manifest
    $recipe.texturePath = "Assets/Art/Sprites/wrong.png"
    Write-MLGSJsonAtomic -Path $recipePath -Value $recipe
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-art-import-recipe.ps1") -Root $Root -ProjectRoot $project -AssetId hero 2>$null | Out-Null
    if ($LASTEXITCODE -ne 20) { throw "Mismatched art import recipe passed." }
    $recipe.texturePath = "Assets/Art/Sprites/hero.png"
    Write-MLGSJsonAtomic -Path $recipePath -Value $recipe
    $baseRecipeJson = $recipe | ConvertTo-Json -Depth 30
    $nineSliceEvidence = @(
      "production/assets/reviews/nine-slice-reference.png",
      "production/assets/reviews/nine-slice-narrow.png",
      "production/assets/reviews/nine-slice-wide.png",
      "production/assets/reviews/nine-slice-tall.png",
      "production/assets/reviews/nine-slice-expanded.png"
    )
    foreach ($relative in $nineSliceEvidence) {
      Copy-Item -LiteralPath (Join-Path $project "production/assets/reviews/hero-game-view.png") -Destination (Join-Path $project $relative) -Force
    }

    $missingPolicyRecipe = $baseRecipeJson | ConvertFrom-Json
    $missingPolicyRecipe.border = @(18, 24, 18, 16)
    $missingPolicyRecipe.slicing.mode = "sliced"
    $missingPolicyRecipe.PSObject.Properties.Remove("nineSlice")
    Write-MLGSJsonAtomic -Path $recipePath -Value $missingPolicyRecipe
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-art-import-recipe.ps1") -Root $Root -ProjectRoot $project -AssetId hero 2>$null | Out-Null
    if ($LASTEXITCODE -ne 20) { throw "Sliced art without a nine-slice policy passed." }

    $asymmetricRecipe = $baseRecipeJson | ConvertFrom-Json
    $asymmetricRecipe.border = @(18, 24, 18, 16)
    $asymmetricRecipe.slicing.mode = "sliced"
    $asymmetricRecipe.nineSlice.classification = "xy"
    $asymmetricRecipe.nineSlice.textureSize = @(104, 104)
    $asymmetricRecipe.nineSlice.safeCenterRect = @(18, 16, 86, 80)
    $asymmetricRecipe.nineSlice.allowedAxes = @("x", "y")
    $asymmetricRecipe.nineSlice.detection.colorEdgeChecked = $true
    $asymmetricRecipe.nineSlice.protrusionPolicy = "none"
    $asymmetricRecipe.nineSlice.validationModes = @("reference", "wide", "tall", "expanded")
    $asymmetricRecipe.nineSlice.notes = "Asymmetric bottom shadow keeps a larger B border."
    $asymmetricRecipe.nineSliceEvidence = @($nineSliceEvidence[0], $nineSliceEvidence[2], $nineSliceEvidence[3], $nineSliceEvidence[4])
    Write-MLGSJsonAtomic -Path $recipePath -Value $asymmetricRecipe
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-art-import-recipe.ps1") -Root $Root -ProjectRoot $project -AssetId hero | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Valid asymmetric xy nine-slice recipe failed." }

    $compositeRecipe = $baseRecipeJson | ConvertFrom-Json
    $compositeRecipe.border = @(20, 16, 20, 16)
    $compositeRecipe.slicing.mode = "sliced"
    $compositeRecipe.nineSlice.classification = "composite"
    $compositeRecipe.nineSlice.textureSize = @(120, 80)
    $compositeRecipe.nineSlice.safeCenterRect = @(20, 16, 100, 64)
    $compositeRecipe.nineSlice.allowedAxes = @()
    $compositeRecipe.nineSlice.detection.colorEdgeChecked = $true
    $compositeRecipe.nineSlice.protrusionPolicy = "separate-sprite"
    $compositeRecipe.nineSlice.validationModes = @()
    $compositeRecipe.nineSlice.notes = "Mid-edge tail must be split before two-axis slicing."
    Write-MLGSJsonAtomic -Path $recipePath -Value $compositeRecipe
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-art-import-recipe.ps1") -Root $Root -ProjectRoot $project -AssetId hero 2>$null | Out-Null
    if ($LASTEXITCODE -ne 20) { throw "Composite mid-edge protrusion passed as a Sliced sprite." }

    $xOnlyRecipe = $baseRecipeJson | ConvertFrom-Json
    $xOnlyRecipe.border = @(20, 16, 20, 16)
    $xOnlyRecipe.slicing.mode = "sliced"
    $xOnlyRecipe.nineSlice.classification = "x-only"
    $xOnlyRecipe.nineSlice.textureSize = @(120, 80)
    $xOnlyRecipe.nineSlice.safeCenterRect = @(20, 16, 100, 64)
    $xOnlyRecipe.nineSlice.allowedAxes = @("x")
    $xOnlyRecipe.nineSlice.detection.colorEdgeChecked = $true
    $xOnlyRecipe.nineSlice.protrusionPolicy = "fixed-band"
    $xOnlyRecipe.nineSlice.validationModes = @("reference", "narrow", "wide")
    $xOnlyRecipe.nineSlice.notes = "The mid-edge tail is valid only while height remains fixed."
    $xOnlyRecipe.nineSliceEvidence = @($nineSliceEvidence[0], $nineSliceEvidence[1], $nineSliceEvidence[2])
    Write-MLGSJsonAtomic -Path $recipePath -Value $xOnlyRecipe
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-art-import-recipe.ps1") -Root $Root -ProjectRoot $project -AssetId hero | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Valid x-only protrusion recipe failed." }

    $recipe = $baseRecipeJson | ConvertFrom-Json
    Write-MLGSJsonAtomic -Path $recipePath -Value $recipe
    $manifest.assets[0].placeholder = $true
    Write-MLGSJsonAtomic -Path $manifestPath -Value $manifest
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/validate-art-manifest.ps1") -Root $Root -ProjectRoot $project -RequiredFor vertical-slice -MinimumStatus approved -DisallowPlaceholders 2>$null | Out-Null
    if ($LASTEXITCODE -ne 4) { throw "Placeholder art passed a final-art gate." }
    $manifest.assets[0].placeholder = $false
    Write-MLGSJsonAtomic -Path $manifestPath -Value $manifest
    $manifest.assets[0].visualTargets = @("VT-missing")
    Write-MLGSJsonAtomic -Path $manifestPath -Value $manifest
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/validate-art-manifest.ps1") -Root $Root -ProjectRoot $project -RequiredFor vertical-slice -MinimumStatus approved -DisallowPlaceholders 2>$null | Out-Null
    if ($LASTEXITCODE -ne 4) { throw "Art without an approved visual target passed." }
    $manifest.assets[0].visualTargets = @("VT-001")
    Write-MLGSJsonAtomic -Path $manifestPath -Value $manifest

    $scopePath = Join-Path $project "production/scope/release-scope.json"
    $scope = Get-Content -LiteralPath $scopePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $profile = Get-Content -LiteralPath (Join-Path $project "design/game-profile.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $scope.updated = (Get-Date).ToString("o")
    $scope.profileId = [string]$profile.id
    $scope.designBaselineVersion = "1"
    $scope.items = @()
    foreach ($requirement in @($profile.releaseScopeRequirements)) {
      $item = [ordered]@{
        id = "scope-$($requirement.id)"
        type = [string]$requirement.type
        description = [string]$requirement.description
        source = "design/concept-package.md"
        requiredFor = [string]$requirement.requiredFor
        status = "integrated"
        placeholder = $false
        plannedCount = [int]$requirement.minimumPlannedCount
        implementedCount = [int]$requirement.minimumPlannedCount
        verifiedCount = 0
        implementation = @("Assets/Scripts/PlayerController.cs")
        evidence = @()
        artAssetIds = @()
        profileRequirementIds = @([string]$requirement.id)
      }
      if ([string]$requirement.type -eq "art") { $item.artAssetIds = @("hero") }
      $scope.items += [pscustomobject]$item
    }
    Write-MLGSJsonAtomic -Path $scopePath -Value $scope
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-content-architecture.ps1") -Root $Root -ProjectRoot $project | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Approved standard-depth content architecture did not pass." }
    $uiPath = Join-Path $project "design/ui/screen-inventory.json"
    $ui = Get-Content -LiteralPath $uiPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $ui.profileId = [string]$profile.id
    $ui.updated = (Get-Date).ToString("o")
    $ui.screens = @()
    foreach ($screenId in @($profile.requiredUiScreens)) {
      $prefabRelative = "Assets/Prefabs/UI/$screenId.prefab"
      $prefabPath = Join-Path $project $prefabRelative
      New-Item -ItemType Directory -Path (Split-Path -Parent $prefabPath) -Force | Out-Null
      Set-Content -LiteralPath $prefabPath -Value "smoke UI" -Encoding UTF8
      $ui.screens += [pscustomobject]@{
        id = [string]$screenId
        scopeId = "scope-ui-production"
        purpose = "Smoke production screen"
        visualTargetIds = @("VT-001")
        prefabOrDocument = $prefabRelative
        states = @("default", "loading", "error")
        controls = @("primary-action")
        componentAudit = [pscustomobject][ordered]@{
          status = "approved"
          method = "manual-visual-audit"
          referenceImage = "design/art/targets/final-gameplay-target.png"
          referenceResolution = @(32, 32)
          completenessNotes = "Smoke audit covers the only visible interactive component."
          artDirectorVerdict = "pass"
          components = @([pscustomobject][ordered]@{
            id = "primary-action-visual"
            role = "primary-action-button"
            controlIds = @("primary-action")
            productionDecision = "procedural-unity"
            assetId = ""
            referenceRect = @(0, 0, 32, 32)
            requiredStates = @("default")
            reuseKey = "primary-action"
            notes = "Initial smoke contract uses a procedural decision."
          })
        }
        artAssetIds = @("hero")
        audioIds = @()
        status = "integrated"
        evidence = @()
      }
    }
    $heroVisualComponent.mode = "screen-derived"
    $heroVisualComponent.role = "primary-action-button"
    $heroVisualComponent.reuseKey = "ui-primary-action"
    $heroVisualComponent.generationUnit = "state-set"
    $heroVisualComponent.styleDescription = "Cool neutral gray Win98 button frame with navy hierarchy and restrained green active fill."
    $heroVisualComponent.promptCore = "Generate only the audited primary action button frame, without baked text, matching the source rectangle."
    $heroVisualComponent.textPolicy = "separate-runtime-text"
    $heroVisualComponent.requiredStates = @("default", "hover", "pressed", "disabled")
    $heroVisualComponent.preserve = @("Preserve the cool gray bevel, square corners, thin dark outline, and restrained green active fill.")
    $heroVisualComponent.avoid = @("Avoid warm beige metal, rounded modern controls, gradients, or baked labels.")
    $heroVisualComponent.sourceComponents = @()
    foreach ($screen in @($ui.screens)) {
      $screen.componentAudit.components[0].productionDecision = "generated-asset"
      $screen.componentAudit.components[0].assetId = "hero"
      $screen.componentAudit.components[0].reuseKey = "ui-primary-action"
      $screen.componentAudit.components[0].requiredStates = @("default", "hover", "pressed", "disabled")
      $screen.artAssetIds = @("hero")
      $heroVisualComponent.sourceComponents += [pscustomobject][ordered]@{
        screenId = [string]$screen.id
        componentId = "primary-action-visual"
        visualTargetId = "VT-001"
        referenceImage = "design/art/targets/final-gameplay-target.png"
        referenceResolution = @(32, 32)
        rect = @(0, 0, 32, 32)
      }
    }
    $manifest.assets[0].visualComponent = $heroVisualComponent
    $prompt.manifestComponentSnapshot = $heroVisualComponent
    $prompt.promptSections.subject = "$($heroVisualComponent.promptCore) Include the required default, hover, pressed, and disabled states."
    $prompt.promptSections.invariants = @($visualTarget.targets[0].styleLock.preserve) + @($heroVisualComponent.preserve)
    $prompt.promptSections.negativeConstraints = @($visualTarget.targets[0].styleLock.avoid) + @($heroVisualComponent.avoid)
    Write-MLGSJsonAtomic -Path (Join-Path $project "production/assets/prompts/hero.json") -Value $prompt
    Write-MLGSJsonAtomic -Path $manifestPath -Value $manifest
    Write-MLGSJsonAtomic -Path $uiPath -Value $ui
    Write-MLGSJsonAtomic -Path $scopePath -Value $scope
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/validate-ui-screen-contract.ps1") -Root $Root -ProjectRoot $project -RequiredFor vertical-slice -MinimumStatus integrated | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Approved UI component decomposition did not pass." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/validate-art-manifest.ps1") -Root $Root -ProjectRoot $project -RequiredFor vertical-slice -MinimumStatus approved -DisallowPlaceholders | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Screen-derived manifest component did not pass." }
    $savedComponents = @($ui.screens[0].componentAudit.components)
    $ui.screens[0].componentAudit.components = @()
    Write-MLGSJsonAtomic -Path $uiPath -Value $ui
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/validate-ui-screen-contract.ps1") -Root $Root -ProjectRoot $project -RequiredFor vertical-slice -MinimumStatus integrated 2>$null | Out-Null
    if ($LASTEXITCODE -ne 13) { throw "Incomplete UI component decomposition passed." }
    $ui.screens[0].componentAudit.components = $savedComponents
    Write-MLGSJsonAtomic -Path $uiPath -Value $ui
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/validate-release-scope.ps1") -Root $Root -ProjectRoot $project -RequiredFor vertical-slice -MinimumStatus integrated -DisallowPlaceholders | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Integrated release scope did not pass." }
    $testScopeItem = @($scope.items | Where-Object { [string]$_.requiredFor -eq "vertical-slice" }) | Select-Object -First 1
    $testScopeItem.implementedCount = [int]$testScopeItem.plannedCount - 1
    Write-MLGSJsonAtomic -Path $scopePath -Value $scope
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/validate-release-scope.ps1") -Root $Root -ProjectRoot $project -RequiredFor vertical-slice -MinimumStatus integrated -DisallowPlaceholders 2>$null | Out-Null
    if ($LASTEXITCODE -ne 7) { throw "Incomplete release-scope counts passed." }
    $testScopeItem.implementedCount = [int]$testScopeItem.plannedCount
    Write-MLGSJsonAtomic -Path $scopePath -Value $scope
  }

  $results += Invoke-Step "skeletal-character-contract-is-scoped" {
    $manifestPath = Join-Path $project "production/assets/asset-manifest.json"
    $promptPath = Join-Path $project "production/assets/prompts/hero.json"
    $contractRelative = "design/art/characters/hero.animation.json"
    $contractPath = Join-Path $project $contractRelative
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $prompt = Get-Content -LiteralPath $promptPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $savedManifestJson = $manifest | ConvertTo-Json -Depth 40
    $savedPromptJson = $prompt | ConvertTo-Json -Depth 40
    try {
      foreach ($relative in @(
        "design/art/characters/source/hero-pose-guide.png",
        "design/art/characters/source/hero-rig-master.png",
        "design/art/characters/source/hero-skeleton-overlay.png",
        "design/art/characters/masks/hero-torso-mask.png"
      )) {
        $full = Join-Path $project $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $full) -Force | Out-Null
        Write-SmokePng -Path $full
      }
      $contract = Get-Content -LiteralPath (Join-Path $Root "templates/character-animation-contract.json") -Raw -Encoding UTF8 | ConvertFrom-Json
      $contract.id = "hero-rig"
      $contract.updated = (Get-Date).ToString("o")
      $contract.status = "approved"
      $contract.assetIds = @("hero")
      $contract.visualTargetIds = @("VT-001")
      $contract.recipeId = "2d-hybrid-combat-character-v1"
      $contract.recipePath = "design/art/recipes/2d-hybrid-combat-character-v1.json"
      $contract.representation = "hybrid"
      $contract.productionView = "side-right"
      $contract.decisionReason = "Smoke validates that skeletal character rules apply only to a declared hybrid-skeletal asset."
      $contract.proportions.headCount = 3
      $contract.proportions.characterHeightPixels = 32
      $contract.proportions.baselineY = 31
      $contract.proportions.tolerancePixels = 1
      $contract.canonicalSource.effectImage = "design/art/targets/final-gameplay-target.png"
      $contract.canonicalSource.poseGuideImage = "design/art/characters/source/hero-pose-guide.png"
      $contract.canonicalSource.rigMasterImage = "design/art/characters/source/hero-rig-master.png"
      $contract.canonicalSource.skeletonOverlayImage = "design/art/characters/source/hero-skeleton-overlay.png"
      $contract.skeleton.sharedProfile = "side-right-smoke-rig"
      $contract.parts[0].sourceFile = "Assets/Art/Sprites/hero.png"
      $contract.parts[0].maskFile = "design/art/characters/masks/hero-torso-mask.png"
      foreach ($test in @($contract.validationTests)) {
        $test.verdict = "pass"
        $test.evidence = @("production/assets/reviews/hero-game-view.png")
      }
      $contract.unity.prefabPath = "Assets/Prefabs/Hero.prefab"
      $contract.unity.gameViewEvidence = @("production/assets/reviews/hero-game-view.png")
      $contract.reviews.artDirectorVerdict = "pass"
      $contract.reviews.technicalArtistVerdict = "pass"
      $contract.reviews.qaVerdict = "pass"
      Write-MLGSJsonAtomic -Path $contractPath -Value $contract

      $manifest.assets[0].visualComponent.generationUnit = "hybrid-skeletal-character"
      $manifest.assets[0] | Add-Member -MemberType NoteProperty -Name animationContract -Value $contractRelative -Force
      Write-MLGSJsonAtomic -Path $manifestPath -Value $manifest

      $prompt.manifestComponentSnapshot = $manifest.assets[0].visualComponent
      $prompt.referenceImages = @($prompt.referenceImages + @(
        "design/art/characters/source/hero-pose-guide.png"
      ) | Select-Object -Unique)
      $prompt.promptSections.invariants = @($prompt.promptSections.invariants + @($contract.promptLock.preserve) | Select-Object -Unique)
      $prompt.promptSections.negativeConstraints = @($prompt.promptSections.negativeConstraints + @($contract.promptLock.avoid) | Select-Object -Unique)
      $prompt.promptText = ([string]$prompt.promptText) + " productionView=side-right headCount=3"
      $prompt | Add-Member -MemberType NoteProperty -Name animationContractSnapshot -Value ([pscustomobject][ordered]@{
        contractPath = $contractRelative
        contractId = "hero-rig"
        recipeId = "2d-hybrid-combat-character-v1"
        representation = "hybrid"
        productionView = "side-right"
        headCount = 3
        preserve = @($contract.promptLock.preserve)
        avoid = @($contract.promptLock.avoid)
      }) -Force
      Write-MLGSJsonAtomic -Path $promptPath -Value $prompt

      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-character-animation-contract.ps1") -Root $Root -ProjectRoot $project -ContractPath $contractRelative -MinimumStatus approved -AssetId hero | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "Approved skeletal character animation contract did not pass." }
      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/validate-art-manifest.ps1") -Root $Root -ProjectRoot $project -RequiredFor vertical-slice -MinimumStatus approved -DisallowPlaceholders | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "Art manifest did not enforce and pass the skeletal character contract." }

      $duplicatePart = $contract.parts[0] | ConvertTo-Json -Depth 20 | ConvertFrom-Json
      $duplicatePart.id = "duplicate-upper-arm"
      $contract.parts = @($contract.parts + $duplicatePart)
      Write-MLGSJsonAtomic -Path $contractPath -Value $contract
      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-character-animation-contract.ps1") -Root $Root -ProjectRoot $project -ContractPath $contractRelative -MinimumStatus approved -AssetId hero 2>$null | Out-Null
      if ($LASTEXITCODE -ne 28) { throw "Duplicate skeletal visible-region ownership passed." }
      $contract.parts = @($contract.parts | Select-Object -First 1)

      $contract.generationPolicy.explodedSheetPolicy = "canonical"
      Write-MLGSJsonAtomic -Path $contractPath -Value $contract
      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-character-animation-contract.ps1") -Root $Root -ProjectRoot $project -ContractPath $contractRelative -MinimumStatus approved -AssetId hero 2>$null | Out-Null
      if ($LASTEXITCODE -ne 28) { throw "Generated exploded sheet was accepted as a canonical skeletal source." }
    } finally {
      Write-MLGSJsonAtomic -Path $manifestPath -Value ($savedManifestJson | ConvertFrom-Json)
      Write-MLGSJsonAtomic -Path $promptPath -Value ($savedPromptJson | ConvertFrom-Json)
    }

    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/validate-art-manifest.ps1") -Root $Root -ProjectRoot $project -RequiredFor vertical-slice -MinimumStatus approved -DisallowPlaceholders | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Static/frame-compatible art path was affected by the skeletal contract." }
  }

  $results += Invoke-Step "art-usage-missing-metadata-fails-closed" {
    $manifestPath = Join-Path $project "production/assets/asset-manifest.json"
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $savedUsageMetadata = [string]$manifest.assets[0].usageMetadata
    try {
      $manifest.assets[0].PSObject.Properties.Remove("usageMetadata")
      Write-MLGSJsonAtomic -Path $manifestPath -Value $manifest
      $usageOutput = @(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-art-usage.ps1") -Root $Root -ProjectRoot $project -AssetId "hero" 2>&1)
      $usageExitCode = $LASTEXITCODE
      $usageText = $usageOutput -join [Environment]::NewLine
      if ($usageExitCode -ne 22) { throw "Missing usageMetadata returned exit code $usageExitCode instead of 22." }
      if ($usageText -match "PropertyNotFoundStrict|VariableIsUndefined|PropertyNotFoundException") { throw "Missing usageMetadata leaked a StrictMode exception." }
      $usageResult = $usageText | ConvertFrom-Json
      if ([bool]$usageResult.passed -or @($usageResult.issues).Count -eq 0) { throw "Missing usageMetadata did not return a structured failure." }
    } finally {
      $manifest.assets[0] | Add-Member -MemberType NoteProperty -Name usageMetadata -Value $savedUsageMetadata -Force
      Write-MLGSJsonAtomic -Path $manifestPath -Value $manifest
    }
  }

  $results += Invoke-Step "legacy-art-contract-status-is-clean" {
    $visualTargetPath = Join-Path $project "design/art/visual-target.json"
    $uiPath = Join-Path $project "design/ui/screen-inventory.json"
    $visualTarget = Get-Content -LiteralPath $visualTargetPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $ui = Get-Content -LiteralPath $uiPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $savedStyleLocks = @($visualTarget.targets | ForEach-Object { $_.styleLock })
    $savedAudits = @($ui.screens | ForEach-Object { $_.componentAudit })
    try {
      foreach ($target in @($visualTarget.targets)) { $target.PSObject.Properties.Remove("styleLock") }
      foreach ($screen in @($ui.screens)) { $screen.PSObject.Properties.Remove("componentAudit") }
      Write-MLGSJsonAtomic -Path $visualTargetPath -Value $visualTarget
      Write-MLGSJsonAtomic -Path $uiPath -Value $ui
      $statusOutput = @(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/get-project-status.ps1") -Root $Root -ProjectRoot $project -RuntimeRoot $runtimeRoot 2>&1)
      $statusExitCode = $LASTEXITCODE
      $statusText = $statusOutput -join [Environment]::NewLine
      if ($statusExitCode -ne 0) { throw "Legacy art contract status returned exit code $statusExitCode." }
      if ($statusText -match "PropertyNotFoundStrict|VariableIsUndefined|PropertyNotFoundException") { throw "Legacy art contract status leaked a StrictMode exception." }
      $legacyStatus = $statusText | ConvertFrom-Json
      if ($null -eq $legacyStatus.gates -or $null -eq $legacyStatus.gaps) { throw "Legacy art contract status did not return the normal structured status payload." }
    } finally {
      for ($index = 0; $index -lt @($visualTarget.targets).Count; $index++) {
        $visualTarget.targets[$index] | Add-Member -MemberType NoteProperty -Name styleLock -Value $savedStyleLocks[$index] -Force
      }
      for ($index = 0; $index -lt @($ui.screens).Count; $index++) {
        $ui.screens[$index] | Add-Member -MemberType NoteProperty -Name componentAudit -Value $savedAudits[$index] -Force
      }
      Write-MLGSJsonAtomic -Path $visualTargetPath -Value $visualTarget
      Write-MLGSJsonAtomic -Path $uiPath -Value $ui
    }
  }

  $results += Invoke-Step "registered-art-sheet-splitting" {
    $sheetRelative = "Assets/Art/Source/smoke-sheet.png"
    Copy-Item -LiteralPath (Join-Path $project "Assets/Art/Source/hero.png") -Destination (Join-Path $project $sheetRelative) -Force
    $plan = Get-Content -LiteralPath (Join-Path $Root "templates/art-batch.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $plan.id = "smoke-sheet"
    $plan.sourceImage = $sheetRelative
    $plan.canvasSize = @(32, 32)
    $plan.minimumCellMargin = 0
    $plan.items = @(
      [pscustomobject]@{ assetId = "smoke-left"; rect = @(0, 0, 16, 32); outputPath = "Assets/Art/Sprites/smoke-left.png"; finalSize = @(16, 16); safePadding = 0; removeMatte = $false; maxSignificantComponents = 1 },
      [pscustomobject]@{ assetId = "smoke-right"; rect = @(16, 0, 16, 32); outputPath = "Assets/Art/Sprites/smoke-right.png"; finalSize = @(16, 16); safePadding = 0; removeMatte = $false; maxSignificantComponents = 1 }
    )
    $plan.reportPath = "production/qa/evidence/art-batches/smoke-sheet.json"
    $plan.updated = (Get-Date).ToString("o")
    $planPath = Join-Path $project "production/assets/batches/smoke-sheet.json"
    Write-MLGSJsonAtomic -Path $planPath -Value $plan
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/split-art-sheet.ps1") -Root $Root -ProjectRoot $project -PlanPath "production/assets/batches/smoke-sheet.json" | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $project "Assets/Art/Sprites/smoke-left.png")) -or -not (Test-Path (Join-Path $project "Assets/Art/Sprites/smoke-right.png"))) { throw "Registered art sheet split failed." }
    $plan.items[1].rect = @(8, 0, 16, 32)
    $plan.reportPath = "production/qa/evidence/art-batches/smoke-sheet-overlap.json"
    Write-MLGSJsonAtomic -Path $planPath -Value $plan
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/split-art-sheet.ps1") -Root $Root -ProjectRoot $project -PlanPath "production/assets/batches/smoke-sheet.json" 2>$null | Out-Null
    if ($LASTEXITCODE -ne 23) { throw "Overlapping registered art cells passed." }
  }

  $results += Invoke-Step "profile-baseline-ui-contracts" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/validate-game-profile-coverage.ps1") -Root $Root -ProjectRoot $project | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Game profile coverage did not pass." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/validate-ui-screen-contract.ps1") -Root $Root -ProjectRoot $project -RequiredFor content-complete -MinimumStatus integrated | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "UI screen contract did not pass." }
    $baselineSources = @("design/concept-package.md", "design/content-architecture.json", "design/game-profile.json", "design/ui/screen-inventory.json", "design/art/visual-scene-contract.json", "design/framework-adoption.json", "design/presentation-architecture.json", "design/code/codebase-profile.json", "design/code/module-map.json", "production/scope/release-scope.json")
    & (Join-Path $Root "tools/freeze-design-baseline.ps1") -Root $Root -ProjectRoot $project -Version 1 -SourcePaths $baselineSources | Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-design-baseline.ps1") -Root $Root -ProjectRoot $project | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Fresh design baseline did not pass." }
    Add-Content -LiteralPath (Join-Path $project "design/concept-package.md") -Value "design mutation" -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-design-baseline.ps1") -Root $Root -ProjectRoot $project 2>$null | Out-Null
    if ($LASTEXITCODE -ne 14) { throw "Changed design source did not invalidate the baseline." }
    & (Join-Path $Root "tools/freeze-design-baseline.ps1") -Root $Root -ProjectRoot $project -Version 2 -SourcePaths $baselineSources -Force | Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-design-baseline.ps1") -Root $Root -ProjectRoot $project | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Re-frozen design baseline did not pass." }
  }

  $results += Invoke-Step "visual-framework-presentation-contracts" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-visual-scene-contract.ps1") -Root $Root -ProjectRoot $project -RequiredFor vertical-slice -MinimumStatus approved | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Approved visual scene contract did not pass." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-framework-adoption.ps1") -Root $Root -ProjectRoot $project | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Approved framework adoption did not pass." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-presentation-architecture.ps1") -Root $Root -ProjectRoot $project | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Approved presentation architecture did not pass." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-codebase-understanding.ps1") -Root $Root -ProjectRoot $project | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Approved lightweight codebase profile did not pass." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-code-task.ps1") -Root $Root -ProjectRoot $project -TaskId smoke-feature | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Approved lightweight code task did not pass." }
    $context = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/new-project-context.ps1") -Root $Root -ProjectRoot $project -RuntimeRoot $runtimeRoot -InvocationId approved-preflight -TaskId smoke-feature | ConvertFrom-Json
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/acquire-project-lease.ps1") -Root $Root -ContextPath $context.contextPath -RuntimeRoot $runtimeRoot -InvocationId approved-preflight -TaskId smoke-feature -Paths "Assets/Scripts/PlayerController.cs" | Out-Null
    try {
      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/preflight-task.ps1") -Root $Root -Command implement -TaskId smoke-feature -ContextPath $context.contextPath -RuntimeRoot $runtimeRoot | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "Approved architecture contracts did not unlock production preflight." }
    } finally {
      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/release-project-lease.ps1") -Root $Root -ContextPath $context.contextPath -RuntimeRoot $runtimeRoot -InvocationId approved-preflight 2>$null | Out-Null
    }

    $sceneContractPath = Join-Path $project "design/art/visual-scene-contract.json"
    $sceneContract = Get-Content -LiteralPath $sceneContractPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $sceneContract.scenes[0].scores.targetMatch = 84
    Write-MLGSJsonAtomic -Path $sceneContractPath -Value $sceneContract
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-visual-scene-contract.ps1") -Root $Root -ProjectRoot $project -RequiredFor vertical-slice -MinimumStatus approved 2>$null | Out-Null
    if ($LASTEXITCODE -ne 16) { throw "Low whole-screen target match passed." }
    $sceneContract.scenes[0].scores.targetMatch = 90
    Write-MLGSJsonAtomic -Path $sceneContractPath -Value $sceneContract

    $frameworkPath = Join-Path $project "design/framework-adoption.json"
    $framework = Get-Content -LiteralPath $frameworkPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $codeProfilePath = Join-Path $project "design/code/codebase-profile.json"
    $codeProfile = Get-Content -LiteralPath $codeProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $originalProjectKind = [string]$codeProfile.projectKind
    $originalFrameworkMode = [string]$framework.projectMode
    $codeProfile.projectKind = "small-existing"
    $framework.projectMode = "existing-framework"
    $framework.frameworkSignals = @()
    Write-MLGSJsonAtomic -Path $codeProfilePath -Value $codeProfile
    Write-MLGSJsonAtomic -Path $frameworkPath -Value $framework
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-framework-adoption.ps1") -Root $Root -ProjectRoot $project 2>$null | Out-Null
    if ($LASTEXITCODE -ne 17) { throw "Existing project without framework signals passed." }
    $codeProfile.projectKind = $originalProjectKind
    $framework.projectMode = $originalFrameworkMode
    Write-MLGSJsonAtomic -Path $codeProfilePath -Value $codeProfile
    Write-MLGSJsonAtomic -Path $frameworkPath -Value $framework

    $contextPath = Join-Path $project "production/context-packs/smoke-feature.json"
    $context = Get-Content -LiteralPath $contextPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $context.status = "implemented"
    $context.updated = (Get-Date).ToString("o")
    Write-MLGSJsonAtomic -Path $contextPath -Value $context
    $changePlanPath = Join-Path $project "production/change-plans/smoke-feature.json"
    $changePlan = Get-Content -LiteralPath $changePlanPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $changePlan.status = "implemented"
    $changePlan.updated = (Get-Date).ToString("o")
    Write-MLGSJsonAtomic -Path $changePlanPath -Value $changePlan
    $plannedConformanceOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-code-conformance.ps1") -Root $Root -ProjectRoot $project -TaskId smoke-feature -ChangedPaths "Assets/Scripts/PlayerController.cs","Assets/Scripts/PlayerModel.cs" 2>&1
    $plannedConformanceExitCode = $LASTEXITCODE
    if ($plannedConformanceExitCode -ne 0) { throw "Planned code change did not pass conformance: $($plannedConformanceOutput -join [Environment]::NewLine)" }
    $taskAudit = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-production-code.ps1") -Root $Root -ProjectRoot $project -TaskId smoke-feature -ChangedPaths "Assets/Scripts/PlayerController.cs","Assets/Scripts/PlayerModel.cs" -NoWrite | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or [string]$taskAudit.conformanceVerdict -ne "pass") { throw "Nested task-scoped production audit did not pass conformance." }
    $forwardedConformance = Get-Content -LiteralPath (Join-Path $project "production/quality/code-conformance-smoke-feature.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    if (@($forwardedConformance.changedPaths).Count -ne 2) { throw "Nested task-scoped production audit dropped changed paths across the PowerShell process boundary." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-code-conformance.ps1") -Root $Root -ProjectRoot $project -TaskId smoke-feature -ChangedPaths "Assets/Scripts/Unplanned.cs" 2>$null | Out-Null
    if ($LASTEXITCODE -ne 21) { throw "Unplanned code change passed conformance." }

    $worldPath = Join-Path $project "Assets/Game/World/GameplayRoot.prefab"
    Set-Content -LiteralPath $worldPath -Value "SpriteRenderer RectTransform CanvasRenderer" -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-presentation-architecture.ps1") -Root $Root -ProjectRoot $project 2>$null | Out-Null
    if ($LASTEXITCODE -ne 18) { throw "UGUI content inside 2D core gameplay passed." }
    Set-Content -LiteralPath $worldPath -Value "SpriteRenderer world gameplay" -Encoding UTF8
  }

  $results += Invoke-Step "capability-routing" {
    $readyKinds = @("image-generation", "sprite-processing", "unity-import", "unity-validation", "visual-comparison")
    & (Join-Path $Root "tools/get-production-capabilities.ps1") -Root $Root -ProjectRoot $project -DeclareReady $readyKinds -Provider "Smoke provider" -Evidence "production/assets/reviews/hero-game-view.png" -SupportsVerification | Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-production-capabilities.ps1") -Root $Root -ProjectRoot $project -RequiredFor vertical-slice | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Ready production capabilities did not pass." }
    $capabilityPath = Join-Path $project "production/capabilities/capability-manifest.json"
    $capability = Get-Content -LiteralPath $capabilityPath -Raw -Encoding UTF8 | ConvertFrom-Json
    (@($capability.capabilities | Where-Object kind -eq "visual-comparison") | Select-Object -First 1).status = "missing"
    Write-MLGSJsonAtomic -Path $capabilityPath -Value $capability
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-production-capabilities.ps1") -Root $Root -ProjectRoot $project -RequiredFor vertical-slice 2>$null | Out-Null
    if ($LASTEXITCODE -ne 15) { throw "Missing visual comparison capability did not fail closed." }
    & (Join-Path $Root "tools/get-production-capabilities.ps1") -Root $Root -ProjectRoot $project -DeclareReady $readyKinds -Provider "Smoke provider" -Evidence "production/assets/reviews/hero-game-view.png" -SupportsVerification | Out-Null
  }

  $results += Invoke-Step "structured-quality-gate" {
    $created = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/new-quality-gate.ps1") -Root $Root -ProjectRoot $project -Stage vertical-slice | ConvertFrom-Json
    $report = Get-Content -LiteralPath $created.report_path -Raw -Encoding UTF8 | ConvertFrom-Json
    $evidencePath = Join-Path $project "production/quality/evidence/vertical-slice-smoke.md"
    New-Item -ItemType Directory -Path (Split-Path -Parent $evidencePath) -Force | Out-Null
    Set-Content -LiteralPath $evidencePath -Value "isolated smoke evidence" -Encoding UTF8
    $report.verdict = "pending"
    $report.declaredVerdict = "pass"
    $report.objectiveVerdict = "pending"
    $report.ownerApproval = $true
    $report.updated = (Get-Date).ToString("o")
    foreach ($check in $report.checks) {
      $check.status = "pass"
      $check.evidence = @("production/quality/evidence/vertical-slice-smoke.md")
      $check.objectiveVerdict = "pending"
      $check.objectiveChecks[0].path = "production/quality/evidence/vertical-slice-smoke.md"
      $check.objectiveChecks[0].status = "pending"
    }
    Write-MLGSJsonAtomic -Path $created.report_path -Value $report
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-production-code.ps1") -Root $Root -ProjectRoot $project | Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/run-objective-checks.ps1") -Root $Root -ProjectRoot $project -Path "production/quality/vertical-slice.json" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Objective quality checks did not pass." }
    $report = Get-Content -LiteralPath $created.report_path -Raw -Encoding UTF8 | ConvertFrom-Json
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-quality-gate.ps1") -Root $Root -ProjectRoot $project -Stage vertical-slice | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Complete structured quality gate did not pass." }
    $report.checks[0].evidence = @("production/quality/evidence/missing.md")
    Write-MLGSJsonAtomic -Path $created.report_path -Value $report
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-quality-gate.ps1") -Root $Root -ProjectRoot $project -Stage vertical-slice 2>$null | Out-Null
    if ($LASTEXITCODE -ne 5) { throw "Missing evidence file passed the quality gate." }
    $report.checks[0].evidence = @("production/quality/evidence/vertical-slice-smoke.md")
    $report.checks[0].status = "pending"
    Write-MLGSJsonAtomic -Path $created.report_path -Value $report
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-quality-gate.ps1") -Root $Root -ProjectRoot $project -Stage vertical-slice 2>$null | Out-Null
    if ($LASTEXITCODE -ne 5) { throw "Incomplete structured quality gate passed." }
    $report.checks[0].status = "pass"
    Write-MLGSJsonAtomic -Path $created.report_path -Value $report
    $orderedStatus = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/get-project-status.ps1") -Root $Root -ProjectRoot $project -RuntimeRoot $runtimeRoot | ConvertFrom-Json
    if ($orderedStatus.active_project.observed_phase -ne "concept") { throw "Later quality evidence skipped an earlier phase gate." }
  }

  $results += Invoke-Step "bounded-work-package" {
    $created = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/new-work-package.ps1") -Root $Root -ProjectRoot $project -Id smoke-work -Title "Smoke work" -Objective "Verify objective truth" -MaxAttempts 2 | ConvertFrom-Json
    $package = Get-Content -LiteralPath $created.path -Raw -Encoding UTF8 | ConvertFrom-Json
    $package.successCriteria[0].statement = "Smoke evidence exists."
    $package.successCriteria[0].evidence = @("production/quality/evidence/vertical-slice-smoke.md")
    $package.successCriteria[0].objectiveChecks[0].path = "production/quality/evidence/vertical-slice-smoke.md"
    $package.updated = (Get-Date).ToString("o")
    Write-MLGSJsonAtomic -Path $created.path -Value $package
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/run-objective-checks.ps1") -Root $Root -ProjectRoot $project -Path "production/work-packages/smoke-work.json" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Work package objective check failed." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/new-execution-strategy.ps1") -Root $Root -ProjectRoot $project -WorkPackagePath "production/work-packages/smoke-work.json" -Strategy pipeline -Domain art -Reason "Exercise staged art-role orchestration" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Execution strategy creation failed." }
    $execution = Get-Content -LiteralPath (Join-Path $project "production/execution/smoke-work.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $executionRoles = @($execution.groups | ForEach-Object { [string]$_.role })
    if ([string]$execution.domain -ne "art" -or $executionRoles -notcontains "technical-artist" -or $executionRoles -notcontains "art-director" -or $executionRoles -contains "gameplay-developer") { throw "Art execution strategy used incorrect roles." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/complete-work-package-attempt.ps1") -Root $Root -ProjectRoot $project -Path "production/work-packages/smoke-work.json" -Verdict pass -Evidence "production/quality/evidence/vertical-slice-smoke.md" | Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-work-package.ps1") -Root $Root -ProjectRoot $project -Path "production/work-packages/smoke-work.json" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Completed work package did not pass." }

    $blocked = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/new-work-package.ps1") -Root $Root -ProjectRoot $project -Id blocked-work -Title "Blocked work" -Objective "Exercise bounded retry" -MaxAttempts 1 | ConvertFrom-Json
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/complete-work-package-attempt.ps1") -Root $Root -ProjectRoot $project -Path "production/work-packages/blocked-work.json" -Verdict fail -Gaps "Missing required result" | Out-Null
    $blockedPackage = Get-Content -LiteralPath $blocked.path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($blockedPackage.status -ne "blocked" -or $blockedPackage.declaredVerdict -ne "blocked") { throw "Attempt exhaustion did not fail closed." }
  }

  $results += Invoke-Step "production-code-audit" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-production-code.ps1") -Root $Root -ProjectRoot $project | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Clean production code audit failed." }
    $badPath = Join-Path $project "Assets/Scripts/BadRuntime.cs"
    Set-Content -LiteralPath $badPath -Value 'public sealed class BadRuntime { void Start() { UnityEngine.GameObject.Find("Hidden"); } }' -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-production-code.ps1") -Root $Root -ProjectRoot $project -NoWrite 2>$null | Out-Null
    if ($LASTEXITCODE -ne 6) { throw "Prohibited production shortcut was not rejected." }
    Remove-Item -LiteralPath $badPath -Force
  }

  $results += Invoke-Step "legacy-state-migration" {
    New-Item -ItemType Directory -Path (Join-Path $legacyProject ".mlgs") -Force | Out-Null
    $legacy = @"
version: 0.2
kind: project
active_project:
  name: "Legacy Game"
  slug: "legacy-game"
  mode: external-adopted
  workspace_path: ""
  external_path: "$($legacyProject.Replace("\", "/"))"
  engine: Unity
  language: C#
  engine_version: "2022.3"
  approved_write_paths:
    - "Assets"
owner_participation:
  level: medium
  notes: ""
automation:
  planning: high
  production: medium
phase:
  current: plan
approvals:
  project_selected: true
  concept_package: true
  design_tech_plan: false
  prototype_validation: false
  production_unblocked: false
prototype:
  policy: recommended
  type: html-or-unity-greybox
  verdict: pending
  skip_reason: ""
next_action:
  command: /mlgs plan systems and tasks
  reason: "Legacy migration test"
  options: []
assumptions: []
risks: []
staff:
  last_lead: producer
  last_agents: []
"@
    Set-Content -LiteralPath (Join-Path $legacyProject ".mlgs/state.yaml") -Value $legacy -Encoding UTF8
    $migration = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/migrate-state.ps1") -Root $Root -ProjectRoot $legacyProject | ConvertFrom-Json
    $migrated = Get-Content -LiteralPath $migration.state_path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($migrated.schemaVersion -ne "0.3" -or $migrated.activeProject.name -ne "Legacy Game") { throw "Legacy migration lost data." }
  }

  $results += Invoke-Step "isolated-trace-dashboard" {
    $trace = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/trace.ps1") -Root $Root -ProjectRoot $project -RuntimeRoot $runtimeRoot -Command test -Title "Isolated smoke trace" -LeadAgent qa-lead -AgentsUsed qa-lead,producer -Verification "isolated" -Summary "Smoke trace"
    if (($trace -join "`n") -notmatch "Trace recorded") { throw "Trace did not complete." }
    $projectRuntime = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/resolve-state.ps1") -Root $Root -ProjectRoot $project -RuntimeRoot $runtimeRoot | ConvertFrom-Json).project_runtime_root
    if (-not (Test-Path (Join-Path $projectRuntime "dashboard/studio-data.js"))) { throw "Dashboard was not exported to the isolated project runtime." }
  }

  $results += Invoke-Step "multi-project-context-and-leases" {
    $secondProject = Join-Path $sandbox "SecondProject"
    New-Item -ItemType Directory -Path $secondProject -Force | Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/init-project-state.ps1") -Root $Root -ProjectRoot $secondProject -Name "Second Smoke" -Mode internal -ApprovedWritePaths Assets -RuntimeRoot $runtimeRoot | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Second project initialization failed." }

    $contextA = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/new-project-context.ps1") -Root $Root -ProjectRoot $project -RuntimeRoot $runtimeRoot -InvocationId smoke-a -TaskId task-a | ConvertFrom-Json
    $contextB = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/new-project-context.ps1") -Root $Root -ProjectRoot $secondProject -RuntimeRoot $runtimeRoot -InvocationId smoke-b -TaskId task-b | ConvertFrom-Json
    if ($contextA.projectId -eq $contextB.projectId -or $contextA.runtimeRoot -eq $contextB.runtimeRoot) { throw "Different projects shared identity or runtime root." }
    if (-not (Test-Path $contextA.contextPath) -or -not (Test-Path $contextB.contextPath)) { throw "Bound project contexts were not persisted." }

    Push-Location $secondProject
    try { $nearest = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/resolve-state.ps1") -Root $Root -RuntimeRoot $runtimeRoot | ConvertFrom-Json }
    finally { Pop-Location }
    if ($nearest.mode -ne "nearest-project" -or $nearest.project_id -ne $contextB.projectId -or [bool]$nearest.pointer_mismatch -or $nearest.pointer_project_root) { throw "Nearest project was contaminated by the compatibility pointer." }

    $explicit = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/resolve-state.ps1") -Root $Root -ProjectRoot $secondProject -RuntimeRoot $runtimeRoot | ConvertFrom-Json
    if ($explicit.mode -ne "explicit-project" -or $explicit.project_id -ne $contextB.projectId -or [bool]$explicit.pointer_mismatch -or $explicit.pointer_project_root) { throw "Explicit project resolution was contaminated by the compatibility pointer." }

    $pointerIgnored = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/resolve-state.ps1") -Root $Root -RuntimeRoot $runtimeRoot -AllowTemplate | ConvertFrom-Json
    if ($pointerIgnored.mode -eq "user-pointer") { throw "Compatibility pointer was read without explicit opt-in." }

    $pointerRecovery = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/resolve-state.ps1") -Root $Root -RuntimeRoot $runtimeRoot -AllowUserPointer | ConvertFrom-Json
    if ($pointerRecovery.mode -ne "user-pointer" -or $pointerRecovery.project_id -ne $contextA.projectId) { throw "Explicit compatibility-pointer recovery failed." }

    $pointerOnly = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/preflight-task.ps1") -Root $Root -RuntimeRoot $runtimeRoot -Command implement 2>$null | ConvertFrom-Json
    if ($LASTEXITCODE -ne 2 -or @($pointerOnly.blockers | Where-Object { $_ -match "No project state" }).Count -eq 0) { throw "Pointer-only project write was not blocked." }

    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/trace.ps1") -Root $Root -ContextPath $contextA.contextPath -RuntimeRoot $runtimeRoot -InvocationId smoke-a -TaskId task-a -Command test -Title "Project A trace" -Summary "A" | Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/trace.ps1") -Root $Root -ContextPath $contextB.contextPath -RuntimeRoot $runtimeRoot -InvocationId smoke-b -TaskId task-b -Command test -Title "Project B trace" -Summary "B" | Out-Null
    $eventsA = @(Get-Content -LiteralPath (Join-Path $contextA.runtimeRoot "logs/activity.jsonl") -Encoding UTF8 | ForEach-Object { $_ | ConvertFrom-Json })
    $eventsB = @(Get-Content -LiteralPath (Join-Path $contextB.runtimeRoot "logs/activity.jsonl") -Encoding UTF8 | ForEach-Object { $_ | ConvertFrom-Json })
    if (@($eventsA | Where-Object { $_.projectId -ne $contextA.projectId }).Count -gt 0 -or @($eventsB | Where-Object { $_.projectId -ne $contextB.projectId }).Count -gt 0) { throw "Project trace events crossed runtime boundaries." }

    $activeA = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/new-project-context.ps1") -Root $Root -ProjectRoot $project -RuntimeRoot $runtimeRoot -InvocationId active-a -TaskId active-task-a | ConvertFrom-Json
    $activeB = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/new-project-context.ps1") -Root $Root -ProjectRoot $project -RuntimeRoot $runtimeRoot -InvocationId active-b -TaskId active-task-b | ConvertFrom-Json
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/trace.ps1") -Root $Root -ContextPath $activeA.contextPath -RuntimeRoot $runtimeRoot -Command implement -Title "Active A" -Status started | Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/trace.ps1") -Root $Root -ContextPath $activeB.contextPath -RuntimeRoot $runtimeRoot -Command implement -Title "Active B" -Status started | Out-Null
    $activeRuntime = Get-Content -LiteralPath (Join-Path $contextA.runtimeRoot "runtime.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    if (@($activeRuntime.activeTasks).Count -ne 2) { throw "Concurrent active task roster did not retain both tasks." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/trace.ps1") -Root $Root -ContextPath $activeA.contextPath -RuntimeRoot $runtimeRoot -Command implement -Title "Active A" -Status completed | Out-Null
    $activeRuntime = Get-Content -LiteralPath (Join-Path $contextA.runtimeRoot "runtime.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    if (@($activeRuntime.activeTasks).Count -ne 1 -or [string]$activeRuntime.activeTasks[0].invocationId -ne "active-b") { throw "Completing one task removed or corrupted another active task." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/trace.ps1") -Root $Root -ContextPath $activeB.contextPath -RuntimeRoot $runtimeRoot -Command implement -Title "Active B" -Status completed | Out-Null

    $leaseA = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/new-project-context.ps1") -Root $Root -ProjectRoot $project -RuntimeRoot $runtimeRoot -InvocationId lease-a -TaskId task-a | ConvertFrom-Json
    $leaseOverlap = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/new-project-context.ps1") -Root $Root -ProjectRoot $project -RuntimeRoot $runtimeRoot -InvocationId lease-overlap -TaskId task-overlap | ConvertFrom-Json
    $leaseDisjoint = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/new-project-context.ps1") -Root $Root -ProjectRoot $project -RuntimeRoot $runtimeRoot -InvocationId lease-disjoint -TaskId task-disjoint | ConvertFrom-Json
    $leaseB = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/new-project-context.ps1") -Root $Root -ProjectRoot $secondProject -RuntimeRoot $runtimeRoot -InvocationId lease-b -TaskId task-b | ConvertFrom-Json
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/acquire-project-lease.ps1") -Root $Root -ContextPath $leaseA.contextPath -RuntimeRoot $runtimeRoot -InvocationId lease-a -TaskId task-a -Paths "Assets/Scripts" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Primary project lease failed." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/acquire-project-lease.ps1") -Root $Root -ContextPath $leaseOverlap.contextPath -RuntimeRoot $runtimeRoot -InvocationId lease-overlap -TaskId task-overlap -Paths "Assets/Scripts/Player.cs" 2>$null | Out-Null
    if ($LASTEXITCODE -ne 9) { throw "Overlapping same-project lease was not blocked." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/acquire-project-lease.ps1") -Root $Root -ContextPath $leaseDisjoint.contextPath -RuntimeRoot $runtimeRoot -InvocationId lease-disjoint -TaskId task-disjoint -Paths "Assets/Art" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Disjoint same-project lease was blocked." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/acquire-project-lease.ps1") -Root $Root -ContextPath $leaseB.contextPath -RuntimeRoot $runtimeRoot -InvocationId lease-b -TaskId task-b -Paths "Assets/Scripts" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Different-project lease was blocked by another project." }
    foreach ($lease in @(
      [pscustomobject]@{ ContextPath = $leaseA.contextPath; InvocationId = "lease-a" },
      [pscustomobject]@{ ContextPath = $leaseDisjoint.contextPath; InvocationId = "lease-disjoint" },
      [pscustomobject]@{ ContextPath = $leaseB.contextPath; InvocationId = "lease-b" }
    )) {
      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/release-project-lease.ps1") -Root $Root -ContextPath $lease.ContextPath -RuntimeRoot $runtimeRoot -InvocationId $lease.InvocationId | Out-Null
    }
  }

  $results += Invoke-Step "model-context-token-budget" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-token-budget.ps1") -Root $Root -View model | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Model-context token budget failed." }
  }

  $results += Invoke-Step "route-boundary-wrappers" {
    $wrapperProject = Join-Path $sandbox "route-wrapper-project"
    $wrapperRuntime = Join-Path $sandbox "route-wrapper-runtime"
    New-Item -ItemType Directory -Path $wrapperProject -Force | Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/init-project-state.ps1") -Root $Root -ProjectRoot $wrapperProject -Name "Route Wrapper Test" -ApprovedWritePaths Assets -RuntimeRoot $wrapperRuntime -SkipPointer | Out-Null
    $start = & (Join-Path $Root "tools/start-route.ps1") -Root $Root -Command fix -ProjectRoot $wrapperProject -RuntimeRoot $wrapperRuntime -InvocationId wrapper-test -TaskId wrapper-task -Paths @("Assets") -AcceptRisk -View model | ConvertFrom-Json
    if (-not [bool]$start.started) { throw "start-route did not acquire a context, lease, and passing preflight." }
    $finish = & (Join-Path $Root "tools/finish-route.ps1") -Root $Root -ContextPath $start.contextPath -Command fix -Title "Route wrapper smoke" -TaskId wrapper-task -LeadAgent gameplay-developer -AgentsUsed @("gameplay-developer", "qa-lead") -ChangedPaths @("Assets/probe.txt") -Verification @("wrapper smoke") -Summary "wrapper passed" -View model | ConvertFrom-Json
    if (-not [bool]$finish.finished -or -not [bool]$finish.traceRecorded -or -not [bool]$finish.leaseReleased) { throw "finish-route did not validate, trace, and release the lease." }
  }

  $results += Invoke-Step "plugin-package-is-self-contained" {
    $pluginRoot = Join-Path $Root "plugins/my-little-game-studio"
    foreach ($relative in @("AGENTS.md", "agents/art-director.md", "workflow/catalog.json", "workflow/routes.json", "workflow/phases.json", "workflow/gates.json", "profiles/unity/catalog.json", "commands/status.md", "rules/studio/art-generation.md", "rules/art-generation/draft.md", "rules/art-generation/batch-plan.md", "rules/art-generation/formal.md", "rules/character-animation-art.md", "templates/character-animation-contract.json", "templates/art-recipes/2d-hybrid-combat-character-v1.json", "tools/workflow-catalog.ps1", "tools/get-route-packet.ps1", "tools/start-route.ps1", "tools/finish-route.ps1", "tools/test-token-budget.ps1", "tools/resolve-state.ps1", "tools/new-project-context.ps1", "tools/acquire-project-lease.ps1", "tools/release-project-lease.ps1", "tools/init-production-pipeline.ps1", "tools/init-build-policy.ps1", "tools/new-work-package.ps1", "tools/get-production-capabilities.ps1", "tools/test-content-architecture.ps1", "tools/test-build-authorization.ps1", "tools/record-build-event.ps1", "tools/test-art-import-recipe.ps1", "tools/test-art-prompt.ps1", "tools/get-art-prompt-packet.ps1", "tools/test-art-usage.ps1", "tools/test-character-animation-contract.ps1", "tools/split-art-sheet.ps1", "tools/split_art_sheet.py", "tools/test-visual-comparison.ps1", "tools/test_visual_comparison.py", "tools/freeze-design-baseline.ps1", "tools/validate-release-scope.ps1", "studio/state.json", "studio/visual-target.schema.json", "studio/visual-comparison.schema.json", "studio/art-import-recipe.schema.json", "studio/art-prompt-metadata.schema.json", "studio/art-batch.schema.json", "studio/art-usage.schema.json", "studio/character-animation-contract.schema.json", "studio/project-context.schema.json", "studio/project-lease.schema.json", "studio/release-scope.schema.json", "studio/work-package.schema.json", "studio/game-profile.schema.json", "studio/content-architecture.schema.json", "studio/build-policy.schema.json", "studio/capability-manifest.schema.json", "dashboard/index.html")) {
      if (-not (Test-Path (Join-Path $pluginRoot $relative))) { throw "Plugin package is missing $relative" }
    }
    $pluginRuntime = Join-Path $sandbox "plugin-runtime"
    $pluginProject = Join-Path $sandbox "plugin-project"
    New-Item -ItemType Directory -Path $pluginProject -Force | Out-Null
    $pluginCheck = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $pluginRoot "tools/check-state.ps1") -Root $pluginRoot -RuntimeRoot $pluginRuntime | ConvertFrom-Json
    if ($pluginCheck.status -ne "passed" -or $pluginCheck.mode -ne "template") { throw "Installed-layout template resolution failed." }
    $pluginInit = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $pluginRoot "tools/init-project-state.ps1") -Root $pluginRoot -ProjectRoot $pluginProject -Name "Installed Layout" -ApprovedWritePaths Assets -RuntimeRoot $pluginRuntime -SkipPointer | ConvertFrom-Json
    if (-not (Test-Path $pluginInit.state_path)) { throw "Installed-layout state initialization failed." }
  }
} finally {
  $liveMutationFound = $false
  foreach ($path in $protectedPaths) {
    $after = Get-HashState $path
    if ($after -ne $before[$path]) {
      $liveMutationFound = $true
      $results += [pscustomobject]@{ name = "no-live-state-mutation"; status = "fail"; detail = "Protected file changed: $path" }
    }
  }
  if (-not $liveMutationFound) {
    $results += [pscustomobject]@{ name = "no-live-state-mutation"; status = "pass"; detail = "" }
  }
  $sandboxFull = [System.IO.Path]::GetFullPath($sandbox)
  $tempFull = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
  if ($sandboxFull.StartsWith($tempFull, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path $sandboxFull)) {
    Remove-Item -LiteralPath $sandboxFull -Recurse -Force
  }
}

$failed = @($results | Where-Object { $_.status -eq "fail" })
[pscustomobject]@{ status = $(if ($failed.Count -eq 0) { "pass" } else { "fail" }); results = $results } | ConvertTo-Json -Depth 10
if ($failed.Count -gt 0) { exit 1 }
