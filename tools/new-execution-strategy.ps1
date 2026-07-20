param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$WorkPackagePath,
  [Parameter(Mandatory = $true)][ValidateSet("direct", "pipeline", "fan-out-and-synthesize", "adversarial-review", "loop-until-done")][string]$Strategy,
  [Parameter(Mandatory = $true)][string]$Reason,
  [ValidateSet("gameplay", "art", "ui", "architecture", "qa", "production")][string]$Domain = "gameplay",
  [ValidateRange(1, 4)][int]$MaxParallel = 1,
  [ValidateRange(1, 5)][int]$MaxRounds = 2,
  [switch]$Force
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$workFull = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $WorkPackagePath
$package = Get-Content -LiteralPath $workFull -Raw -Encoding UTF8 | ConvertFrom-Json
$relative = "production/execution/$($package.id).json"
$path = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $relative
if ((Test-Path $path) -and -not $Force) { throw "Execution strategy already exists: $path" }
$roles = if ($Domain -eq "art") {
  switch ($Strategy) {
    "direct" { @("technical-artist") }
    "pipeline" { @("creative-director", "art-director", "technical-artist", "unity-architect", "qa-lead") }
    "fan-out-and-synthesize" { @("creative-director", "ui-ux-developer", "technical-artist", "unity-architect", "art-director") }
    "adversarial-review" { @("art-director", "qa-lead") }
    "loop-until-done" { @("technical-artist", "art-director", "qa-lead") }
  }
} else {
  switch ($Strategy) {
    "direct" { @("gameplay-developer") }
    "pipeline" { @("game-designer", "gameplay-developer", "qa-lead") }
    "fan-out-and-synthesize" { @("game-designer", "unity-architect", "art-director", "producer") }
    "adversarial-review" { @("gameplay-developer", "qa-lead") }
    "loop-until-done" { @("gameplay-developer", "qa-lead") }
  }
}
$groups = @()
$index = 0
foreach ($role in $roles) {
  $index++
  $groups += [ordered]@{ id = "group-$index"; role = $role; objective = "$role contribution to $($package.objective)"; inputs = @($WorkPackagePath); outputs = @("production/work-packages/$($package.id).json") }
}
$plan = [ordered]@{
  '$schema' = "../../.mlgs/execution-strategy.schema.json"
  schemaVersion = "1.0"
  id = "execution-$($package.id)"
  workPackageId = [string]$package.id
  strategy = $Strategy
  domain = $Domain
  reason = $Reason
  groups = $groups
  synthesisOwner = "producer"
  maxParallel = $MaxParallel
  maxRounds = $MaxRounds
  stopCondition = "Both declared and objective verdicts pass, or the attempt budget is exhausted."
  updated = (Get-Date).ToString("o")
}
Write-MLGSJsonAtomic -Path $path -Value $plan
$package.strategy = $Strategy
$package.executionPlanPath = $relative
$package.updated = (Get-Date).ToString("o")
Write-MLGSJsonAtomic -Path $workFull -Value $package
$schema = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ".mlgs/execution-strategy.schema.json"
New-Item -ItemType Directory -Path (Split-Path -Parent $schema) -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $Root "studio/execution-strategy.schema.json") -Destination $schema -Force
[pscustomobject]@{ created = $true; path = $path; work_package = $workFull; strategy = $Strategy; domain = $Domain } | ConvertTo-Json -Depth 6
