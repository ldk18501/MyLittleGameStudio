param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [switch]$Force
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
if (-not (Test-Path $ProjectRoot)) { throw "Project root does not exist: $ProjectRoot" }

$artArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/init-art-pipeline.ps1"), "-Root", $Root, "-ProjectRoot", $ProjectRoot)
if ($Force) { $artArgs += "-Force" }
& powershell @artArgs | Out-Null

$written = @()
function Copy-IfNeeded {
  param([string]$SourceRelative, [string]$TargetRelative)
  $target = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $TargetRelative
  if ((Test-Path $target) -and -not $Force) { return }
  New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $Root $SourceRelative) -Destination $target -Force
  $script:written += $TargetRelative
}

Copy-IfNeeded "studio/release-scope.schema.json" ".mlgs/release-scope.schema.json"
Copy-IfNeeded "studio/work-package.schema.json" ".mlgs/work-package.schema.json"
Copy-IfNeeded "studio/game-profile.schema.json" ".mlgs/game-profile.schema.json"
Copy-IfNeeded "studio/ui-screen-contract.schema.json" ".mlgs/ui-screen-contract.schema.json"
Copy-IfNeeded "studio/design-baseline.schema.json" ".mlgs/design-baseline.schema.json"
Copy-IfNeeded "studio/change-impact.schema.json" ".mlgs/change-impact.schema.json"
Copy-IfNeeded "studio/capability-manifest.schema.json" ".mlgs/capability-manifest.schema.json"
Copy-IfNeeded "studio/execution-strategy.schema.json" ".mlgs/execution-strategy.schema.json"
Copy-IfNeeded "studio/framework-adoption.schema.json" ".mlgs/framework-adoption.schema.json"
Copy-IfNeeded "studio/presentation-architecture.schema.json" ".mlgs/presentation-architecture.schema.json"
Copy-IfNeeded "templates/framework-adoption.json" "design/framework-adoption.json"
Copy-IfNeeded "templates/presentation-architecture.json" "design/presentation-architecture.json"
Copy-IfNeeded "templates/ui-screen-contract.json" "design/ui/screen-inventory.json"
Copy-IfNeeded "templates/design-baseline.json" "design/baseline.json"
Copy-IfNeeded "templates/capability-manifest.json" "production/capabilities/capability-manifest.json"
Copy-IfNeeded "templates/release-scope.json" "production/scope/release-scope.json"
Copy-IfNeeded "templates/player-journey.md" "design/player-journey.md"
Copy-IfNeeded "templates/onboarding-design.md" "design/onboarding.md"
Copy-IfNeeded "templates/configuration-plan.md" "production/data/configuration-plan.md"
Copy-IfNeeded "templates/operations-readiness.md" "production/release/operations-readiness.md"

foreach ($relative in @("design/framework-adoption.json", "design/presentation-architecture.json")) {
  $contractPath = Join-Path $ProjectRoot $relative
  if (Test-Path $contractPath) {
    $contract = Get-Content -LiteralPath $contractPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace([string]$contract.updated)) {
      $contract.updated = (Get-Date).ToString("o")
      Write-MLGSJsonAtomic -Path $contractPath -Value $contract
    }
  }
}

$scopePath = Join-Path $ProjectRoot "production/scope/release-scope.json"
$uiPath = Join-Path $ProjectRoot "design/ui/screen-inventory.json"
if (Test-Path $uiPath) {
  $ui = Get-Content -LiteralPath $uiPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ([string]::IsNullOrWhiteSpace([string]$ui.updated)) { $ui.updated = (Get-Date).ToString("o"); Write-MLGSJsonAtomic -Path $uiPath -Value $ui }
}

$capabilityPath = Join-Path $ProjectRoot "production/capabilities/capability-manifest.json"
if (Test-Path $capabilityPath) {
  $capability = Get-Content -LiteralPath $capabilityPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ([string]::IsNullOrWhiteSpace([string]$capability.updated)) { $capability.updated = (Get-Date).ToString("o"); Write-MLGSJsonAtomic -Path $capabilityPath -Value $capability }
}

if (Test-Path $scopePath) {
  $scope = Get-Content -LiteralPath $scopePath -Raw -Encoding UTF8 | ConvertFrom-Json
  $changed = $false
  if ([string]$scope.schemaVersion -eq "1.0") { $scope.schemaVersion = "1.1"; $changed = $true }
  if ($scope.PSObject.Properties.Name -notcontains "profileId") { $scope | Add-Member NoteProperty profileId ""; $changed = $true }
  if ($scope.PSObject.Properties.Name -notcontains "designBaselineVersion") { $scope | Add-Member NoteProperty designBaselineVersion ""; $changed = $true }
  foreach ($item in @($scope.items)) {
    if ($item.PSObject.Properties.Name -notcontains "profileRequirementIds") { $item | Add-Member NoteProperty profileRequirementIds @(); $changed = $true }
  }
  if ([string]::IsNullOrWhiteSpace([string]$scope.updated)) { $changed = $true }
  if ($changed) {
    $scope.updated = (Get-Date).ToString("o")
    Write-MLGSJsonAtomic -Path $scopePath -Value $scope
  }
}

[pscustomobject]@{ initialized = $true; project_root = $ProjectRoot; files_written = @($written) } | ConvertTo-Json -Depth 8
