param(
  [string]$Root = "",
  [string]$ProjectRoot = "",
  [string]$StatePath = "",
  [string]$ContextPath = "",
  [string]$RuntimeRoot = "",
  [string]$DashboardRoot = "",
  [Parameter(Mandatory = $true)][string]$Command,
  [Parameter(Mandatory = $true)][string]$Title,
  [ValidateSet("started", "completed", "partial", "blocked")][string]$Status = "completed",
  [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')][string]$InvocationId = "",
  [string]$TaskId = "",
  [string]$LeadAgent = "producer",
  [string[]]$AgentsUsed = @("producer"),
  [string[]]$SkillsUsed = @(),
  [string[]]$FilesRead = @(),
  [string[]]$FilesWritten = @(),
  [string[]]$Assumptions = @(),
  [string[]]$Decisions = @(),
  [string[]]$Verification = @(),
  [string]$Summary = "",
  [switch]$AllowUnbound
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")

$resolveArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/resolve-state.ps1"), "-Root", $Root, "-AllowTemplate")
if ($ProjectRoot) { $resolveArgs += @("-ProjectRoot", $ProjectRoot) }
if ($StatePath) { $resolveArgs += @("-StatePath", $StatePath) }
if ($ContextPath) { $resolveArgs += @("-ContextPath", $ContextPath) }
if ($RuntimeRoot) { $resolveArgs += @("-RuntimeRoot", $RuntimeRoot) }
if (-not $AllowUnbound) { $resolveArgs += "-RequireProjectContext" }
$resolved = & powershell @resolveArgs | ConvertFrom-Json
if (-not $AllowUnbound -and (-not $resolved.exists -or -not [bool]$resolved.context_safe)) {
  throw "Trace requires a bound project context. $($resolved.context_reason)"
}
if ($resolved.context_invocation_id) {
  if ($InvocationId -and $InvocationId -ne [string]$resolved.context_invocation_id) { throw "Trace invocationId does not match the bound project context." }
  $InvocationId = [string]$resolved.context_invocation_id
  if (-not $TaskId) { $TaskId = [string]$resolved.context_task_id }
}
if ([string]::IsNullOrWhiteSpace($InvocationId)) {
  $InvocationId = (Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss") + "-" + [guid]::NewGuid().ToString("N").Substring(0, 10)
}

$projectRuntimeRoot = [System.IO.Path]::GetFullPath([string]$resolved.project_runtime_root)
if ([string]::IsNullOrWhiteSpace($DashboardRoot)) { $DashboardRoot = Join-Path $projectRuntimeRoot "dashboard" }
$logsDir = Join-Path $projectRuntimeRoot "logs"
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
  $snapshot = [pscustomobject]@{ id = [string]$resolved.project_id; name = ""; phase = ""; participation = ""; nextCommand = ""; projectRoot = [string]$resolved.project_root; statePath = [string]$resolved.state_path }
  try {
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
$projectSnapshot = Get-ProjectSnapshot
$event = [ordered]@{
  id = ((Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss") + "-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
  timestamp = $timestamp
  invocationId = $InvocationId
  taskId = $TaskId
  projectId = [string]$resolved.project_id
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
  project = $projectSnapshot
}

$lockPath = Join-Path $projectRuntimeRoot ".trace.lock"
$lock = $null
New-Item -ItemType Directory -Path $projectRuntimeRoot -Force | Out-Null
for ($attempt = 0; $attempt -lt 50 -and $null -eq $lock; $attempt++) {
  try { $lock = [System.IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None') } catch { Start-Sleep -Milliseconds 100 }
}
if ($null -eq $lock) { throw "Could not acquire MLGS trace lock for project $($resolved.project_id)." }
try {
  $activityPath = Join-Path $logsDir "activity.jsonl"
  Add-Content -LiteralPath $activityPath -Value ($event | ConvertTo-Json -Depth 20 -Compress) -Encoding UTF8
  $runtimePath = Join-Path $projectRuntimeRoot "runtime.json"
  $runtime = if (Test-Path $runtimePath) { Get-Content -LiteralPath $runtimePath -Raw -Encoding UTF8 | ConvertFrom-Json } else {
    [pscustomobject]@{ version = "0.3"; updated = ""; activeCommand = ""; activeTask = ""; activeTasks = @(); summary = ""; project = $null; agents = (New-AgentRoster); latestEvents = @() }
  }
  $activeTasks = @()
  if ($runtime.PSObject.Properties.Name -contains "activeTasks") { $activeTasks = @($runtime.activeTasks | Where-Object { $_.invocationId -ne $InvocationId }) }
  if ($Status -eq "started") {
    $activeTasks += [pscustomobject]@{ invocationId = $InvocationId; taskId = $TaskId; command = $Command; title = $Title; leadAgent = $leadId; agentsUsed = $agentIds; startedAt = $timestamp }
  }
  $roster = @(New-AgentRoster)
  foreach ($agent in $roster) {
    $matchingTasks = @($activeTasks | Where-Object { @($_.agentsUsed) -contains $agent.id })
    if ($matchingTasks.Count -gt 0) {
      $latestTask = $matchingTasks | Select-Object -Last 1
      $agent.status = "active"
      $agent.lastEvent = [string]$latestTask.startedAt
      $agent.currentTask = [string]$latestTask.title
    } elseif ($agentIds -contains $agent.id) {
      $agent.status = $Status
      $agent.lastEvent = $timestamp
      $agent.currentTask = $Title
    }
  }
  $recent = @()
  foreach ($line in @(Get-Content -LiteralPath $activityPath -Encoding UTF8 | Where-Object { $_.Trim() } | Select-Object -Last 10)) {
    try { $recent += ($line | ConvertFrom-Json) } catch { }
  }
  $primaryTask = @($activeTasks) | Select-Object -First 1
  $runtime = [ordered]@{
    version = "0.3"
    updated = $timestamp
    activeCommand = $(if ($primaryTask) { [string]$primaryTask.command } else { "" })
    activeTask = $(if ($primaryTask) { [string]$primaryTask.title } else { "" })
    activeTasks = @($activeTasks)
    summary = $Summary
    project = $projectSnapshot
    agents = $roster
    latestEvents = $recent
  }
  Write-MLGSJsonAtomic -Path $runtimePath -Value $runtime
} finally {
  $lock.Dispose()
  if (Test-Path $lockPath) { Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue }
}

$exportArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/export-dashboard.ps1"), "-Root", $Root, "-RuntimeRoot", [string]$resolved.global_runtime_root, "-DashboardRoot", $DashboardRoot)
if ([bool]$resolved.context_safe) { $exportArgs += @("-ProjectRoot", [string]$resolved.project_root) }
if ($resolved.context_path) { $exportArgs += @("-ContextPath", [string]$resolved.context_path) }
$dashboard = & powershell @exportArgs | ConvertFrom-Json
Write-Output "Trace recorded: $($event.id)"
Write-Output "Invocation: $InvocationId"
Write-Output "Project: $($resolved.project_id)"
Write-Output "Dashboard: $($dashboard.output_path)"
