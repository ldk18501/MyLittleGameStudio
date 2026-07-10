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

  $results += Invoke-Step "check-template-state" {
    $check = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/check-state.ps1") -Root $Root -RuntimeRoot $runtimeRoot | ConvertFrom-Json
    if ($check.status -ne "passed") { throw "Template state check failed." }
  }

  $results += Invoke-Step "detect-complete-unity-project" {
    $detected = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/detect-project-stage.ps1") -Root $Root -ProjectRoot $project -RuntimeRoot $runtimeRoot | ConvertFrom-Json
    if (-not $detected.is_unity_project -or $detected.is_partial_unity_project -or $detected.recommended_command -ne "adopt") { throw "Unity detection is incorrect." }
  }

  $results += Invoke-Step "adopt-isolated-project" {
    $adopted = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/adopt-project.ps1") -Root $Root -ProjectRoot $project -Name "Colon: Smoke" -OwnerParticipation high -ApprovedWritePaths Assets -RuntimeRoot $runtimeRoot -Apply | ConvertFrom-Json
    if (-not (Test-Path $adopted.apply_result.state_path)) { throw "Adoption did not create state.json." }
    if (-not (Test-Path (Join-Path $runtimeRoot "current-project.json"))) { throw "Isolated pointer was not written." }
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
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/preflight-task.ps1") -Root $Root -Command implement -ProjectRoot $project -RuntimeRoot $runtimeRoot | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Unlocked production did not pass preflight." }
    $valid = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/validate-changes.ps1") -Root $Root -ProjectRoot $project -RuntimeRoot $runtimeRoot -ChangedPaths "Assets/Scripts/PlayerController.cs","production/task-plan.md" | ConvertFrom-Json
    if (-not $valid.valid) { throw "Approved paths were rejected." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/validate-changes.ps1") -Root $Root -ProjectRoot $project -RuntimeRoot $runtimeRoot -ChangedPaths "ProjectSettings/ProjectSettings.asset" 2>$null | Out-Null
    if ($LASTEXITCODE -ne 3) { throw "Out-of-bound path was not rejected." }
  }

  $results += Invoke-Step "formal-art-pipeline" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/init-art-pipeline.ps1") -Root $Root -ProjectRoot $project | Out-Null
    foreach ($relative in @(
      "Assets/Art/Source/hero.png",
      "Assets/Art/Sprites/hero.png",
      "production/assets/prompts/hero.json",
      "production/assets/import-recipes/hero.json",
      "production/assets/reviews/hero-game-view.png",
      "Assets/Prefabs/Hero.prefab"
    )) {
      $path = Join-Path $project $relative
      New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
      Set-Content -LiteralPath $path -Value "smoke" -Encoding UTF8
    }
    $manifestPath = Join-Path $project "production/assets/asset-manifest.json"
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $manifest.assets = @([pscustomobject]@{
      id = "hero"
      kind = "sprite"
      usage = "Hero presentation"
      requiredFor = "vertical-slice"
      sourceType = "generated"
      source = "smoke/provider"
      license = "project-owned/generated"
      promptMetadata = "production/assets/prompts/hero.json"
      sourceFile = "Assets/Art/Source/hero.png"
      outputPath = "Assets/Art/Sprites/hero.png"
      status = "approved"
      placeholder = $false
      importRecipe = "production/assets/import-recipes/hero.json"
      references = @("Assets/Prefabs/Hero.prefab")
      evidence = @("production/assets/reviews/hero-game-view.png")
    })
    Write-MLGSJsonAtomic -Path $manifestPath -Value $manifest
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/validate-art-manifest.ps1") -Root $Root -ProjectRoot $project -RequiredFor vertical-slice -MinimumStatus approved -DisallowPlaceholders | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Approved art manifest did not pass." }
    $manifest.assets[0].placeholder = $true
    Write-MLGSJsonAtomic -Path $manifestPath -Value $manifest
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/validate-art-manifest.ps1") -Root $Root -ProjectRoot $project -RequiredFor vertical-slice -MinimumStatus approved -DisallowPlaceholders 2>$null | Out-Null
    if ($LASTEXITCODE -ne 4) { throw "Placeholder art passed a final-art gate." }
    $manifest.assets[0].placeholder = $false
    Write-MLGSJsonAtomic -Path $manifestPath -Value $manifest
  }

  $results += Invoke-Step "structured-quality-gate" {
    $created = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/new-quality-gate.ps1") -Root $Root -ProjectRoot $project -Stage vertical-slice | ConvertFrom-Json
    $report = Get-Content -LiteralPath $created.report_path -Raw -Encoding UTF8 | ConvertFrom-Json
    $report.verdict = "pass"
    $report.ownerApproval = $true
    $report.updated = (Get-Date).ToString("o")
    foreach ($check in $report.checks) {
      $check.status = "pass"
      $check.evidence = @("manual:isolated-smoke")
    }
    Write-MLGSJsonAtomic -Path $created.report_path -Value $report
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-quality-gate.ps1") -Root $Root -ProjectRoot $project -Stage vertical-slice | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Complete structured quality gate did not pass." }
    $report.checks[0].status = "pending"
    Write-MLGSJsonAtomic -Path $created.report_path -Value $report
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-quality-gate.ps1") -Root $Root -ProjectRoot $project -Stage vertical-slice 2>$null | Out-Null
    if ($LASTEXITCODE -ne 5) { throw "Incomplete structured quality gate passed." }
    $report.checks[0].status = "pass"
    Write-MLGSJsonAtomic -Path $created.report_path -Value $report
    $orderedStatus = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/get-project-status.ps1") -Root $Root -ProjectRoot $project -RuntimeRoot $runtimeRoot | ConvertFrom-Json
    if ($orderedStatus.active_project.observed_phase -ne "concept") { throw "Later quality evidence skipped an earlier phase gate." }
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
    $trace = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/trace.ps1") -Root $Root -RuntimeRoot $runtimeRoot -Command test -Title "Isolated smoke trace" -LeadAgent qa-lead -AgentsUsed qa-lead,producer -Verification "isolated" -Summary "Smoke trace"
    if (($trace -join "`n") -notmatch "Trace recorded") { throw "Trace did not complete." }
    if (-not (Test-Path (Join-Path $runtimeRoot "dashboard/studio-data.js"))) { throw "Dashboard was not exported to the isolated runtime." }
  }

  $results += Invoke-Step "plugin-package-is-self-contained" {
    $pluginRoot = Join-Path $Root "plugins/my-little-game-studio"
    foreach ($relative in @("AGENTS.md", "workflow/catalog.json", "commands/status.md", "tools/resolve-state.ps1", "studio/state.json", "dashboard/index.html")) {
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
