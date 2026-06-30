param(
  [string]$Root = "",
  [string]$ProjectRoot = "",
  [string]$StatePath = "",
  [switch]$AllowTemplate
)

if ([string]::IsNullOrWhiteSpace($Root)) {
  $scriptPath = $PSCommandPath
  if ([string]::IsNullOrWhiteSpace($scriptPath)) {
    $scriptPath = $MyInvocation.MyCommand.Path
  }
  if ([string]::IsNullOrWhiteSpace($scriptPath)) {
    $Root = (Get-Location).Path
  } else {
    $Root = Split-Path -Parent (Split-Path -Parent $scriptPath)
  }
}

function Resolve-ExistingPath {
  param([string]$Base, [string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path)) {
    return ""
  }

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }

  return [System.IO.Path]::GetFullPath((Join-Path $Base $Path))
}

function Test-AnyPath {
  param([string[]]$Paths)

  foreach ($path in $Paths) {
    if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path $path)) {
      return $true
    }
  }

  return $false
}

function Count-Files {
  param(
    [string]$Path,
    [string[]]$Include = @("*")
  )

  if (-not (Test-Path $Path)) {
    return 0
  }

  return @(
    Get-ChildItem -Path $Path -Recurse -File -Include $Include -ErrorAction SilentlyContinue
  ).Count
}

function Read-StateValue {
  param([string]$Content, [string]$Key)

  $match = [regex]::Match($Content, "(?m)^\s*$([regex]::Escape($Key))\s*:\s*[""']?([^""'\r\n#]+)")
  if ($match.Success) {
    return $match.Groups[1].Value.Trim()
  }

  return ""
}

$resolverPath = Join-Path $Root "tools/resolve-state.ps1"
$resolvedStatePath = ""
$resolvedProjectRoot = ""
$resolveMode = "explicit"

