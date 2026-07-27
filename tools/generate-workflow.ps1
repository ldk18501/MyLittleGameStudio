param([string]$Root = "", [switch]$Check)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/workflow-catalog.ps1")
$catalog = Import-MLGSWorkflowCatalog -Root $Root -IncludePhases -IncludeGates

function Get-MLGSOptionalArray {
  param($Object, [Parameter(Mandatory = $true)][string]$Name)
  if ($Object.PSObject.Properties.Name -contains $Name) { return @($Object.$Name) }
  return @()
}

$errors = @()
foreach ($command in $catalog.commands) {
  if (-not (Test-Path (Join-Path $Root $command.file))) { $errors += "Missing command file: $($command.file)" }
  if (-not (Test-Path (Join-Path $Root ("agents/" + $command.lead + ".md")))) { $errors += "Missing lead agent: $($command.lead)" }
  $supports = @(Get-MLGSOptionalArray -Object $command -Name "support" | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
  foreach ($support in $supports) {
    if (-not (Test-Path (Join-Path $Root ("agents/" + $support + ".md")))) { $errors += "Missing supporting agent: $support" }
  }
  if ($command.PSObject.Properties.Name -contains "modes") {
    $defaults = @($command.modes | Where-Object { $_.default -eq $true })
    if ($defaults.Count -ne 1) { $errors += "Command $($command.id) must define exactly one default mode." }
    foreach ($mode in @($command.modes)) {
      foreach ($name in @("id", "file", "intents")) {
        if (-not ($mode.PSObject.Properties.Name -contains $name)) { $errors += "Command $($command.id) mode is missing $name." }
      }
      if ($mode.file -and -not (Test-Path (Join-Path $Root ([string]$mode.file)))) { $errors += "Missing mode file: $($mode.file)" }
      foreach ($stageFile in @(Get-MLGSOptionalArray -Object $mode -Name "stageFiles")) {
        if (-not (Test-Path (Join-Path $Root ([string]$stageFile)))) { $errors += "Missing mode stage file: $stageFile" }
      }
    }
  }
}
$commandIds = @($catalog.commands.id)
foreach ($phase in $catalog.phases) {
  foreach ($commandId in @($phase.commands)) {
    if ($commandIds -notcontains $commandId) { $errors += "Phase $($phase.id) references unknown command $commandId" }
  }
  if (-not ($catalog.gates.PSObject.Properties.Name -contains [string]$phase.gate)) { $errors += "Phase $($phase.id) references unknown gate $($phase.gate)" }
}
foreach ($gateProperty in $catalog.gates.PSObject.Properties) {
  $gate = $gateProperty.Value
  if ($gate.PSObject.Properties.Name -contains "qualityReport") {
    $quality = $gate.qualityReport
    foreach ($name in @("path", "stage", "requiredChecks")) {
      if (-not ($quality.PSObject.Properties.Name -contains $name)) { $errors += "Gate $($gateProperty.Name) qualityReport is missing $name" }
    }
    if (($quality.PSObject.Properties.Name -contains "requiredChecks") -and @($quality.requiredChecks).Count -eq 0) { $errors += "Gate $($gateProperty.Name) qualityReport has no required checks" }
  }
  if ($gate.PSObject.Properties.Name -contains "artManifest") {
    $art = $gate.artManifest
    foreach ($name in @("path", "requiredFor", "minimumStatus")) {
      if (-not ($art.PSObject.Properties.Name -contains $name)) { $errors += "Gate $($gateProperty.Name) artManifest is missing $name" }
    }
  }
  if ($gate.PSObject.Properties.Name -contains "codeAudit") {
    $audit = $gate.codeAudit
    if (-not ($audit.PSObject.Properties.Name -contains "path")) { $errors += "Gate $($gateProperty.Name) codeAudit is missing path" }
  }
}
if ($errors.Count -gt 0) { throw ($errors -join "`n") }

$lines = @(
  "# MLGS Command Index",
  "",
  '> Generated from `workflow/catalog.json` plus its phase/gate catalogs. Do not edit by hand.',
  "",
  'MLGS publicly exposes only `/mlgs`; the Producer selects one internal route.',
  "",
  "| Route | Lead | Supporting | Intent examples |",
  "|---|---|---|---|"
)
foreach ($command in $catalog.commands) {
  $supports = @(Get-MLGSOptionalArray -Object $command -Name "support" | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
  $support = if ($supports.Count -gt 0) { $supports -join ", " } else { "-" }
  $intents = @($command.intents) -join ", "
  $lines += ('| `{0}` | {1} | {2} | {3} |' -f $command.id, $command.lead, $support, $intents)
}
$lines += @("", "## Phases", "", "| Phase | Lead | Gate | Routes |", "|---|---|---|---|")
foreach ($phase in $catalog.phases) {
  $phaseCommands = @($phase.commands) -join ", "
  $lines += ('| {0} | {1} | {2} | {3} |' -f $phase.id, $phase.lead, $phase.gate, $phaseCommands)
}
$modeRows = @()
foreach ($command in $catalog.commands) {
  foreach ($mode in @(Get-MLGSOptionalArray -Object $command -Name "modes")) {
    $modeRows += ('| `{0}` | `{1}` | {2} | {3} |' -f $command.id, $mode.id, [bool]$mode.default, (@($mode.intents) -join ", "))
  }
}
if ($modeRows.Count -gt 0) {
  $lines += @("", "## Route Modes", "", "| Route | Mode | Default | Intent examples |", "|---|---|---|---|")
  $lines += $modeRows
}
$content = ($lines -join "`r`n") + "`r`n"
$outputPath = Join-Path $Root "workflow/command-index.md"
if ($Check) {
  if (-not (Test-Path $outputPath)) { throw "Generated command index is missing." }
  $actual = Get-Content -LiteralPath $outputPath -Raw -Encoding UTF8
  if ($actual.Replace("`r`n", "`n") -ne $content.Replace("`r`n", "`n")) { throw "workflow/command-index.md is stale. Run tools/generate-workflow.ps1." }
} else {
  Set-Content -LiteralPath $outputPath -Value $content -Encoding UTF8 -NoNewline
}

[pscustomobject]@{ status = "passed"; check = [bool]$Check; output_path = $outputPath; command_count = $catalog.commands.Count; mode_count = $modeRows.Count } | ConvertTo-Json
