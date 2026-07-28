param(
  [string]$Root = "",
  [ValidateSet("model", "full")][string]$View = "model",
  [int]$SkillMaxChars = 3500,
  [int]$AgentsMaxChars = 9000,
  [int]$RoutePacketMaxChars = 4000,
  [int]$StatusMaxChars = 5000
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)

$issues = @()
$measurements = @()

function Add-Measurement {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][int]$Characters,
    [Parameter(Mandatory = $true)][int]$Budget
  )
  $script:measurements += [pscustomobject]@{
    name = $Name
    characters = $Characters
    estimatedTokenCeiling = [Math]::Ceiling($Characters / 3.0)
    budget = $Budget
    passed = $Characters -le $Budget
  }
  if ($Characters -gt $Budget) { $script:issues += "$Name exceeds its model-context budget: $Characters > $Budget characters." }
}

$skillPath = if (Test-Path (Join-Path $Root "skills/mlgs/SKILL.md")) {
  Join-Path $Root "skills/mlgs/SKILL.md"
} else {
  Join-Path $Root "plugins/my-little-game-studio/skills/mlgs/SKILL.md"
}
$agentsPath = Join-Path $Root "AGENTS.md"
Add-Measurement -Name "skill" -Characters (Get-Content -LiteralPath $skillPath -Raw -Encoding UTF8).Length -Budget $SkillMaxChars
Add-Measurement -Name "workspace-agents" -Characters (Get-Content -LiteralPath $agentsPath -Raw -Encoding UTF8).Length -Budget $AgentsMaxChars

$catalog = Get-Content -LiteralPath (Join-Path $Root "workflow/catalog.json") -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($command in @($catalog.commands)) {
  $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/get-route-packet.ps1"), "-Root", $Root, "-Command", [string]$command.id, "-SkipState", "-View", "model")
  if ($command.PSObject.Properties.Name -contains "modes") {
    $defaultMode = @($command.modes | Where-Object { [bool]$_.default }) | Select-Object -First 1
    if ($null -ne $defaultMode) { $args += @("-Mode", [string]$defaultMode.id) }
  }
  $packet = & powershell @args | Out-String
  if ($LASTEXITCODE -ne 0) {
    $issues += "Route packet failed for command '$($command.id)'."
    continue
  }
  Add-Measurement -Name ("route:" + [string]$command.id) -Characters $packet.Trim().Length -Budget $RoutePacketMaxChars
}

$routeDocument = Get-Content -LiteralPath (Join-Path $Root "workflow/routes.json") -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($route in @($routeDocument.commands | Where-Object { $_.PSObject.Properties.Name -contains "policyByMode" })) {
  foreach ($modeProperty in $route.policyByMode.PSObject.Properties) {
    $packet = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/get-route-packet.ps1") -Root $Root -Command $route.id -Mode $modeProperty.Name -SkipState -View model | Out-String
    if ($LASTEXITCODE -ne 0) { $issues += "Route packet failed for command '$($route.id)' mode '$($modeProperty.Name)'."; continue }
    Add-Measurement -Name ("route:" + [string]$route.id + ":" + $modeProperty.Name) -Characters $packet.Trim().Length -Budget $RoutePacketMaxChars
  }
}
foreach ($command in @($catalog.commands | Where-Object { $_.PSObject.Properties.Name -contains "modes" })) {
  foreach ($mode in @($command.modes)) {
    $packet = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/get-route-packet.ps1") -Root $Root -Command $command.id -Mode $mode.id -SkipState -View model | Out-String
    if ($LASTEXITCODE -ne 0) { $issues += "Route packet failed for command '$($command.id)' mode '$($mode.id)'."; continue }
    Add-Measurement -Name ("route:" + [string]$command.id + ":" + [string]$mode.id) -Characters $packet.Trim().Length -Budget $RoutePacketMaxChars
    foreach ($stageFile in @($mode.stageFiles | Where-Object { $_ })) {
      $stage = [System.IO.Path]::GetFileNameWithoutExtension([string]$stageFile).Split("-")[-1]
      $stagePacket = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/get-route-packet.ps1") -Root $Root -Command $command.id -Mode $mode.id -Stage $stage -SkipState -View model | Out-String
      if ($LASTEXITCODE -ne 0) { $issues += "Route packet failed for command '$($command.id)' mode '$($mode.id)' stage '$stage'."; continue }
      Add-Measurement -Name ("route:" + [string]$command.id + ":" + [string]$mode.id + ":" + $stage) -Characters $stagePacket.Trim().Length -Budget $RoutePacketMaxChars
    }
  }
}

$status = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/get-project-status.ps1") -Root $Root -AllowTemplate -View model -ActivityLimit 3 | Out-String
if ($LASTEXITCODE -ne 0) {
  $issues += "Compact project status failed."
} else {
  Add-Measurement -Name "status:model" -Characters $status.Trim().Length -Budget $StatusMaxChars
}

$result = [ordered]@{
  passed = $issues.Count -eq 0
  budgets = [ordered]@{
    skill = $SkillMaxChars
    workspaceAgents = $AgentsMaxChars
    routePacket = $RoutePacketMaxChars
    status = $StatusMaxChars
  }
  maximumRoutePacketCharacters = [int](($measurements | Where-Object { $_.name -like "route:*" } | Measure-Object characters -Maximum).Maximum)
  issues = @($issues)
}

if ($View -eq "full") {
  $result["measurements"] = @($measurements)
  $result | ConvertTo-Json -Depth 10
} else {
  $result | ConvertTo-Json -Depth 8 -Compress
}
if (-not $result.passed) { exit 2 }
