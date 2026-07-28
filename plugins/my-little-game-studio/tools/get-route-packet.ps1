param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$Command,
  [string]$Mode = "",
  [string]$Stage = "",
  [string]$ProjectRoot = "",
  [string]$StatePath = "",
  [string]$ContextPath = "",
  [string]$RuntimeRoot = "",
  [ValidateSet("model", "full")][string]$View = "model",
  [switch]$AllowUserPointer,
  [switch]$InspectPointer,
  [switch]$AllowLegacyPointer,
  [switch]$SkipState
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)

$catalogPath = Join-Path $Root "workflow/catalog.json"
$routesPath = Join-Path $Root "workflow/routes.json"
if (-not (Test-Path -LiteralPath $catalogPath)) { throw "Missing workflow catalog: $catalogPath" }
if (-not (Test-Path -LiteralPath $routesPath)) { throw "Missing model route manifest: $routesPath" }

$catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
$routes = Get-Content -LiteralPath $routesPath -Raw -Encoding UTF8 | ConvertFrom-Json
$catalogCommand = @($catalog.commands | Where-Object { [string]$_.id -eq $Command }) | Select-Object -First 1
$route = @($routes.commands | Where-Object { [string]$_.id -eq $Command }) | Select-Object -First 1
if ($null -eq $catalogCommand -or $null -eq $route) { throw "Unknown MLGS command: $Command" }

function Get-OptionalArray {
  param($Object, [Parameter(Mandatory = $true)][string]$Name)
  if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) { return @($Object.$Name) }
  return @()
}

function Get-OptionalObject {
  param($Object, [Parameter(Mandatory = $true)][string]$Name)
  if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) { return $Object.$Name }
  return $null
}

$selectedMode = $null
if ($catalogCommand.PSObject.Properties.Name -contains "modes") {
  if ($Mode) {
    $selectedMode = @($catalogCommand.modes | Where-Object { [string]$_.id -eq $Mode }) | Select-Object -First 1
    if ($null -eq $selectedMode) { throw "Unknown mode '$Mode' for MLGS command '$Command'." }
  } else {
    $selectedMode = @($catalogCommand.modes | Where-Object { [bool]$_.default }) | Select-Object -First 1
  }
}

$policies = @(Get-OptionalArray -Object $route -Name "policies")
$policyByMode = Get-OptionalObject -Object $route -Name "policyByMode"
if ($Mode -and $null -ne $policyByMode -and $policyByMode.PSObject.Properties.Name -contains $Mode) {
  $policies += @($policyByMode.$Mode)
}
$policies = @($policies | Where-Object { $_ } | Select-Object -Unique)

$selectedModeFile = ""
$onDemandModeFiles = @()
if ($null -ne $selectedMode) {
  $selectedModeFile = [string]$selectedMode.file
  $stageFiles = @(Get-OptionalArray -Object $selectedMode -Name "stageFiles")
  if ($Stage) {
    $matchedStage = @($stageFiles | Where-Object {
      [System.IO.Path]::GetFileNameWithoutExtension([string]$_).EndsWith("-" + $Stage, [System.StringComparison]::OrdinalIgnoreCase)
    }) | Select-Object -First 1
    if (-not $matchedStage -and $stageFiles.Count -gt 0) { throw "Unknown stage '$Stage' for MLGS command '$Command' mode '$($selectedMode.id)'." }
    if ($matchedStage) { $selectedModeFile = [string]$matchedStage }
  } else {
    $onDemandModeFiles = $stageFiles
  }
}

$resolved = $null
if (-not $SkipState) {
  $resolveArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/resolve-state.ps1"), "-Root", $Root, "-AllowTemplate")
  if ($ProjectRoot) { $resolveArgs += @("-ProjectRoot", $ProjectRoot) }
  if ($StatePath) { $resolveArgs += @("-StatePath", $StatePath) }
  if ($ContextPath) { $resolveArgs += @("-ContextPath", $ContextPath) }
  if ($RuntimeRoot) { $resolveArgs += @("-RuntimeRoot", $RuntimeRoot) }
  if ($AllowUserPointer) { $resolveArgs += "-AllowUserPointer" }
  if ($InspectPointer) { $resolveArgs += "-InspectPointer" }
  if ($AllowLegacyPointer) { $resolveArgs += "-AllowLegacyPointer" }
  $resolved = & powershell @resolveArgs | ConvertFrom-Json
}

$compactState = if ($null -eq $resolved) {
  $null
} else {
  $stateResult = [ordered]@{
    mode = [string]$resolved.mode
    projectId = [string]$resolved.project_id
    projectRoot = [string]$resolved.project_root
    statePath = [string]$resolved.state_path
    stateFormat = [string]$resolved.state_format
    contextPath = [string]$resolved.context_path
    contextSafe = [bool]$resolved.context_safe
    needsRepair = [bool]$resolved.needs_repair
    reason = $(if ($resolved.repair_reason) { [string]$resolved.repair_reason } else { [string]$resolved.context_reason })
  }
  if ($InspectPointer) {
    $stateResult["pointerMismatch"] = [bool]$resolved.pointer_mismatch
    $stateResult["pointerProjectRoot"] = [string]$resolved.pointer_project_root
  }
  $stateResult
}

$packet = [ordered]@{
  schemaVersion = "1.0"
  command = [string]$route.id
  detailFile = [string]$route.detailFile
  lead = [string]$route.lead
  support = @(Get-OptionalArray -Object $route -Name "support")
  conditionalSupport = Get-OptionalObject -Object $route -Name "conditionalSupport"
  policies = @($policies)
  conditionalPolicies = Get-OptionalObject -Object $route -Name "conditionalPolicies"
  conditionalFiles = @(Get-OptionalArray -Object $route -Name "conditionalFiles")
  mode = $(if ($null -ne $selectedMode) { [string]$selectedMode.id } elseif ($Mode) { $Mode } else { $null })
  modeFile = $selectedModeFile
  onDemandModeFiles = @($onDemandModeFiles)
  requiresProjectContext = [bool]$route.requiresProjectContext
  writeRoute = [bool]$route.writeRoute
  steps = @(Get-OptionalArray -Object $route -Name "steps")
  completion = [string]$route.completion
  state = $compactState
}

if ($View -eq "full") {
  [ordered]@{
    packet = $packet
    route = $route
    catalogCommand = $catalogCommand
    resolved = $resolved
  } | ConvertTo-Json -Depth 20
} else {
  $packet | ConvertTo-Json -Depth 12 -Compress
}
