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
      [pscustomobject]@{ key = "A"; command = "/mlgs 开始一个新的 Unity 游戏"; label = "新游戏"; description = "从空项目或粗略想法开始。" },
      [pscustomobject]@{ key = "B"; command = "/mlgs 接管 <path>"; label = "接入现有 Unity 项目"; description = "检查并挂接一个项目目录。" },
      [pscustomobject]@{ key = "C"; command = "/mlgs 帮助"; label = "怎么使用"; description = "查看自然语言示例和当前建议。" }
    )
  }

  if (-not $Detection.artifacts.concept) {
    return @(
      [pscustomobject]@{ key = "A"; command = "/mlgs 头脑风暴并创建概念包"; label = "创建概念包"; description = "整理卖点、幻想、支柱和 MVP 范围。" },
      [pscustomobject]@{ key = "B"; command = "/mlgs 复查项目接入缺口"; label = "复查接入缺口"; description = "重新执行项目差距分析。" },
      [pscustomobject]@{ key = "C"; command = "/mlgs 打开 dashboard"; label = "打开 Dashboard"; description = "查看工作室活动。" }
    )
  }

  if (-not $Detection.artifacts.design_plan) {
    return @(
      [pscustomobject]@{ key = "A"; command = "/mlgs 规划系统和任务"; label = "规划系统"; description = "生成系统设计、技术计划和任务。" },
      [pscustomobject]@{ key = "B"; command = "/mlgs 审查当前概念"; label = "审查概念"; description = "在规划前检查概念包。" },
      [pscustomobject]@{ key = "C"; command = "/mlgs 打开 dashboard"; label = "打开 Dashboard"; description = "查看工作室活动。" }
    )
  }

  if (-not $Detection.artifacts.prototype) {
    return @(
      [pscustomobject]@{ key = "A"; command = "/mlgs 验证核心原型"; label = "验证原型"; description = "制作可玩原型，或记录跳过风险。" },
      [pscustomobject]@{ key = "B"; command = "/mlgs 接受风险并继续实现"; label = "带风险实现"; description = "仅在 owner 接受原型风险后继续。" },
      [pscustomobject]@{ key = "C"; command = "/mlgs 定义 QA 检查"; label = "定义检查"; description = "在生产前准备 QA 证据。" }
    )
  }

  return @(
    [pscustomobject]@{ key = "A"; command = "/mlgs 继续实现下一个任务"; label = "实现下一任务"; description = "选择或执行一个生产任务。" },
    [pscustomobject]@{ key = "B"; command = "/mlgs 验证当前任务"; label = "验证"; description = "运行编译、smoke 或 QA 检查。" },
    [pscustomobject]@{ key = "C"; command = "/mlgs 做构建预检"; label = "构建"; description = "执行构建预检或产出构建。" },
    [pscustomobject]@{ key = "D"; command = "/mlgs 审查当前状态"; label = "审查"; description = "检查发布准备度或代码健康。" }
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
  $nextCommand = "/mlgs 开始"
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
    gaps = @("还没有配置活动项目。")
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



