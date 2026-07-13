param(
  [string]$Root = "",
  [string]$RuntimeRoot = "",
  [string]$DashboardRoot = "",
  [Parameter(Mandatory = $true)][string]$Command,
  [Parameter(Mandatory = $true)][string]$Title,
  [ValidateSet("started", "completed", "partial", "blocked")][string]$Status = "completed",
  [string]$LeadAgent = "producer",
  [string[]]$AgentsUsed = @("producer"),
  [string[]]$SkillsUsed = @(),
  [string[]]$FilesRead = @(),
  [string[]]$FilesWritten = @(),
  [string[]]$Assumptions = @(),
  [string[]]$Decisions = @(),
  [string[]]$Verification = @(),
  [string]$Summary = ""
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$runtimeWasExplicit = -not [string]::IsNullOrWhiteSpace($RuntimeRoot)
$RuntimeRoot = Get-MLGSRuntimeRoot -Root $Root -RuntimeRoot $RuntimeRoot
$isPluginRoot = Test-Path (Join-Path $Root ".codex-plugin/plugin.json")
if ([string]::IsNullOrWhiteSpace($DashboardRoot)) {
  $DashboardRoot = if ($runtimeWasExplicit -or $isPluginRoot) { Join-Path $RuntimeRoot "dashboard" } else { Join-Path $Root "dashboard" }
}
$logsDir = Join-Path $RuntimeRoot "logs"
New-Item -ItemType Directory -Path $logsDir -Force | Out-Null

function Expand-Values {
  param([string[]]$Values)
  $result = @()
  foreach ($value in $Values) {
    if ($null -eq $value) { continue }
    foreach ($part in ($value -split ",")) {
      if ($part.Trim()) { $result += $part.Trim() }
    }
  }
  return @($result | Select-Object -Unique)
}

function ConvertTo-AgentId {
  param([string]$Value)
  return (($Value.Trim().ToLowerInvariant() -replace "[^a-z0-9]+", "-").Trim("-"))
}

function New-AgentRoster {
  return @(
    [pscustomobject]@{ id = "producer"; name = "Producer"; role = "Production, scope, risk, task flow"; status = "idle"; lastEvent = ""; currentTask = "" },
    [pscustomobject]@{ id = "creative-director"; name = "Creative Director"; role = "Vision, pillars, references, scope focus"; status = "idle"; lastEvent = ""; currentTask = "" },
    [pscustomobject]@{ id = "art-director"; name = "Art Director"; role = "Visual target, style consistency, final visual approval"; status = "idle"; lastEvent = ""; currentTask = "" },
    [pscustomobject]@{ id = "game-designer"; name = "Game Designer"; role = "Systems, rules, tuning, acceptance"; status = "idle"; lastEvent = ""; currentTask = "" },
    [pscustomobject]@{ id = "unity-architect"; name = "Unity Architect"; role = "Unity architecture, packages, build risk"; status = "idle"; lastEvent = ""; currentTask = "" },
    [pscustomobject]@{ id = "gameplay-developer"; name = "Gameplay Developer"; role = "Focused Unity/C# gameplay tasks"; status = "idle"; lastEvent = ""; currentTask = "" },
    [pscustomobject]@{ id = "ui-ux-developer"; name = "UI/UX Developer"; role = "Runtime UI, HUD, input ergonomics"; status = "idle"; lastEvent = ""; currentTask = "" },
    [pscustomobject]@{ id = "technical-artist"; name = "Technical Artist"; role = "Shaders, VFX, assets, visual perf"; status = "idle"; lastEvent = ""; currentTask = "" },
    [pscustomobject]@{ id = "qa-lead"; name = "QA Lead"; role = "Verification, evidence, readiness"; status = "idle"; lastEvent = ""; currentTask = "" }
  )
}

function Get-ProjectSnapshot {
  $snapshot = [pscustomobject]@{ name = ""; phase = ""; participation = ""; nextCommand = ""; projectRoot = "" }
  try {
    $resolved = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/resolve-state.ps1") -Root $Root -RuntimeRoot $RuntimeRoot -AllowTemplate | ConvertFrom-Json
    $snapshot.projectRoot = $resolved.project_root
    if ($resolved.exists -and $resolved.mode -ne "template") {
      $state = Import-MLGSState -Path $resolved.state_path
      $gate = Get-MLGSGateEvaluation -Root $Root -ProjectRoot $resolved.project_root -State $state
      $snapshot.name = $state.activeProject.name
      $snapshot.phase = $gate.observedPhase
      $snapshot.participation = $state.ownerParticipation.level
      $snapshot.nextCommand = $gate.recommendedCommand
    }
  } catch { }
  return $snapshot
}

$AgentsUsed = Expand-Values $AgentsUsed
$SkillsUsed = Expand-Values $SkillsUsed
$FilesRead = Expand-Values $FilesRead
$FilesWritten = Expand-Values $FilesWritten
$agentIds = @($AgentsUsed | ForEach-Object { ConvertTo-AgentId $_ })
$leadId = ConvertTo-AgentId $LeadAgent
if ($agentIds -notcontains $leadId) { $agentIds = @($leadId) + $agentIds }
$agentIds = @($agentIds | Select-Object -Unique)
$timestamp = (Get-Date).ToString("o")
$event = [ordered]@{
  id = ((Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss") + "-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
  timestamp = $timestamp
  command = $Command
  title = $Title
  status = $Status
  leadAgent = $leadId
  agentsUsed = $agentIds
  skillsUsed = @($SkillsUsed)
  filesRead = @($FilesRead)
  filesWritten = @($FilesWritten)
  assumptions = @($Assumptions | Where-Object { $_ })
  decisions = @($Decisions | Where-Object { $_ })
  verification = @($Verification | Where-Object { $_ })
  summary = $Summary
}

$lockPath = Join-Path $RuntimeRoot ".trace.lock"
$lock = $null
for ($attempt = 0; $attempt -lt 50 -and $null -eq $lock; $attempt++) {
  try { $lock = [System.IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None') } catch { Start-Sleep -Milliseconds 100 }
}
if ($null -eq $lock) { throw "Could not acquire MLGS trace lock." }
try {
  $activityPath = Join-Path $logsDir "activity.jsonl"
  Add-Content -LiteralPath $activityPath -Value ($event | ConvertTo-Json -Depth 20 -Compress) -Encoding UTF8
  $runtimePath = Join-Path $RuntimeRoot "runtime.json"
  $runtime = if (Test-Path $runtimePath) { Get-Content -LiteralPath $runtimePath -Raw -Encoding UTF8 | ConvertFrom-Json } else {
    [pscustomobject]@{ version = "0.2"; updated = ""; activeCommand = ""; activeTask = ""; summary = ""; project = $null; agents = (New-AgentRoster); latestEvents = @() }
  }
  $roster = @(New-AgentRoster)
  foreach ($agent in $roster) {
    $old = @($runtime.agents | Where-Object { $_.id -eq $agent.id }) | Select-Object -First 1
    if ($old) {
      $agent.status = $old.status; $agent.lastEvent = $old.lastEvent; $agent.currentTask = $old.currentTask
    }
    if ($agentIds -contains $agent.id) {
      $agent.status = if ($Status -eq "started") { "active" } else { $Status }
      $agent.lastEvent = $timestamp
      $agent.currentTask = $Title
    } elseif ($Status -ne "started" -and $agent.status -eq "active") {
      $agent.status = "idle"; $agent.currentTask = ""
    }
  }
  $recent = @()
  foreach ($line in @(Get-Content -LiteralPath $activityPath -Encoding UTF8 | Where-Object { $_.Trim() } | Select-Object -Last 10)) {
    try { $recent += ($line | ConvertFrom-Json) } catch { }
  }
  $runtime = [ordered]@{
    version = "0.2"
    updated = $timestamp
    activeCommand = $(if ($Status -eq "started") { $Command } else { "" })
    activeTask = $(if ($Status -eq "started") { $Title } else { "" })
    summary = $Summary
    project = Get-ProjectSnapshot
    agents = $roster
    latestEvents = $recent
  }
  Write-MLGSJsonAtomic -Path $runtimePath -Value $runtime
} finally {
  $lock.Dispose()
  if (Test-Path $lockPath) { Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue }
}

$exportArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/export-dashboard.ps1"), "-Root", $Root, "-RuntimeRoot", $RuntimeRoot, "-DashboardRoot", $DashboardRoot)
$dashboard = & powershell @exportArgs | ConvertFrom-Json
Write-Output "Trace recorded: $($event.id)"
Write-Output "Dashboard: $($dashboard.output_path)"
