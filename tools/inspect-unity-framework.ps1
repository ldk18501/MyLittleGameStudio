param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [string]$Path = "design/framework-adoption.json",
  [switch]$Apply
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$assets = Join-Path $ProjectRoot "Assets"
if (-not (Test-Path $assets)) { throw "Unity Assets folder does not exist: $assets" }

function To-Relative([string]$FullName) {
  return $FullName.Substring($ProjectRoot.Length).TrimStart('\', '/').Replace("\", "/")
}

$excluded = "(?i)(^|/)(Plugins|ThirdParty|External|Samples?)(/|$)"
$asmdefs = @(Get-ChildItem -LiteralPath $assets -Recurse -File -Filter "*.asmdef" -ErrorAction SilentlyContinue | ForEach-Object { To-Relative $_.FullName } | Where-Object { $_ -notmatch $excluded } | Sort-Object -Unique)
$scripts = @(Get-ChildItem -LiteralPath $assets -Recurse -File -Filter "*.cs" -ErrorAction SilentlyContinue | Where-Object { (To-Relative $_.FullName) -notmatch $excluded })
$signals = @()
$patterns = [ordered]@{
  bootstrap = "(?i)(Bootstrap|Installer|CompositionRoot|EntryPoint)"
  module = "(?i)(Module|Feature)"
  lifecycle = "(?i)(Lifecycle|GameLoop|AppState|StateMachine)"
  events = "(?i)(EventBus|MessageBus|Signal|EventSystem)"
  config = "(?i)(Config|Settings|Table|Database)"
  save = "(?i)(Save|Persistence|Repository)"
  ui = "(?i)(UIManager|Panel|View|Presenter|ViewModel)"
  assets = "(?i)(Addressable|AssetLoader|ResourceService)"
  tests = "(?i)(Test|Spec)"
}
foreach ($file in $scripts) {
  foreach ($entry in $patterns.GetEnumerator()) {
    if ($file.BaseName -match $entry.Value) {
      $signals += [pscustomobject]@{ kind = [string]$entry.Key; name = $file.BaseName; path = (To-Relative $file.FullName); decision = "adopt" }
      break
    }
  }
}
foreach ($relative in $asmdefs) { $signals += [pscustomobject]@{ kind = "assembly"; name = [System.IO.Path]::GetFileNameWithoutExtension($relative); path = $relative; decision = "adopt" } }
$signals = @($signals | Sort-Object path -Unique)

$report = [ordered]@{
  projectRoot = $ProjectRoot
  packagesManifest = "Packages/manifest.json"
  asmdefPaths = @($asmdefs)
  frameworkSignals = @($signals)
  warnings = @()
}
if ($signals.Count -eq 0) { $report.warnings += "No obvious framework signals were detected; Unity Architect must inspect module ownership manually." }

if ($Apply) {
  $target = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Path
  if (-not (Test-Path $target)) { throw "Initialize the production pipeline before applying framework reconnaissance: $Path" }
  $contract = Get-Content -LiteralPath $target -Raw -Encoding UTF8 | ConvertFrom-Json
  $contract.projectMode = if ($signals.Count -gt 0 -or $asmdefs.Count -gt 0) { "existing-framework" } else { "new-foundation" }
  $contract.reconnaissance.completed = $true
  $contract.reconnaissance.asmdefPaths = @($asmdefs)
  $contract.reconnaissance.evidence = @("Packages/manifest.json") + @($asmdefs) + @($signals | Select-Object -First 10 -ExpandProperty path)
  $contract.frameworkSignals = @($signals)
  if ([string]$contract.projectMode -eq "new-foundation") {
    $planned = @{
      compositionRoot = "Assets/Game/Bootstrap/GameBootstrap.cs"
      moduleBoundary = "Assets/Game"
      lifecycle = "Assets/Game/Bootstrap/GameBootstrap.cs"
      configuration = "Assets/Game/Config"
      uiPresentation = "Assets/Game/UI"
    }
    foreach ($name in $planned.Keys) {
      $contract.selectedIntegration.$name.decision = "create"
      $contract.selectedIntegration.$name.path = $planned[$name]
      $contract.selectedIntegration.$name.notes = "Planned minimal foundation; create only when a real production task requires it."
    }
    foreach ($name in @("events", "persistence")) {
      $contract.selectedIntegration.$name.decision = "not-applicable"
      $contract.selectedIntegration.$name.path = ""
      $contract.selectedIntegration.$name.notes = "Introduce only when a real requirement appears."
    }
  }
  $contract.architectVerdict = "pending"
  $contract.status = "draft"
  $contract.updated = (Get-Date).ToString("o")
  Write-MLGSJsonAtomic -Path $target -Value $contract
  $report.appliedPath = $target
}

$report | ConvertTo-Json -Depth 10
