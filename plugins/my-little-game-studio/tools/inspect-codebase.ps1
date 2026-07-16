param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [ValidateSet("auto", "new-project", "small-existing", "large-framework")][string]$ProjectKind = "auto",
  [string]$OverrideReason = "",
  [ValidateRange(20, 1000)][int]$LargeSourceThreshold = 120,
  [ValidateRange(2, 50)][int]$LargeAsmdefThreshold = 6,
  [ValidateRange(2, 100)][int]$LargeFrameworkSignalThreshold = 12,
  [switch]$Apply
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$assets = Join-Path $ProjectRoot "Assets"
if (-not (Test-Path $assets)) { throw "Unity Assets folder does not exist: $assets" }

function To-Relative([string]$FullName) { $FullName.Substring($ProjectRoot.Length).TrimStart('\', '/').Replace("\", "/") }
function Get-Slug([string]$Value) {
  $slug = ($Value.ToLowerInvariant() -replace "[^a-z0-9]+", "-").Trim("-")
  if (-not $slug) { return "module" }
  return $slug
}

$excludedPattern = "(?i)(^|/)(Plugins|ThirdParty|External|Generated|Packages|PackageCache|Samples?)(/|$)"
$allScripts = @(Get-ChildItem -LiteralPath $assets -Recurse -File -Filter "*.cs" -ErrorAction SilentlyContinue)
$projectScripts = @($allScripts | Where-Object { (To-Relative $_.FullName) -notmatch $excludedPattern })
$testScripts = @($projectScripts | Where-Object { (To-Relative $_.FullName) -match "(?i)(^|/)(Tests?|Editor/Tests?)(/|$)|Tests?\.cs$" })
$testScriptPaths = @($testScripts | ForEach-Object { $_.FullName })
$runtimeScripts = @($projectScripts | Where-Object { $testScriptPaths -notcontains $_.FullName })
$asmdefs = @(Get-ChildItem -LiteralPath $assets -Recurse -File -Filter "*.asmdef" -ErrorAction SilentlyContinue | Where-Object { (To-Relative $_.FullName) -notmatch $excludedPattern })
$signalPattern = "(?i)(Bootstrap|Installer|CompositionRoot|EntryPoint|Module|Service|Manager|EventBus|Signal|Repository|Presenter|ViewModel|AssetLoader|Table|Config)"
$frameworkSignals = @($runtimeScripts | Where-Object { $_.BaseName -match $signalPattern })

$externalAdopted = $false
$statePath = Join-Path $ProjectRoot ".mlgs/state.json"
if (Test-Path $statePath) {
  try { $state = Import-MLGSState -Path $statePath; $externalAdopted = [string]$state.activeProject.mode -eq "external-adopted" } catch { }
}

$autoKind = "small-existing"
$confidence = "medium"
$rationale = "Existing Unity code is present but does not cross the deep-analysis thresholds."
if ($runtimeScripts.Count -ge $LargeSourceThreshold -or $asmdefs.Count -ge $LargeAsmdefThreshold -or $frameworkSignals.Count -ge $LargeFrameworkSignalThreshold) {
  $autoKind = "large-framework"; $confidence = "high"; $rationale = "The project crosses a large-codebase threshold and needs dependency-graph analysis."
} elseif (-not $externalAdopted -and $runtimeScripts.Count -le 3 -and $asmdefs.Count -eq 0 -and $frameworkSignals.Count -eq 0) {
  $autoKind = "new-project"; $confidence = "medium"; $rationale = "The project has almost no existing runtime architecture and can establish a minimal foundation."
} elseif ($runtimeScripts.Count -le 3) {
  $confidence = "low"; $rationale = "The codebase is tiny but appears adopted; confirm whether it is a new project or a small legacy project."
}

$selectedKind = if ($ProjectKind -eq "auto") { $autoKind } else { $ProjectKind }
if ($ProjectKind -ne "auto" -and [string]::IsNullOrWhiteSpace($OverrideReason)) { throw "-OverrideReason is required when overriding project classification." }
$classificationSource = if ($ProjectKind -eq "auto") { "auto" } else { "owner-override" }
if ($ProjectKind -ne "auto") { $confidence = "high"; $rationale = "Owner/architect override: $OverrideReason" }

$policy = switch ($selectedKind) {
  "new-project" { [ordered]@{ architectureMode = "create-minimal"; contextDepth = "file-neighborhood"; structuralAnalysisRequirement = "optional"; minimumExemplars = 0; minimumContextFiles = 0; requireModuleMap = $false; requireChangePlan = $true; requirePostImpact = $false; allowNewFoundation = $true; legacyCompatibility = "not-applicable" } }
  "small-existing" { [ordered]@{ architectureMode = "adapt-lightly"; contextDepth = "module-neighborhood"; structuralAnalysisRequirement = "recommended"; minimumExemplars = 2; minimumContextFiles = 2; requireModuleMap = $true; requireChangePlan = $true; requirePostImpact = $false; allowNewFoundation = $true; legacyCompatibility = "balanced" } }
  default { [ordered]@{ architectureMode = "adopt-or-deliberately-evolve"; contextDepth = "dependency-graph"; structuralAnalysisRequirement = "required"; minimumExemplars = 3; minimumContextFiles = 5; requireModuleMap = $true; requireChangePlan = $true; requirePostImpact = $true; allowNewFoundation = $true; legacyCompatibility = "evolve-with-approval" } }
}
$intensity = @{ "new-project" = "lightweight"; "small-existing" = "standard"; "large-framework" = "deep" }[$selectedKind]

$contents = @($runtimeScripts | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue }) -join "`n"
$namespaceMatches = [regex]::Matches($contents, "(?m)^\s*namespace\s+([A-Za-z_][A-Za-z0-9_\.]*)") | ForEach-Object { $_.Groups[1].Value }
$namespaceRoot = @($namespaceMatches | ForEach-Object { ($_ -split '\.')[0] } | Group-Object | Sort-Object Count -Descending | Select-Object -First 1 -ExpandProperty Name)
$namespaceRoot = if ($namespaceRoot.Count) { [string]$namespaceRoot[0] } else { "" }
$logging = if ($contents -match "\bLog\.(e|w|i|d)\s*\(") { "Use the existing custom Log API." } elseif ($contents -match "\bDebug\.Log") { "Use Unity Debug logging with the existing severity pattern." } else { "No stable logger detected; select one before production." }
$asyncFlow = if ($contents -match "\bUniTask\b") { "Use UniTask and project cancellation/lifecycle conventions." } elseif ($contents -match "\bTask\b") { "Use Task/async according to existing lifecycle cancellation." } elseif ($contents -match "\bIEnumerator\b|StartCoroutine") { "Use coroutines according to existing owner lifecycle." } else { "No dominant async style detected; decide per module." }
$events = if ($contents -match "EventBus|MessageBus|Signal") { "Use the detected event/signal system for cross-module communication." } elseif ($contents -match "\bevent\s+|Action<") { "Use typed C# events following existing subscription cleanup." } else { "Prefer direct interfaces locally; introduce events only across real boundaries." }
$configuration = if ($contents -match "ScriptableObject") { "Use existing ScriptableObject configuration patterns." } elseif ($contents -match "Table|Config") { "Use the detected table/configuration pipeline." } else { "Choose validated ScriptableObject or data files; do not hardcode production content." }
$uiArchitecture = if ($contents -match "Presenter|ViewModel") { "Follow the detected Presenter/ViewModel separation." } elseif ($contents -match "BasePanel|UIManager") { "Follow the detected panel/UI manager lifecycle." } else { "Keep UI views passive and gameplay state outside UI." }

$candidatePatterns = [ordered]@{ bootstrap = "(?i)(Bootstrap|Installer|EntryPoint)"; module = "(?i)(Module|System|Manager|Service)"; gameplay = "(?i)(Controller|Gameplay|Combat|Player|Enemy)"; ui = "(?i)(Panel|View|Presenter|ViewModel|UI)"; configuration = "(?i)(Config|Table|Settings)"; persistence = "(?i)(Save|Repository|Persistence)"; test = "(?i)(Test|Spec)" }
$exemplars = @()
foreach ($entry in $candidatePatterns.GetEnumerator()) {
  $file = @($projectScripts | Where-Object { $_.BaseName -match $entry.Value } | Sort-Object Length -Descending | Select-Object -First 1)
  if ($file.Count -eq 0) { continue }
  $relative = To-Relative $file[0].FullName
  if (@($exemplars | Where-Object path -eq $relative).Count -gt 0) { continue }
  $exemplars += [pscustomobject]@{ role = [string]$entry.Key; path = $relative; reason = "Representative detected $($entry.Key) implementation; Unity Architect must confirm."; sha256 = (Get-FileHash -LiteralPath $file[0].FullName -Algorithm SHA256).Hash }
}
$exemplars = @($exemplars | Select-Object -First ([Math]::Max([int]$policy.minimumExemplars, 6)))

$codeRoots = @($runtimeScripts | ForEach-Object {
  $relative = To-Relative $_.FullName
  $parts = $relative -split '/'
  if ($parts.Count -ge 3) { "$($parts[0])/$($parts[1])/$($parts[2])" } elseif ($parts.Count -ge 2) { "$($parts[0])/$($parts[1])" }
} | Where-Object { $_ } | Group-Object | Sort-Object Count -Descending | Select-Object -First 12 -ExpandProperty Name)

$profile = [ordered]@{
  '$schema' = "../../.mlgs/codebase-profile.schema.json"
  schemaVersion = "1.0"
  projectKind = $selectedKind
  intensity = $intensity
  classification = [ordered]@{ source = $classificationSource; confidence = $confidence; rationale = $rationale; overrideReason = $(if ($ProjectKind -eq "auto") { "" } else { $OverrideReason }) }
  metrics = [ordered]@{ runtimeCSharpFiles = $runtimeScripts.Count; testCSharpFiles = $testScripts.Count; asmdefs = $asmdefs.Count; frameworkSignals = $frameworkSignals.Count; topLevelCodeRoots = @($codeRoots) }
  policy = $policy
  structuralAnalysis = [ordered]@{ provider = "none"; status = $(if ($policy.structuralAnalysisRequirement -eq "optional") { "not-required" } else { "pending" }); queries = @(); evidence = @(); notes = "CodeGraph, Roslyn, or manual structural evidence may satisfy this policy; the tool choice is not hard-coded." }
  conventions = [ordered]@{ namespaceRoot = $namespaceRoot; serializedFields = "[SerializeField] private unless confirmed project exemplars differ."; memberNaming = "Follow approved exemplars and existing neighboring module conventions."; logging = $logging; asyncFlow = $asyncFlow; events = $events; configuration = $configuration; uiArchitecture = $uiArchitecture; generatedCodePaths = @("Assets/Generated"); thirdPartyPaths = @("Assets/Plugins", "Assets/ThirdParty", "Assets/External"); notes = @("Auto-detected conventions are candidates until Unity Architect approval.") }
  exemplars = @($exemplars)
  architectVerdict = "pending"
  status = "draft"
  blockers = @()
  updated = (Get-Date).ToString("o")
}

$modules = @()
foreach ($asmdef in $asmdefs) {
  $rootRelative = To-Relative $asmdef.Directory.FullName
  $modules += [pscustomobject][ordered]@{ id = Get-Slug $asmdef.BaseName; root = $rootRelative; state = "existing"; asmdefs = @((To-Relative $asmdef.FullName)); responsibilities = @("Review and record module responsibilities."); publicEntryPoints = @(); dependencies = @(); lifecycle = "Review existing lifecycle."; dataOwnership = @(); exemplars = @($exemplars | Where-Object { $_.path.StartsWith($rootRelative, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -ExpandProperty path) }
}
if ($modules.Count -eq 0 -and $selectedKind -ne "new-project") {
  foreach ($codeRoot in @($codeRoots | Select-Object -First 8)) {
    $modules += [pscustomobject][ordered]@{ id = Get-Slug $codeRoot; root = $codeRoot; state = "existing"; asmdefs = @(); responsibilities = @("Review and record module responsibilities."); publicEntryPoints = @(); dependencies = @(); lifecycle = "Review existing lifecycle."; dataOwnership = @(); exemplars = @($exemplars | Where-Object { $_.path.StartsWith($codeRoot, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -ExpandProperty path) }
  }
}
if ($modules.Count -eq 0 -and $selectedKind -eq "new-project") {
  $modules = @([pscustomobject][ordered]@{ id = "game-foundation"; root = "Assets/Game"; state = "planned"; asmdefs = @(); responsibilities = @("Minimal project foundation and composition root."); publicEntryPoints = @(); dependencies = @(); lifecycle = "Define only what the first production feature requires."; dataOwnership = @(); exemplars = @() })
}
$moduleMap = [ordered]@{ '$schema' = "../../.mlgs/module-map.schema.json"; schemaVersion = "1.0"; projectKind = $selectedKind; modules = @($modules); sharedServices = @(); dependencyRules = @("Feature modules may depend on approved shared contracts; shared code must not depend back on features."); architectVerdict = "pending"; status = "draft"; blockers = @(); updated = (Get-Date).ToString("o") }

if ($Apply) {
  foreach ($schema in @("codebase-profile.schema.json", "module-map.schema.json")) {
    $schemaTarget = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ".mlgs/$schema"
    New-Item -ItemType Directory -Path (Split-Path -Parent $schemaTarget) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $Root "studio/$schema") -Destination $schemaTarget -Force
  }
  $profilePath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath "design/code/codebase-profile.json"
  $modulePath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath "design/code/module-map.json"
  Write-MLGSJsonAtomic -Path $profilePath -Value $profile
  Write-MLGSJsonAtomic -Path $modulePath -Value $moduleMap
}

[pscustomobject]@{ projectRoot = $ProjectRoot; projectKind = $selectedKind; intensity = $intensity; classification = $profile.classification; metrics = $profile.metrics; policy = $policy; profile = $profile; moduleMap = $moduleMap; applied = [bool]$Apply } | ConvertTo-Json -Depth 20
