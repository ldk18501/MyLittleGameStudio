param([string]$Root = "", [switch]$Check)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
$catalogPath = Join-Path $Root "workflow/catalog.json"
$catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json

$errors = @()
foreach ($command in $catalog.commands) {
  if (-not (Test-Path (Join-Path $Root $command.file))) { $errors += "Missing command file: $($command.file)" }
  if (-not (Test-Path (Join-Path $Root ("agents/" + $command.lead + ".md")))) { $errors += "Missing lead agent: $($command.lead)" }
  $supports = @($command.support | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
  foreach ($support in $supports) {
    if (-not (Test-Path (Join-Path $Root ("agents/" + $support + ".md")))) { $errors += "Missing supporting agent: $support" }
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
  '> Generated from `workflow/catalog.json`. Do not edit by hand.',
  "",
  'MLGS publicly exposes only `/mlgs`; the Producer selects one internal route.',
  "",
  "| Route | Lead | Supporting | Intent examples |",
  "|---|---|---|---|"
)
foreach ($command in $catalog.commands) {
  $supports = @($command.support | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
  $support = if ($supports.Count -gt 0) { $supports -join ", " } else { "-" }
  $intents = @($command.intents) -join ", "
  $lines += ('| `{0}` | {1} | {2} | {3} |' -f $command.id, $command.lead, $support, $intents)
}
$lines += @("", "## Phases", "", "| Phase | Lead | Gate | Routes |", "|---|---|---|---|")
foreach ($phase in $catalog.phases) {
  $phaseCommands = @($phase.commands) -join ", "
  $lines += ('| {0} | {1} | {2} | {3} |' -f $phase.id, $phase.lead, $phase.gate, $phaseCommands)
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

[pscustomobject]@{ status = "passed"; check = [bool]$Check; output_path = $outputPath; command_count = $catalog.commands.Count } | ConvertTo-Json
