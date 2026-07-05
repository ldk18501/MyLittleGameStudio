param(
  [string]$Root = "",
  [int]$Limit = 50
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

$dashboardDir = Join-Path $Root "dashboard"
$runtimePath = Join-Path $Root "studio/runtime.json"
$activityPath = Join-Path $Root "studio/logs/activity.jsonl"
$statusScript = Join-Path $Root "tools/get-project-status.ps1"
$outputPath = Join-Path $dashboardDir "studio-data.js"

if (-not (Test-Path $dashboardDir)) {
  New-Item -ItemType Directory -Path $dashboardDir | Out-Null
}

if (Test-Path $runtimePath) {
  $runtime = Get-Content -Path $runtimePath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
  $runtime = [pscustomobject]@{
    version = "0.1"
    updated = (Get-Date).ToString("o")
    activeCommand = ""
    activeTask = ""
    summary = "No MLGS runtime file exists yet."
    project = [pscustomobject]@{
      name = ""
      phase = ""
      participation = ""
      nextCommand = ""
      projectRoot = ""
    }
    agents = @()
    latestEvents = @()
  }
}

$events = @()
if (Test-Path $activityPath) {
  $lines = Get-Content -Path $activityPath -Encoding UTF8 | Where-Object { $_.Trim().Length -gt 0 } | Select-Object -Last $Limit
  foreach ($line in $lines) {
    try {
      $events += ($line | ConvertFrom-Json)
    } catch {
      $events += [pscustomobject]@{
        id = "invalid"
        timestamp = ""
        command = "unknown"
        title = "Invalid trace line"
        status = "blocked"
        leadAgent = "producer"
        agentsUsed = @("producer")
        skillsUsed = @()
        filesRead = @()
        filesWritten = @()
        assumptions = @()
        decisions = @("A malformed trace line was ignored by the dashboard exporter.")
        verification = @()
        summary = $line
      }
    }
  }
}

$status = $null
if (Test-Path $statusScript) {
  try {
    $status = & powershell -NoProfile -ExecutionPolicy Bypass -File $statusScript -Root $Root -AllowTemplate | ConvertFrom-Json
  } catch {
    $status = $null
  }
}

function Get-ArtifactValue {
  param($StatusObject, [string]$Name)

  if ($null -eq $StatusObject -or $null -eq $StatusObject.artifacts) {
    return $false
  }

  $property = $StatusObject.artifacts.PSObject.Properties[$Name]
  if ($null -eq $property) {
    return $false
  }

  return [bool]$property.Value
}

function Get-ApprovalValue {
  param($StatusObject, [string]$Name)

  if ($null -eq $StatusObject -or $null -eq $StatusObject.approvals) {
    return ""
  }

  $property = $StatusObject.approvals.PSObject.Properties[$Name]
  if ($null -eq $property) {
    return ""
  }

  return [string]$property.Value
}

function New-ChecklistItem {
  param(
    [string]$Id,
    [string]$Label,
    [bool]$Done,
    [string]$Command,
    [string]$Detail
  )

  return [pscustomobject]@{
    id = $Id
    label = $Label
    status = $(if ($Done) { "done" } else { "missing" })
    command = $Command
    detail = $Detail
  }
}

function Take-RecentValues {
  param(
    [object[]]$SourceEvents,
    [string]$PropertyName,
    [int]$Take = 5
  )

  $values = @()
  foreach ($event in @($SourceEvents | Sort-Object timestamp -Descending)) {
    $property = $event.PSObject.Properties[$PropertyName]
    if ($null -eq $property -or $null -eq $property.Value) {
      continue
    }

    foreach ($value in @($property.Value)) {
      foreach ($part in (([string]$value) -split ";")) {
        $text = $part.Trim()
        if (-not [string]::IsNullOrWhiteSpace($text)) {
          $values += $text
        }
      }
    }
  }

  return @($values | Select-Object -First $Take)
}

function Get-AgentInsights {
  param($RuntimeObject, [object[]]$SourceEvents)

  $agents = @()
  if ($RuntimeObject -and $RuntimeObject.agents) {
    $agents = @($RuntimeObject.agents)
  }

  $insights = @()
  foreach ($agent in $agents) {
    $agentId = [string]$agent.id
    $agentEvents = @($SourceEvents | Where-Object {
      $ids = @()
      if ($_.agentsUsed) { $ids += @($_.agentsUsed) }
      if ($_.leadAgent) { $ids += [string]$_.leadAgent }
      $ids -contains $agentId
    })

    $latest = @($agentEvents | Sort-Object timestamp -Descending | Select-Object -First 1)
    $insights += [pscustomobject]@{
      id = $agentId
      recentCount = $agentEvents.Count
      latestTitle = $(if ($latest.Count -gt 0) { $latest[0].title } else { "" })
      latestStatus = $(if ($latest.Count -gt 0) { $latest[0].status } else { "" })
      latestCommand = $(if ($latest.Count -gt 0) { $latest[0].command } else { "" })
      latestVerification = $(if ($latest.Count -gt 0 -and $latest[0].verification) { @($latest[0].verification | Select-Object -First 2) } else { @() })
      latestDecisions = $(if ($latest.Count -gt 0 -and $latest[0].decisions) { @($latest[0].decisions | Select-Object -First 2) } else { @() })
    }
  }

  return @($insights)
}

$phaseChecklist = @(
  (New-ChecklistItem "project" "已选择项目" ((Get-ApprovalValue $status "project_selected") -eq "true") "/mlgs 开始或接管项目" "配置项目状态、指针、可写路径和参与度。"),
  (New-ChecklistItem "concept" "概念包" ((Get-ApprovalValue $status "concept_package") -eq "true" -or (Get-ArtifactValue $status "concept")) "/mlgs 头脑风暴并创建概念包" "明确卖点、支柱、目标玩家、反目标和 MVP 范围。"),
  (New-ChecklistItem "plan" "系统与任务计划" ((Get-ApprovalValue $status "design_tech_plan") -eq "true" -or (Get-ArtifactValue $status "design_plan")) "/mlgs 规划系统和任务" "生成系统设计、技术计划、任务看板和原型策略。"),
  (New-ChecklistItem "prototype" "原型证据" ((Get-ApprovalValue $status "prototype_validation") -match "pass|skipped" -or (Get-ArtifactValue $status "prototype")) "/mlgs 验证核心原型" "记录可玩证据，或记录跳过原型的风险决策。"),
  (New-ChecklistItem "tests" "验证证据" (Get-ArtifactValue $status "tests") "/mlgs 验证当前任务" "记录编译、smoke、QA 或试玩证据。"),
  (New-ChecklistItem "production" "生产解锁" ((Get-ApprovalValue $status "production_unblocked") -eq "true") "/mlgs 继续实现下一个任务" "在计划和原型证据齐备后解锁生产任务。")
)

$blockedEvents = @($events | Where-Object { $_.status -eq "blocked" -or $_.status -eq "partial" } | Sort-Object timestamp -Descending | Select-Object -First 5)
$blockers = @()
if ($status -and $status.gaps) {
  $blockers += @($status.gaps)
}
foreach ($event in $blockedEvents) {
  $blockers += "$($event.title): $($event.summary)"
}

$operations = [pscustomobject]@{
  status = $status
  phaseChecklist = @($phaseChecklist)
  nextOptions = $(if ($status -and $status.next_options) { @($status.next_options) } else { @() })
  blockers = @($blockers | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 6)
  risks = $(if ($status -and $status.risks) { @($status.risks | Select-Object -First 6) } else { @() })
  assumptions = $(if ($status -and $status.assumptions) { @($status.assumptions | Select-Object -First 6) } else { @() })
  recentDecisions = @(Take-RecentValues $events "decisions" 6)
  recentVerification = @(Take-RecentValues $events "verification" 6)
  agentInsights = @(Get-AgentInsights $runtime $events)
}

$payload = [pscustomobject]@{
  generatedAt = (Get-Date).ToString("o")
  runtime = $runtime
  events = $events
  operations = $operations
}

$json = $payload | ConvertTo-Json -Depth 20
$content = "window.MLGS_STUDIO_DATA = $json;"
Set-Content -Path $outputPath -Value $content -Encoding UTF8

Write-Output "Dashboard data exported: $outputPath"


