param(
  [string]$Root = "",
  [string]$ProjectRoot = "",
  [string]$StatePath = "",
  [string]$RuntimeRoot = "",
  [switch]$AllowTemplate
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")

$args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/resolve-state.ps1"), "-Root", $Root)
if ($ProjectRoot) { $args += @("-ProjectRoot", $ProjectRoot) }
if ($StatePath) { $args += @("-StatePath", $StatePath) }
if ($RuntimeRoot) { $args += @("-RuntimeRoot", $RuntimeRoot) }
if ($AllowTemplate) { $args += "-AllowTemplate" }
$resolved = & powershell @args | ConvertFrom-Json
$resolvedProjectRoot = if ($ProjectRoot) { [System.IO.Path]::GetFullPath($ProjectRoot) } else { [string]$resolved.project_root }
if ([string]::IsNullOrWhiteSpace($resolvedProjectRoot)) { $resolvedProjectRoot = $Root }
$projectExists = Test-Path $resolvedProjectRoot

function Count-Files {
  param([string]$Path, [string[]]$Include = @("*"))
  if (-not (Test-Path $Path)) { return 0 }
  return @(Get-ChildItem -LiteralPath $Path -Recurse -File -Include $Include -ErrorAction SilentlyContinue).Count
}

$stateExists = $resolved.exists -and $resolved.mode -ne "template" -and (Test-Path $resolved.state_path)
$state = $null
if ($stateExists) {
  $state = Import-MLGSState -Path $resolved.state_path
  $validation = Test-MLGSState -State $state
  if (-not $validation.valid) { throw ("Invalid project state: " + ($validation.errors -join "; ")) }
}

$assetsPath = Join-Path $resolvedProjectRoot "Assets"
$projectSettingsPath = Join-Path $resolvedProjectRoot "ProjectSettings"
$manifestPath = Join-Path $resolvedProjectRoot "Packages/manifest.json"
$unityMarkers = @($assetsPath, $projectSettingsPath, $manifestPath)
$unityMarkerCount = @($unityMarkers | Where-Object { Test-Path $_ }).Count
$isUnityProject = $unityMarkerCount -eq 3
$isPartialUnityProject = $unityMarkerCount -gt 0 -and -not $isUnityProject
$unityVersion = ""
$versionPath = Join-Path $projectSettingsPath "ProjectVersion.txt"
if (Test-Path $versionPath) {
  $match = [regex]::Match((Get-Content -LiteralPath $versionPath -Raw -Encoding UTF8), "m_EditorVersion:\s*([^\r\n]+)")
  if ($match.Success) { $unityVersion = $match.Groups[1].Value.Trim() }
}

$designPath = Join-Path $resolvedProjectRoot "design"
$docsPath = Join-Path $resolvedProjectRoot "docs"
$prototypePath = Join-Path $resolvedProjectRoot "prototype"
$productionPath = Join-Path $resolvedProjectRoot "production"
$testsPath = Join-Path $resolvedProjectRoot "tests"
$systemsCount = Count-Files -Path (Join-Path $designPath "systems") -Include @("*.md")
$hasConcept = Test-Path (Join-Path $designPath "concept-package.md")
$hasTechPlan = Test-Path (Join-Path $docsPath "tech-plan.md")
$hasTaskPlan = Test-Path (Join-Path $productionPath "task-plan.md")
$hasDesignPlan = $systemsCount -gt 0 -and $hasTechPlan -and $hasTaskPlan
$hasPrototypePlan = Test-Path (Join-Path $prototypePath "prototype-plan.md")
$hasPlaytestReport = Test-Path (Join-Path $prototypePath "playtest-report.md")
$hasPrototype = $hasPrototypePlan -and $hasPlaytestReport
$hasTests = (Count-Files -Path $testsPath -Include @("*.cs", "*.md", "*.json", "*.txt")) -gt 0
$hasQa = (Count-Files -Path (Join-Path $productionPath "qa") -Include @("*.md", "*.json", "*.txt")) -gt 0
$sourceFileCount = Count-Files -Path (Join-Path $resolvedProjectRoot "src") -Include @("*.cs", "*.gd", "*.cpp", "*.h", "*.rs", "*.py", "*.js", "*.ts")
$assetFileCount = Count-Files -Path $assetsPath -Include @("*.cs", "*.prefab", "*.unity", "*.asset", "*.mat", "*.controller")
$designFileCount = Count-Files -Path $designPath -Include @("*.md")
$docFileCount = Count-Files -Path $docsPath -Include @("*.md")

$gaps = @()
if (-not $stateExists) { $gaps += "No MLGS project state is configured." }
if ($isPartialUnityProject) { $gaps += "Unity project markers are incomplete; Assets, ProjectSettings, and Packages/manifest.json are all required." }
if (-not $hasConcept) { $gaps += "Missing design/concept-package.md." }
if ($systemsCount -eq 0) { $gaps += "Missing design/systems/*.md." }
if (-not $hasTechPlan) { $gaps += "Missing docs/tech-plan.md." }
if (-not $hasTaskPlan) { $gaps += "Missing production/task-plan.md." }
if (-not $hasPrototypePlan) { $gaps += "Missing prototype/prototype-plan.md." }
if (-not $hasPlaytestReport) { $gaps += "Missing prototype/playtest-report.md." }
if (-not ($hasTests -or $hasQa)) { $gaps += "No tests or production QA evidence detected." }

$gateEvaluation = if ($projectExists) { Get-MLGSGateEvaluation -Root $Root -ProjectRoot $resolvedProjectRoot -State $state } else { $null }
$detectedStage = "not-started"
if (-not $projectExists) { $detectedStage = "missing-project" }
elseif ($stateExists) { $detectedStage = $gateEvaluation.observedPhase }
elseif ($hasTaskPlan -and ($sourceFileCount + $assetFileCount) -gt 0) { $detectedStage = "production" }
elseif ($hasPrototype) { $detectedStage = "prototype" }
elseif ($hasDesignPlan) { $detectedStage = "plan" }
elseif ($hasConcept) { $detectedStage = "concept" }
elseif ($designFileCount -gt 0 -or $docFileCount -gt 0 -or $unityMarkerCount -gt 0) { $detectedStage = "intake" }

$recommendedCommand = if ($stateExists) { "status" } elseif ($isUnityProject -or $isPartialUnityProject -or $designFileCount -gt 0 -or $docFileCount -gt 0 -or $sourceFileCount -gt 0) { "adopt" } else { "start" }

[pscustomobject]@{
  resolve_mode = $resolved.mode
  project_root = $resolvedProjectRoot
  project_exists = $projectExists
  state_path = $resolved.state_path
  state_exists = $stateExists
  state_format = $resolved.state_format
  migration_available = $stateExists -and $resolved.state_format -eq "legacy-yaml"
  is_unity_project = $isUnityProject
  is_partial_unity_project = $isPartialUnityProject
  unity_marker_count = $unityMarkerCount
  unity_version = $unityVersion
  detected_stage = $detectedStage
  recommended_command = $recommendedCommand
  counts = [pscustomobject]@{
    design_files = $designFileCount
    docs_files = $docFileCount
    systems_files = $systemsCount
    source_files = $sourceFileCount
    asset_files = $assetFileCount
  }
  artifacts = [pscustomobject]@{
    concept = $hasConcept
    systems = $systemsCount -gt 0
    tech_plan = $hasTechPlan
    task_plan = $hasTaskPlan
    design_plan = $hasDesignPlan
    prototype_plan = $hasPrototypePlan
    playtest_report = $hasPlaytestReport
    prototype = $hasPrototype
    tests_or_qa = $hasTests -or $hasQa
  }
  gates = $gateEvaluation
  gaps = @($gaps)
} | ConvertTo-Json -Depth 15
