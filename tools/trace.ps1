param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)]
  [string]$Command,
  [Parameter(Mandatory = $true)]
  [string]$Title,
  [ValidateSet("started", "completed", "partial", "blocked")]
  [string]$Status = "completed",
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

function ConvertTo-AgentId {
  param([string]$Name)

  $clean = $Name.Trim().ToLowerInvariant()
  switch ($clean) {
    "producer" { return "producer" }
    "creative director" { return "creative-director" }
    "creative-director" { return "creative-director" }
    "game designer" { return "game-designer" }
    "game-designer" { return "game-designer" }
    "unity architect" { return "unity-architect" }
    "unity-architect" { return "unity-architect" }
    "gameplay developer" { return "gameplay-developer" }
    "gameplay-developer" { return "gameplay-developer" }
    "ui/ux developer" { return "ui-ux-developer" }
    "ui ux developer" { return "ui-ux-developer" }
    "ui-ux-developer" { return "ui-ux-developer" }
    "technical artist" { return "technical-artist" }
    "technical-artist" { return "technical-artist" }
    "qa lead" { return "qa-lead" }
    "qa-lead" { return "qa-lead" }
    default { return ($clean -replace "[^a-z0-9]+", "-").Trim("-") }
  }
}

function Expand-CommaList {
  param([string[]]$Values)

  $expanded = @()
  foreach ($value in $Values) {
    if ($null -eq $value) {
      continue
    }

    foreach ($part in ($value -split ",")) {
      $trimmed = $part.Trim()
      if ($trimmed.Length -gt 0) {
        $expanded += $trimmed
      }
    }
  }

  return @($expanded | Select-Object -Unique)
}

function Normalize-TextList {
  param([string[]]$Values)

  $normalized = @()
  foreach ($value in $Values) {
    if ($null -eq $value) {
      continue
    }

    $trimmed = $value.Trim()
    if ($trimmed.Length -gt 0) {
      $normalized += $trimmed
    }
  }

  return @($normalized)
}

function New-AgentRoster {
  return @(
    [pscustomobject]@{ id = "producer"; name = "Producer"; role = "Coordination, routing, scope, state"; status = "idle"; lastEvent = ""; currentTask = "" },
    [pscustomobject]@{ id = "creative-director"; name = "Creative Director"; role = "Game vision, references, creative direction"; status = "idle"; lastEvent = ""; currentTask = "" },
    [pscustomobject]@{ id = "game-designer"; name = "Game Designer"; role = "Rules, systems, tuning, acceptance criteria"; status = "idle"; lastEvent = ""; currentTask = "" },
    [pscustomobject]@{ id = "unity-architect"; name = "Unity Architect"; role = "Unity structure, technical plan, build risk"; status = "idle"; lastEvent = ""; currentTask = "" },
    [pscustomobject]@{ id = "gameplay-developer"; name = "Gameplay Developer"; role = "Gameplay code and production implementation"; status = "idle"; lastEvent = ""; currentTask = "" },
    [pscustomobject]@{ id = "ui-ux-developer"; name = "UI/UX Developer"; role = "Interface, interaction, readability"; status = "idle"; lastEvent = ""; currentTask = "" },
    [pscustomobject]@{ id = "technical-artist"; name = "Technical Artist"; role = "Visual systems, VFX, generated art, performance"; status = "idle"; lastEvent = ""; currentTask = "" },
    [pscustomobject]@{ id = "qa-lead"; name = "QA Lead"; role = "Verification, risks, release checks"; status = "idle"; lastEvent = ""; currentTask = "" }
  )
}

function Read-StateValue {
  param([string]$Content, [string]$Key)

  $match = [regex]::Match($Content, "(?m)^\s*$([regex]::Escape($Key))\s*:\s*[""']?([^""'\r\n#]+)")
  if ($match.Success) {
    return $match.Groups[1].Value.Trim()
  }

  return ""
}

function Get-ProjectSnapshot {
  param([string]$RootPath)

  $resolverPath = Join-Path $RootPath "tools/resolve-state.ps1"
  $snapshot = [pscustomobject]@{
    name = ""
    phase = ""
    participation = ""
    nextCommand = ""
    projectRoot = ""
  }

  if (-not (Test-Path $resolverPath)) {
    return $snapshot
  }

  try {
    $resolved = & powershell -NoProfile -ExecutionPolicy Bypass -File $resolverPath -Root $RootPath -AllowTemplate | ConvertFrom-Json
    $snapshot.projectRoot = $resolved.project_root
    if ($resolved.exists -and (Test-Path $resolved.state_path)) {
      $state = Get-Content -Path $resolved.state_path -Raw -Encoding UTF8
      $snapshot.name = Read-StateValue $state "name"
      $snapshot.phase = Read-StateValue $state "current"
      $snapshot.participation = Read-StateValue $state "level"
      $snapshot.nextCommand = Read-StateValue $state "command"
      if ($snapshot.participation -eq "") {
        $snapshot.participation = "medium"
      }
    }
  } catch {
  }

  return $snapshot
}

