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

function Read-StateValue {
  param([string]$Content, [string]$Key)

  $match = [regex]::Match($Content, "(?m)^\s*$([regex]::Escape($Key))\s*:\s*[""']?([^""'\r\n#]+)")
  if ($match.Success) {
    return $match.Groups[1].Value.Trim()
  }

  return ""
}

function Read-ListBlock {
  param([string]$Content, [string]$Key)

  $items = @()
  $lines = $Content -split "`r?`n"
  $inBlock = $false
  foreach ($line in $lines) {
    if ($line -match "^\s*$([regex]::Escape($Key))\s*:\s*\[\]\s*$") {
      return @()
    }
    if ($line -match "^\s*$([regex]::Escape($Key))\s*:\s*$") {
      $inBlock = $true
      continue
    }
    if ($inBlock) {
      if ($line -match "^\s*-\s*[""']?([^""']+)[""']?\s*$") {
        $items += $matches[1].Trim()
        continue
      }
      if ($line -match "^\S") {
        break
      }
    }
  }

  return @($items)
}

function Get-NextOptions {
  param(
    [string]$Mode,
    $Detection,
    [string]$NextCommand
  )

  if ($Mode -eq "template") {
    return @(
      [pscustomobject]@{ key = "A"; command = "/mlgs start"; label = "New game"; description = "Start from a blank or rough idea." },
      [pscustomobject]@{ key = "B"; command = "/mlgs adopt <path>"; label = "Existing Unity project"; description = "Attach and inspect a project folder." },
      [pscustomobject]@{ key = "C"; command = "/mlgs help"; label = "Command menu"; description = "Show available commands." }
    )
  }

  if (-not $Detection.artifacts.concept) {
    return @(
      [pscustomobject]@{ key = "A"; command = "/mlgs brainstorm"; label = "Create concept"; description = "Pitch, fantasy, pillars, MVP scope." },
      [pscustomobject]@{ key = "B"; command = "/mlgs adopt"; label = "Inspect adoption gaps"; description = "Re-run project gap analysis." },
      [pscustomobject]@{ key = "C"; command = "/mlgs dashboard"; label = "Open dashboard"; description = "See staff activity." }
    )
  }

  if (-not $Detection.artifacts.design_plan) {
    return @(
      [pscustomobject]@{ key = "A"; command = "/mlgs plan"; label = "Plan systems"; description = "Create systems, tech plan, and tasks." },
      [pscustomobject]@{ key = "B"; command = "/mlgs review design"; label = "Review concept"; description = "Check concept before planning." },
      [pscustomobject]@{ key = "C"; command = "/mlgs dashboard"; label = "Open dashboard"; description = "See staff activity." }
    )
  }

  if (-not $Detection.artifacts.prototype) {
    return @(
      [pscustomobject]@{ key = "A"; command = "/mlgs prototype"; label = "Validate prototype"; description = "Build or skip with recorded risk." },
      [pscustomobject]@{ key = "B"; command = "/mlgs implement"; label = "Implement with risk"; description = "Proceed only if the owner accepts prototype risk." },
      [pscustomobject]@{ key = "C"; command = "/mlgs test"; label = "Define checks"; description = "Prepare QA before production." }
    )
  }

  return @(
    [pscustomobject]@{ key = "A"; command = "/mlgs implement"; label = "Implement next task"; description = "Pick or execute a production task." },
    [pscustomobject]@{ key = "B"; command = "/mlgs test"; label = "Verify"; description = "Run compile/smoke/QA checks." },
    [pscustomobject]@{ key = "C"; command = "/mlgs build"; label = "Build"; description = "Run build preflight or produce a build." },
    [pscustomobject]@{ key = "D"; command = "/mlgs review"; label = "Review"; description = "Review readiness or code health." }
  )
}

$resolverPath = Join-Path $Root "tools/resolve-state.ps1"
$detectPath = Join-Path $Root "tools/detect-project-stage.ps1"
$runtimePath = Join-Path $Root "studio/runtime.json"
$activityPath = Join-Path $Root "studio/logs/activity.jsonl"

$resolveArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $resolverPath, "-Root", $Root)
if (-not [string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $resolveArgs += @("-ProjectRoot", $ProjectRoot)
}
if (-not [string]::IsNullOrWhiteSpace($StatePath)) {
  $resolveArgs += @("-StatePath", $StatePath)
}
if ($AllowTemplate) {
  $resolveArgs += "-AllowTemplate"
}

$resolved = & powershell @resolveArgs | ConvertFrom-Json

$stateContent = ""
if ($resolved.exists -and (Test-Path $resolved.state_path)) {
  $stateContent = Get-Content -Raw -Encoding UTF8 -LiteralPath $resolved.state_path
}

$phase = Read-StateValue $stateContent "current"
switch ($phase) {
  "idea-alignment" { $phase = "intake" }
  "concept-package" { $phase = "concept" }
  "design-tech-plan" { $phase = "plan" }
  "prototype-validation" { $phase = "prototype" }
  "polish-ship" { $phase = "release" }
}

$participation = Read-StateValue $stateContent "level"
if ([string]::IsNullOrWhiteSpace($participation)) {
  $participation = "medium"
}

$nextCommand = Read-StateValue $stateContent "command"
if ([string]::IsNullOrWhiteSpace($nextCommand)) {
  $nextCommand = "start"
}

$detection = $null
if ($resolved.project_exists -and $resolved.mode -ne "template" -and (Test-Path $detectPath)) {
  $detection = & powershell -NoProfile -ExecutionPolicy Bypass -File $detectPath -Root $Root -ProjectRoot $resolved.project_root | ConvertFrom-Json
}

if ($null -eq $detection) {
  $detection = [pscustomobject]@{
    artifacts = [pscustomobject]@{
      references = $false
      concept = $false
      design_plan = $false
      prototype = $false
      production_plan = $false
      tests = $false
    }
    gaps = @("No active project is configured.")
    counts = [pscustomobject]@{
      design_files = 0
      docs_files = 0
      source_files = 0
      asset_files = 0
    }
  }
}

$runtime = $null
if (Test-Path $runtimePath) {
  try {
    $runtime = Get-Content -Raw -Encoding UTF8 -LiteralPath $runtimePath | ConvertFrom-Json
  } catch {
  }
}

$latestEvents = @()
if (Test-Path $activityPath) {
  $lines = Get-Content -Encoding UTF8 -LiteralPath $activityPath | Where-Object { $_.Trim().Length -gt 0 } | Select-Object -Last 5
  foreach ($line in $lines) {
    try {
      $latestEvents += ($line | ConvertFrom-Json)
    } catch {
    }
  }
}

$completedArtifacts = @()
foreach ($property in $detection.artifacts.PSObject.Properties) {
  if ($property.Value -eq $true) {
    $completedArtifacts += $property.Name
  }
}

$missingArtifacts = @()
foreach ($property in $detection.artifacts.PSObject.Properties) {
  if ($property.Value -ne $true) {
    $missingArtifacts += $property.Name
  }
}

[pscustomobject]@{
  resolved = $resolved
  active_project = [pscustomobject]@{
    name = $(Read-StateValue $stateContent "name")
    phase = $phase
    owner_participation = $participation
    project_root = $resolved.project_root
    state_path = $resolved.state_path
    mode = $(Read-StateValue $stateContent "mode")
    unity_version = $(Read-StateValue $stateContent "engine_version")
  }
  approvals = [pscustomobject]@{
    project_selected = $(Read-StateValue $stateContent "project_selected")
    concept_package = $(Read-StateValue $stateContent "concept_package")
    design_tech_plan = $(Read-StateValue $stateContent "design_tech_plan")
    prototype_validation = $(Read-StateValue $stateContent "prototype_validation")
    production_unblocked = $(Read-StateValue $stateContent "production_unblocked")
  }
  prototype = [pscustomobject]@{
    policy = $(Read-StateValue $stateContent "policy")
    verdict = $(Read-StateValue $stateContent "verdict")
    skip_reason = $(Read-StateValue $stateContent "skip_reason")
  }
  artifacts = $detection.artifacts
  counts = $detection.counts
  completed_artifacts = $completedArtifacts
  missing_artifacts = $missingArtifacts
  gaps = @($detection.gaps)
  risks = @(Read-ListBlock $stateContent "risks")
  assumptions = @(Read-ListBlock $stateContent "assumptions")
  next_command = $nextCommand
  next_options = @(Get-NextOptions $resolved.mode $detection $nextCommand)
  latest_activity = $latestEvents
  runtime_summary = $(if ($runtime) { $runtime.summary } else { "" })
} | ConvertTo-Json -Depth 12