if (-not [string]::IsNullOrWhiteSpace($StatePath)) {
  $resolvedStatePath = Resolve-ExistingPath $Root $StatePath
  $resolvedProjectRoot = Split-Path -Parent (Split-Path -Parent $resolvedStatePath)
} elseif (-not [string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $resolvedProjectRoot = Resolve-ExistingPath $Root $ProjectRoot
  $resolvedStatePath = Join-Path $resolvedProjectRoot ".mlgs/state.yaml"
} elseif (Test-Path $resolverPath) {
  $resolved = & powershell -ExecutionPolicy Bypass -File $resolverPath -Root $Root -AllowTemplate:$AllowTemplate | ConvertFrom-Json
  $resolvedStatePath = $resolved.state_path
  $resolvedProjectRoot = $resolved.project_root
  $resolveMode = $resolved.mode
} else {
  $resolvedProjectRoot = $Root
}

if ([string]::IsNullOrWhiteSpace($resolvedProjectRoot)) {
  $resolvedProjectRoot = $Root
}

$projectExists = Test-Path $resolvedProjectRoot
$stateExists = (-not [string]::IsNullOrWhiteSpace($resolvedStatePath)) -and (Test-Path $resolvedStatePath)
$stateContent = ""
if ($stateExists) {
  $stateContent = Get-Content -Path $resolvedStatePath -Raw -Encoding UTF8
}

$unityVersionPath = Join-Path $resolvedProjectRoot "ProjectSettings/ProjectVersion.txt"
$unityVersion = ""
if (Test-Path $unityVersionPath) {
  $versionText = Get-Content -Path $unityVersionPath -Raw -Encoding UTF8
  $match = [regex]::Match($versionText, "m_EditorVersion:\s*([^\r\n]+)")
  if ($match.Success) {
    $unityVersion = $match.Groups[1].Value.Trim()
  }
}

$hasAssets = Test-Path (Join-Path $resolvedProjectRoot "Assets")
$hasProjectSettings = Test-Path (Join-Path $resolvedProjectRoot "ProjectSettings")
$hasPackages = Test-Path (Join-Path $resolvedProjectRoot "Packages/manifest.json")
$isUnityProject = $hasAssets -or $hasProjectSettings -or $hasPackages

$designPath = Join-Path $resolvedProjectRoot "design"
$docsPath = Join-Path $resolvedProjectRoot "docs"
$prototypePath = Join-Path $resolvedProjectRoot "prototype"
$productionPath = Join-Path $resolvedProjectRoot "production"
$testsPath = Join-Path $resolvedProjectRoot "tests"
$srcPath = Join-Path $resolvedProjectRoot "src"

$hasReferences = Test-AnyPath @(
  (Join-Path $designPath "references.md"),
  (Join-Path $designPath "reference-analysis.md")
)
$hasConcept = Test-Path (Join-Path $designPath "concept-package.md")
$hasDesignPlan = Test-AnyPath @(
  (Join-Path $docsPath "tech-plan.md"),
  (Join-Path $productionPath "task-plan.md"),
  (Join-Path $designPath "systems")
)
$hasPrototype = Test-AnyPath @(
  (Join-Path $prototypePath "prototype-plan.md"),
  (Join-Path $prototypePath "playtest-report.md")
)
$hasProductionPlan = Test-AnyPath @(
  (Join-Path $productionPath "task-plan.md"),
  (Join-Path $productionPath "tasks")
)
$hasTests = (Count-Files -Path $testsPath -Include @("*.cs", "*.md", "*.json", "*.txt")) -gt 0
$sourceFileCount = Count-Files -Path $srcPath -Include @("*.cs", "*.gd", "*.cpp", "*.h", "*.rs", "*.py", "*.js", "*.ts")
$assetFileCount = Count-Files -Path (Join-Path $resolvedProjectRoot "Assets") -Include @("*.cs", "*.prefab", "*.unity", "*.asset", "*.mat", "*.controller")
$designFileCount = Count-Files -Path $designPath -Include @("*.md")
$docFileCount = Count-Files -Path $docsPath -Include @("*.md")

$phaseFromState = ""
if ($stateExists) {
  $phaseFromState = Read-StateValue $stateContent "current"
}

switch ($phaseFromState) {
  "idea-alignment" { $phaseFromState = "intake" }
  "concept-package" { $phaseFromState = "concept" }
  "design-tech-plan" { $phaseFromState = "plan" }
  "prototype-validation" { $phaseFromState = "prototype" }
  "polish-ship" { $phaseFromState = "release" }
}

$gaps = @()
if (-not $stateExists) { $gaps += "No .mlgs/state.yaml is configured for this project." }
if (-not $hasReferences) { $gaps += "Missing design references." }
if (-not $hasConcept) { $gaps += "Missing concept package." }
if (-not $hasDesignPlan) { $gaps += "Missing system design, tech plan, or task plan." }
if (-not $hasPrototype) { $gaps += "Missing prototype plan or playtest report." }
if (-not $hasTests) { $gaps += "No tests or QA evidence detected." }

$detectedStage = "not-started"
if (-not $projectExists) {
  $detectedStage = "missing-project"
} elseif ($phaseFromState.Length -gt 0 -and $phaseFromState -ne "not-started") {
  $detectedStage = $phaseFromState
} elseif ($hasProductionPlan -and ($sourceFileCount + $assetFileCount) -gt 0) {
  $detectedStage = "production"
} elseif ($hasPrototype) {
  $detectedStage = "prototype"
} elseif ($hasDesignPlan) {
  $detectedStage = "plan"
} elseif ($hasConcept) {
  $detectedStage = "concept"
} elseif ($hasReferences -or $designFileCount -gt 0 -or $docFileCount -gt 0 -or $isUnityProject) {
  $detectedStage = "intake"
}

$recommendedCommand = "start"
if ($stateExists) {
  $recommendedCommand = "status"
} elseif ($isUnityProject -or $designFileCount -gt 0 -or $docFileCount -gt 0 -or $sourceFileCount -gt 0) {
  $recommendedCommand = "adopt"
}

[pscustomobject]@{
  resolve_mode = $resolveMode
  project_root = $resolvedProjectRoot
  project_exists = $projectExists
  state_path = $resolvedStatePath
  state_exists = $stateExists
  is_unity_project = $isUnityProject
  unity_version = $unityVersion
  detected_stage = $detectedStage
  recommended_command = $recommendedCommand
  counts = [pscustomobject]@{
    design_files = $designFileCount
    docs_files = $docFileCount
    source_files = $sourceFileCount
    asset_files = $assetFileCount
  }
  artifacts = [pscustomobject]@{
    references = $hasReferences
    concept = $hasConcept
    design_plan = $hasDesignPlan
    prototype = $hasPrototype
    production_plan = $hasProductionPlan
    tests = $hasTests
  }
  gaps = $gaps
} | ConvertTo-Json -Depth 8