$studioDir = Join-Path $Root "studio"
$logsDir = Join-Path $studioDir "logs"
$dashboardDir = Join-Path $Root "dashboard"
$activityPath = Join-Path $logsDir "activity.jsonl"
$runtimePath = Join-Path $studioDir "runtime.json"
$exportScript = Join-Path $Root "tools/export-dashboard.ps1"

$AgentsUsed = Expand-CommaList $AgentsUsed
$SkillsUsed = Expand-CommaList $SkillsUsed
$FilesRead = Expand-CommaList $FilesRead
$FilesWritten = Expand-CommaList $FilesWritten
$Assumptions = Normalize-TextList $Assumptions
$Decisions = Normalize-TextList $Decisions
$Verification = Normalize-TextList $Verification

foreach ($dir in @($studioDir, $logsDir, $dashboardDir)) {
  if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
}

$leadId = ConvertTo-AgentId $LeadAgent
$agentIds = @($AgentsUsed | ForEach-Object { ConvertTo-AgentId $_ })
if ($agentIds -notcontains $leadId) {
  $agentIds = @($leadId) + $agentIds
}
$agentIds = @($agentIds | Where-Object { $_ -and $_.Trim().Length -gt 0 } | Select-Object -Unique)

$event = [pscustomobject]@{
  id = ((Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss") + "-" + ([guid]::NewGuid().ToString("N").Substring(0, 8)))
  timestamp = (Get-Date).ToString("o")
  command = $Command
  title = $Title
  status = $Status
  leadAgent = $leadId
  agentsUsed = $agentIds
  skillsUsed = @($SkillsUsed)
  filesRead = @($FilesRead)
  filesWritten = @($FilesWritten)
  assumptions = @($Assumptions)
  decisions = @($Decisions)
  verification = @($Verification)
  summary = $Summary
}

$eventJson = $event | ConvertTo-Json -Depth 20 -Compress
Add-Content -Path $activityPath -Value $eventJson -Encoding UTF8

if (Test-Path $runtimePath) {
  $runtime = Get-Content -Path $runtimePath -Raw -Encoding UTF8 | ConvertFrom-Json
  if (-not $runtime.agents) {
    $runtime | Add-Member -MemberType NoteProperty -Name agents -Value (New-AgentRoster)
  }
  if (-not ($runtime.PSObject.Properties.Name -contains "project")) {
    $runtime | Add-Member -MemberType NoteProperty -Name project -Value (Get-ProjectSnapshot $Root)
  }
} else {
  $runtime = [pscustomobject]@{
    version = "0.1"
    updated = ""
    activeCommand = ""
    activeTask = ""
    summary = ""
    project = Get-ProjectSnapshot $Root
    agents = New-AgentRoster
    latestEvents = @()
  }
}

$agentList = @($runtime.agents)
foreach ($known in (New-AgentRoster)) {
  if (-not ($agentList | Where-Object { $_.id -eq $known.id })) {
    $agentList += $known
  }
}

foreach ($agent in $agentList) {
  if ($agentIds -contains $agent.id) {
    if ($Status -eq "started") {
      $agent.status = "active"
      $agent.currentTask = $Title
    } elseif ($Status -eq "blocked") {
      $agent.status = "blocked"
      $agent.currentTask = $Title
    } elseif ($Status -eq "partial") {
      $agent.status = "partial"
      $agent.currentTask = $Title
    } else {
      $agent.status = "completed"
      $agent.currentTask = $Title
    }
    $agent.lastEvent = $event.timestamp
  } elseif ($Status -ne "started" -and $agent.status -eq "active") {
    $agent.status = "idle"
    $agent.currentTask = ""
  }
}

$recentEvents = @()
if (Test-Path $activityPath) {
  $recentLines = Get-Content -Path $activityPath -Encoding UTF8 | Where-Object { $_.Trim().Length -gt 0 } | Select-Object -Last 10
  foreach ($line in $recentLines) {
    try {
      $recentEvents += ($line | ConvertFrom-Json)
    } catch {
    }
  }
}

$runtime.version = "0.1"
$runtime.updated = (Get-Date).ToString("o")
$runtime.activeCommand = $(if ($Status -eq "started") { $Command } else { "" })
$runtime.activeTask = $(if ($Status -eq "started") { $Title } else { "" })
$runtime.summary = $Summary
$runtime.project = Get-ProjectSnapshot $Root
$runtime.agents = $agentList
$runtime.latestEvents = $recentEvents

$runtime | ConvertTo-Json -Depth 20 | Set-Content -Path $runtimePath -Encoding UTF8

if (Test-Path $exportScript) {
  & powershell -ExecutionPolicy Bypass -File $exportScript -Root $Root | Out-Null
}

Write-Output "Trace recorded: $($event.id)"
